#!/bin/bash

repo="$1"
tag="$2"
asset_name="$3"

help() {
  echo 'curl -fsSL https://shuai.dev/scripts/private-github-release-asset-downloader.sh | bash -s -- cli/cli v2.46.0 gh_2.46.0_linux_amd64.tar.gz'
}

if [ -z "$repo" ] || [ -z "$tag" ] || [ -z "${asset_name}" ]; then
    help
    exit
fi

[ -z "${GITHUB_TOKEN}" ] && { echo "GITHUB_TOKEN not set"; exit 1; }

asset_url=$(curl -sSL \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GITHUB_TOKEN} "\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/${repo}/releases \
  | jq -r '.[] | select(.tag_name=="'$tag'") | .assets[] | select(.name=="'${asset_name}'") | .url')

curl -sSL -H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/octet-stream" ${asset_url} -o $asset_name