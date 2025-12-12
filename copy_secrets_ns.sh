#!/bin/bash

# Configuration
MOUNT_PATH="/sys/mount"
VAULT_ADDR='https://hcvault.com:8200'
SOURCE_NAMESPACE=''
DEST_NAMESPACE=''
SOURCE_PATH='sec_kv/ssl_certificates/'

# Function: Enable KV v2 secrets engine if missing
enable_kv_engine() {
	local ns=$1
	export VAULT_NAMESPACE="$ns"

	if ! vault secrets list -format=json | jq -e --arg path "$MOUNT_PATH/" '.[$path]'; then
		echo "Enabling KV v2 at $MOUNT_PATH/ in namespace $ns"
		vault secrets enable -path="$MOUNT_PATH" -version=2 kv
	else
		echo "KV engine already enabled at $MOUNT_PATH/ in namespace $ns"
	fi
}

copy_secret() {
	local full_path="$1"
	echo "INSIDE COPY SECRETS FUNCTION"
	echo "full path is ", $full_path

	# Check if secret exists at destination
	VAULT_NAMESPACE="$DEST_NAMESPACE"
	export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
	if vault kv get "$full_path" &>/dev/null; then
		echo "Secret $full_path already exists at destination. Skipping."
		return
	fi

	# Read secret from source
	VAULT_NAMESPACE="$SOURCE_NAMESPACE"
	export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
	SECRET_JSON=$(vault kv get -format=json "$full_path" | jq -c '.data.data')
	echo "The SECRET JSON is" $SECRET_JSON

	if [ -z "$SECRET_JSON" ] || [ "$SECRET_JSON" == "null" ]; then
		echo "No secret data found at $full_path. Skipping."
		return
	fi

	# Write secret to destination
	echo "NOW WRITING"
	VAULT_NAMESPACE="$DEST_NAMESPACE"
	export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
	#echo "$SECRET_JSON" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"'| xargs vault kv put "$full_path"
	SECRET_JSON=$(jq -n --argjson data "$SECRET_JSON" '{data: $data}')
	#echo "$SECRET_JSON"| vault kv put "$full_path" -
	VAULT_NAMESPACE="$DEST_NAMESPACE"
	export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
	echo "$SECRET_JSON" | vault write "$full_path" -
	echo "Copied secret: $full_path"
}

# Read all secret keys (folder + secrets) from source namespace
VAULT_NAMESPACE="$SOURCE_NAMESPACE"
export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
SECRET_KEYS=$(vault kv list -format=json $SOURCE_PATH | jq -r '.[]')
echo "THE SECRET KEYS ARE - $SECRET_KEYS"

for key in $SECRET_KEYS; do
	echo "Processing key: $key"

	# If it's a folder (ends with '/'), recursively process its contents
	if [[ "$key" == */ ]]; then
		FPATH="${SOURCE_PATH}${key%/}"
		FOLDER_PATH="$FPATH"/
		echo "Entering folder: $FOLDER_PATH"

		VAULT_NAMESPACE="$SOURCE_NAMESPACE"
		export VAULT_TOKEN=$(vault login -token-only -address=${VAULT_ADDR} -namespace=${VAULT_NAMESPACE} -method=aws)
		SUBKEYS=$(vault kv list -format=json "$FOLDER_PATH" | jq -r '.[]')
		echo "SUBKEYS ARE - "$SUBKEYS

		for subkey in $SUBKEYS; do
			FULL_SUBKEY="${FOLDER_PATH}/${subkey}"
			echo "Processing subkey: $FULL_SUBKEY"
			copy_secret "$FULL_SUBKEY"
		done
	else
		FULL_KEY="${SOURCE_PATH}/${key}"
		copy_secret "$FULL_KEY"
	fi
done
