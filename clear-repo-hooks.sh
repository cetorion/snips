#!/bin/bash
# 
USER=""
GITHUB_URL_BASE="https://github.com"
GITHUB_ORG=""
URL="${GITHUB_URL_BASE}/api/v3/search/code?q=org:${GITHUB_ORG}+filename:pipeline_config.groovy&per_page=1000"

echo "Getting repos..."
repos=$(
curl -s -L --noproxy '*' -u $USER -X GET $URL \
  -H 'Content-Type: application/json' \
  -H 'cache-control: no-cache' \
  -H 'Accept: application/vnd.github.cloak-preview' \
  | jq -c -r '.items[].repository.full_name' | sort
)

for repo in $repos; do
  echo "Repo: $repo"
  echo "Getting webhooks"
  
  hooks=$(
  curl -k -H 'Accept: application/vnd.github+json' \
    -u $USER ${GITHUB_URL_BASE}/api/v3/repos/$repo/hooks | jq -c -r '.[].id'
  )

  for hook in $hooks; do
    echo "Hook: $hook"
    echo "Deleting ..."
    curl -k -X DELETE -H 'Accept: application/vnd.github+json' \
    -u $USER \
    ${GITHUB_URL_BASE}/api/v3/repos/$repo/hooks/$hook
  done
done
