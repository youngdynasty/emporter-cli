#!/bin/sh
#
#
#  ███████╗███╗   ███╗██████╗  ██████╗ ██████╗ ████████╗███████╗██████╗ 
#  ██╔════╝████╗ ████║██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔════╝██╔══██╗
#  █████╗  ██╔████╔██║██████╔╝██║   ██║██████╔╝   ██║   █████╗  ██████╔╝
#  ██╔══╝  ██║╚██╔╝██║██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══╝  ██╔══██╗
#  ███████╗██║ ╚═╝ ██║██║     ╚██████╔╝██║  ██║   ██║   ███████╗██║  ██║
#  ╚══════╝╚═╝     ╚═╝╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
# 
#    Instantly create a secure URL to your Mac, accessible anywhere.
#                        https://emporter.app
#
#

PREFIX=/usr/local/bin

# Set up the environment to exit on error
set -e

# Package code signatures are verified before installation
PACKAGE_TEAM_ID=EEQTQC5N2L
PACKAGE_VERSION=0.1.0
PACKAGE_URL=https://github.com/youngdynasty/emporter-cli/releases/download/v$PACKAGE_VERSION/emporter.pkg

# Optional overrides
if [ -z "$PACKAGE" ];  then PACKAGE=$PACKAGE_URL; fi

# Helper functions for pretty output
fatal()   { echo   "\033[1;38;41m ✘ \033[0m $1" >&2; exit 1; }
warning() { echo   "\033[1;38;43m ! \033[0m $1"; }
success() { echo   "\033[1;38;42m ✓ \033[0m $1"; }
bold()    { printf "\033[1m%s\033[0m" "$1"; }

# Create a temporary work directory ...
TEMP_DIR=$(mktemp -d)

if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then fatal "Could not create temporary download directory"; fi

# ... that is removed on exit 
trap "{ rm -fr '$TEMP_DIR'; }" EXIT

echo "==> Downloading $(bold "emporter v$PACKAGE_VERSION") package..."
({ if [ "$PACKAGE" != "$PACKAGE_URL" ]; then cp "$PACKAGE" "$TEMP_DIR/emporter.pkg"; else curl -sSL "$PACKAGE" -o "$TEMP_DIR/emporter.pkg"; fi })

# Verify signature
SIGNATURE=$(pkgutil --check-signature $TEMP_DIR/emporter.pkg | grep $PACKAGE_TEAM_ID)
if [ -z "$SIGNATURE" ]; then fatal "Package contained a valid signature but it was not signed by Young Dynasty"; fi

warning "The macOS installer may require root to install $(bold emporter) to $(bold /usr/local/bin)."
sudo installer -pkg "$TEMP_DIR/emporter.pkg" -target / > /dev/null

# Woohoo!
success "Install complete! Run '$(bold emporter)' to get started."
