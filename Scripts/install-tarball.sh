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

# Set up the environment to exit on error
set -e

# Package code signatures are verified before installation
PACKAGE_ID=net.youngdynasty.emporter.cli
PACKAGE_TEAM_ID=EEQTQC5N2L
PACKAGE_VERSION=0.1.1
PACKAGE_URL=https://github.com/youngdynasty/emporter-cli/releases/download/v$PACKAGE_VERSION/emporter.tar.gz

# Optional overrides
if [ -z "$PREFIX" ];   then PREFIX=/usr/local/bin;   fi
if [ -z "$BIN_NAME" ]; then BIN_NAME=emporter;       fi
if [ -z "$PACKAGE" ];  then PACKAGE=$PACKAGE_URL; fi

# Helper functions for pretty output
fatal()   { echo   "\033[1;38;41m ✘ \033[0m $1" >&2; exit 1; }
warning() { echo   "\033[1;38;43m ! \033[0m $1"; }
success() { echo   "\033[1;38;42m ✓ \033[0m $1"; }
bold()    { printf "\033[1m%s\033[0m" "$1"; }

# Make sure we're on macOS 10.13+
if [ "$(uname -s)" == "Darwin" ]; then
    MAC_OS_MINOR_VERSION="$(sw_vers -productVersion | sed -e "s/\./"$'\t'"/g" -e "s/-/"$'\t'"/" | cut -f 2)"
else
    MAC_OS_MINOR_VERSION="0"
fi

if [ "$MAC_OS_MINOR_VERSION" -lt 13 ]; then fatal "$(bold Emporter) requires macOS 10.13+ to run."; fi

# Make sure we're _not_ running as root. It'll be annoying to apply updates, plus it's really not in the user's best interest
if [ "$EUID" -eq 0 ]; then fatal "Installing $(bold Emporter) as $(bold root) is not supported."; fi

# Create a temporary work directory ...
TEMP_DIR=$(mktemp -d)

if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then fatal "Could not create temporary download directory"; fi

# ... that is removed on exit 
trap "{ rm -fr '$TEMP_DIR'; }" EXIT
echo "==> Downloading and unpacking $(bold "emporter v$PACKAGE_VERSION")..."
({ if [ -f "$PACKAGE" ]; then cat "$PACKAGE"; else curl -sSL "$PACKAGE"; fi }) | tar -xzC "$TEMP_DIR"

# Assume first item in the package is our binary
PACKAGE_BINARY=$(ls "$TEMP_DIR" | head -n 1)

# Verify the binary is the Emporter CLI, signed by Apple on behalf of Young Dynasty
codesign -vR="
    identifier = \"$PACKAGE_ID\"
    and anchor apple generic
    and certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */
    and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */
    and certificate leaf[subject.OU] = \"$PACKAGE_TEAM_ID\"
    " "$TEMP_DIR"/"$PACKAGE_BINARY"

# Make sure the destination directory exists before we copy
if [ ! -d "$PREFIX" ]; then mkdir -p "$PREFIX"; fi

# Copy to destination (and overwrite the existing version if needed)
mv -f "$TEMP_DIR/$PACKAGE_BINARY" "$PREFIX/$BIN_NAME"

# Output a warning if our $PATH does not include our prefix
if [[ "$PATH" != *"$PREFIX"* ]]; then warning "Your $(bold "\$PATH") does not include $(bold "$PREFIX")."; fi

# Woohoo!
success "Install complete! Run '$(bold "$BIN_NAME")' to get started."
