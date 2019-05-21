#/bin/sh

# ------------------------------------------------------------------------------------------

# Exit on error
set -e

# Helper functions for pretty output
fatal()   { echo   "\033[1;38;41m ✘ \033[0m $1" >&2; exit 1; }
warning() { echo   "\033[1;38;43m ! \033[0m $1"; }
success() { echo   "\033[1;38;42m ✓ \033[0m $1"; }
bold()    { printf "\033[1m%s\033[0m" "$1"; }

# Parse args / environment
SCRIPT_NAME=$(basename $0)
VERSION=$1

if [ -z "$VERSION" ]; then fatal "Usage: $SCRIPT_NAME VERSION [ASSETS...]"; fi
if [ -z "$GITHUB_CREDS" ]; then fatal "Missing $(bold GITHUB_CREDS) environment variable"; fi
if [ -z "$(which jq)" ]; then fatal "$(bold jq) not found in $(bold \$PATH)."; fi

# GitHub API
GITHUB_REPO=youngdynasty/emporter-cli
gh_api_url() { if [[ "$1" == "http"* ]]; then echo $1; else echo "https://api.github.com/repos/$GITHUB_REPO$1"; fi; }
gh_api()     { curl -u "$GITHUB_CREDS" -sS "${@:2}" "$(gh_api_url $1)"; }

# ------------------------------------------------------------------------------------------

echo "==> Finding $(bold v$VERSION) release draft..."

# Get release
RELEASE=$(gh_api "/releases" | jq ".[] | select(.tag_name | contains(\"v$VERSION\"))")

# Create it if it doesn't exist
if [ -z "$RELEASE" ]; then 
    echo "==> Drafting new release..."
    RELEASE=$(gh_api "/releases" -d "{\"tag_name\": \"v$VERSION\", \"draft\": true}")
fi

RELEASE_ID=$(echo $RELEASE | jq -r '.id')

# Exit early if there was an error or the release was already published
if [ "$RELEASE_ID" == "null" ]; then
    fatal "Unexpected result:\n\n$(echo $RELEASE | jq)"
elif [ "$(echo $RELEASE | jq '.draft')" != "true" ]; then
    fatal "Release $(bold v$VERSION) already exists on GitHub!"
fi

# Upload assets
ASSET_UPLOAD_URL=$(echo $RELEASE | jq -r '.upload_url' | cut -d '{' -f 1)

for ASSET_PATH in "${@:2}"; do
    ASSET_NAME=$(basename $ASSET_PATH)
    ASSET_MIME_TYPE=$(file -b --mime-type $ASSET_NAME)
    
    echo "==> Uploading $(bold $ASSET_NAME)..."

    UPLOAD=$(gh_api "$ASSET_UPLOAD_URL?name=$ASSET_NAME" --data-binary "@$ASSET_PATH" -H "Content-Type: $ASSET_MIME_TYPE")

    if [ "$(echo $UPLOAD | jq -r '.id')" == "null" ]; then
        if [ $(echo $UPLOAD | jq -r '.errors[0].code') == 'already_exists' ]; then
            warning "File already exists; ignoring"
        else
            fatal "Unexpected result:\n\n$(echo $UPLOAD | jq)"
        fi
    fi
done

success "Release draft is ready for review"

# Open draft in default browser for release notes, etc
open "$(echo $RELEASE | jq -r '.html_url')"
