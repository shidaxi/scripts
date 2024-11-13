#!/bin/bash

## color codes
C_RESET="\033[0m"
C_RESET_UNDERLINE="\033[24m"
C_RESET_REVERSE="\033[27m"
C_DEFAULT="\033[39m"
C_DEFAULTB="\033[49m"
C_BOLD="\033[1m"
C_BRIGHT="\033[2m"
C_UNDERSCORE="\033[4m"
C_REVERSE="\033[7m"
C_BLACK="\033[30m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_BROWN="\033[33m"
C_BLUE="\033[34m"
C_MAGENTA="\033[35m"
C_CYAN="\033[36m"
C_WHITE="\033[37m"

c_red() {
   printf "${C_RED}${1}${C_RESET}"
}

c_blue() {
   printf "${C_BLUE}${1}${C_RESET}"
}

c_brown() {
   printf "${C_BROWN}${1}${C_RESET}"
}

c_green() {
   printf "${C_GREEN}${1}${C_RESET}"
}

c_red_bold() {
   printf "${C_RED}${C_BOLD}${1}${C_RESET}"
}

c_blue_bold() {
   printf "${C_BLUE}${C_BOLD}${1}${C_RESET}"
}

c_brown_bold() {
   printf "${C_BROWN}${C_BOLD}${1}${C_RESET}"
}

c_green_bold() {
   printf "${C_GREEN}${C_BOLD}${1}${C_RESET}"
}

now() {
  date +'[%Y-%m-%d %H:%M:%S]'
}

log_error() {
   printf "❌  ${C_MAGENTA}${C_BOLD}$(now)${C_RESET} ${C_RED}${C_BOLD}${1}${C_RESET}\n"
   exit 1
}

log_notice() {
   printf "🔔 ${C_MAGENTA}${C_BOLD}$(now)${C_RESET} ${C_BLUE}${C_BOLD}${1}${C_RESET}\n"
}

log_warn() {
   printf "⚠️ ${C_MAGENTA}${C_BOLD}$(now)${C_RESET} ${C_BROWN}${C_BOLD}${1}${C_RESET}\n"
}

log_info() {
   printf "✅ ${C_MAGENTA}${C_BOLD}$(now)${C_RESET} ${C_GREEN}${C_BOLD}${1}${C_RESET}\n"
}

print_cmd() {
   printf "${C_CYAN}${C_BOLD}>${C_RESET} ${C_GREEN}${C_BOLD}${1}${C_RESET}\n"
}

# Check if at least one argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <org/repo> [tag]"
  exit 1
fi

ORG_REPO=$1
TAG=$2

# Detect OS type and architecture
OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')

if [ "$OS_TYPE" == "darwin" ]; then
  OS_TYPE="darwin|macos"
fi

OS_ARCH=$(uname -m)
if [ "$OS_ARCH" == "x86_64" ]; then
  OS_ARCH="amd64"
elif [ "$OS_ARCH" == "aarch64" ]; then
  OS_ARCH="arm64"
fi

# Check if the repository is private
REPO_INFO=$(curl -s "https://api.github.com/repos/$ORG_REPO")
STATUS=$(echo "$REPO_INFO" | jq -r .status)

if [ "$STATUS" = "404" ]; then
  log_notice "Private repository detected, getting GitHub token..."
  GITHUB_TOKEN=$(gh auth token)
  if [ -z "$GITHUB_TOKEN" ]; then
    log_error "Failed to get GitHub token. Please run 'gh auth login' first"
  fi
fi


# Function to fetch the latest release
fetch_latest_release() {
  curl -s https://${GITHUB_TOKEN}@api.github.com/repos/$ORG_REPO/releases/latest
}

# Function to fetch all releases
fetch_releases() {
  curl -s https://${GITHUB_TOKEN}@api.github.com/repos/$ORG_REPO/releases
}

# Choose the appropriate release based on tag or latest
if [ -n "$TAG" ]; then
  RELEASES=$(fetch_releases)
  RELEASE=$(echo "$RELEASES" | jq -r --arg TAG "$TAG" '.[] | select(.tag_name | test($TAG)) | @base64' | head -n 1)
else
  RELEASE=$(fetch_latest_release | jq -r '@base64')
fi

if [ -z "$RELEASE" ]; then
  log_error "No release found for tag: $TAG"
fi

# Decode release JSON
RELEASE_JSON=$(echo "$RELEASE" | base64 --decode)

# Find asset URL matching OS type and architecture
# ASSET_URL=$(echo "$RELEASE_JSON" | jq -r \
#   --arg OS_TYPE "$OS_TYPE" \
#   --arg OS_ARCH "$OS_ARCH" \
#   '.assets[] | select(.name | ascii_downcase| match($OS_TYPE) and test($OS_ARCH)) | .browser_download_url' \
#   | head -n 1)
ASSET_ID=$(echo "$RELEASE" | base64 --decode | jq -r \
  --arg OS_TYPE "$OS_TYPE" \
  --arg OS_ARCH "$OS_ARCH" \
  '.assets[] | select(.name | ascii_downcase| match($OS_TYPE) and test($OS_ARCH)) | .id' \
  | head -n 1)
ASSET_NAME=$(echo "$RELEASE" | base64 --decode | jq -r \
  --arg OS_TYPE "$OS_TYPE" \
  --arg OS_ARCH "$OS_ARCH" \
  '.assets[] | select(.name | ascii_downcase| match($OS_TYPE) and test($OS_ARCH)) | .name' \
  | head -n 1)

if [ -z "$ASSET_ID" ]; then
  log_error "No asset found for OS: $OS_TYPE and ARCH: $OS_ARCH"
fi

# ASSET_URL="${ASSET_URL//github.com/${GITHUB_TOKEN}@github.com}"
ASSET_URL="https://${GITHUB_TOKEN}@api.github.com/repos/$ORG_REPO/releases/assets/$ASSET_ID"
# Download the asset
log_info "Downloading $ASSET_NAME..."
curl -H "Accept: application/octet-stream" --progress-bar -sL $ASSET_URL -o $ASSET_NAME

# Check if the downloaded file is a tar.gz and extract if necessary
FILENAME=$(basename "$ASSET_NAME")
if [[ "$FILENAME" == *.tar.gz ]]; then
  log_info "Extracting $FILENAME ..."
  CMD="tar -xzf $FILENAME -C ."
  print_cmd "$CMD"; eval "$CMD"
  log_info "Extraction complete."
elif [[ "$FILENAME" == *.zip ]]; then
  log_info "Extracting $FILENAME ..."
  CMD="unzip -q $FILENAME"
  print_cmd "$CMD"; eval "$CMD"
  log_info "Extraction complete."
fi

log_info "Download complete."
