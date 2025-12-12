#!/bin/bash

RDC='\033[0;31m'
YLC='\033[1;33m'
NOC='\033[0m'

RUN=0
if [[ $1 == "-d" ]]; then
	RUN=1
else
	printf "${YLC}Dry run. Use '-d' to really delete the groups${NOC}\n\n"
fi

function delete_sgrps {
	SGS=$(aws ec2 describe-security-groups \
		--query "SecurityGroups[?GroupName!='default'].[GroupId]" \
		--output text)

	for SG in $SGS; do
		NIS=$(aws ec2 describe-network-interfaces \
			--filters Name=group-id,Values="$SG" \
			--query "NetworkInterfaces[*].[GroupId]" \
			--output text)

		if [[ -z "$NIS" ]]; then
			if (($RUN)); then
				printf "${RDC} delete unused SG: $SG ${NOC}\n"
				aws ec2 delete-security-group --group-id "$SG"
			else
				printf "${YLC} mark unused SG:  $SG ${NOC}\n"
			fi
		fi
	done
}

delete_sgrps

# aws ec2 describe-instances --instance-ids i-0f4fb9fc95780c76b --query 'Reservations[*].Instances[*].PrivateIpAddress' --output text
