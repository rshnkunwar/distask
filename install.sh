#!/bin/bash
set -e

# ========================================================
#  DisTask One-Line Installer for macOS
# ========================================================

REPO="rshnkunwar/distask"
APP_NAME="DisTask"
BUNDLE_NAME="$APP_NAME.app"
DEST_DIR="/Applications"
USER_DEST_DIR="$HOME/Applications"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${PURPLE}${BOLD}📋 DisTask Installer for macOS${NC}"
echo -e "${BLUE}========================================${NC}"

# Verify macOS environment
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}❌ Error: DisTask is designed specifically for macOS.${NC}"
    exit 1
fi

# Determine target install directory
TARGET_DIR="$DEST_DIR"
if [ ! -w "$DEST_DIR" ]; then
    mkdir -p "$USER_DEST_DIR"
    TARGET_DIR="$USER_DEST_DIR"
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

INSTALLED=false

# 1. Try downloading pre-built binary release from GitHub
RELEASE_URL="https://github.com/$REPO/releases/latest/download/$APP_NAME.zip"
echo -e "🔍 Checking for pre-built release binary..."

if curl -sILf "$RELEASE_URL" -o /dev/null 2>/dev/null; then
    echo -e "⬇️  Downloading pre-built release from GitHub..."
    if curl -sL "$RELEASE_URL" -o "$TEMP_DIR/$APP_NAME.zip"; then
        echo -e "📦 Unpacking $BUNDLE_NAME..."
        unzip -q "$TEMP_DIR/$APP_NAME.zip" -d "$TEMP_DIR"
        if [ -d "$TEMP_DIR/$BUNDLE_NAME" ]; then
            INSTALLED=true
        fi
    fi
fi

# 2. If no pre-built release, build from source
if [ "$INSTALLED" = false ]; then
    echo -e "🔨 Building from source using Swift..."

    # Check for git and swift
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Error: 'git' is not installed.${NC}"
        exit 1
    fi

    if ! command -v swift &> /dev/null; then
        echo -e "${RED}❌ Error: Xcode Command Line Tools / Swift compiler required.${NC}"
        echo -e "👉 Please run: ${BOLD}xcode-select --install${NC} and re-run this script."
        exit 1
    fi

    echo -e "📥 Cloning repository..."
    git clone --depth 1 "https://github.com/$REPO.git" "$TEMP_DIR/distask"

    echo -e "⚡ Compiling DisTask (release mode)..."
    cd "$TEMP_DIR/distask"
    ./build_app.sh > /dev/null 2>&1 || ./build_app.sh

    if [ -d "$TEMP_DIR/distask/$BUNDLE_NAME" ]; then
        mv "$TEMP_DIR/distask/$BUNDLE_NAME" "$TEMP_DIR/$BUNDLE_NAME"
        INSTALLED=true
    fi
fi

if [ "$INSTALLED" = true ]; then
    echo -e "🚀 Installing to ${BOLD}$TARGET_DIR/$BUNDLE_NAME${NC}..."
    # Close any currently running instance
    pkill -f "$APP_NAME" 2>/dev/null || true
    sleep 0.5

    rm -rf "$TARGET_DIR/$BUNDLE_NAME"
    cp -R "$TEMP_DIR/$BUNDLE_NAME" "$TARGET_DIR/$BUNDLE_NAME"

    # Remove macOS quarantine bit
    xattr -cr "$TARGET_DIR/$BUNDLE_NAME" 2>/dev/null || true

    echo -e "${GREEN}${BOLD}✅ Successfully installed DisTask!${NC}"
    echo -e "🎉 Launching DisTask..."
    open "$TARGET_DIR/$BUNDLE_NAME"
    echo -e "💡 DisTask is now running in your macOS menu bar."
else
    echo -e "${RED}❌ Failed to install DisTask.${NC}"
    exit 1
fi
