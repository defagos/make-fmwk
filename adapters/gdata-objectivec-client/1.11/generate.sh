#!/bin/bash

SCRIPT_FILE_DIR=`dirname $0`
SCRIPT_FILE_DIR=`cd $SCRIPT_FILE_DIR; pwd`
CHECKOUT_DIR="$SCRIPT_FILE_DIR/checkout/gdata-objectivec-client"
GENERATED_PROJECT_DIR="$SCRIPT_FILE_DIR/GDataTouch"
GENERATED_SOURCE_DIR="$GENERATED_PROJECT_DIR/Sources"
MAKE_SCRIPT="$SCRIPT_FILE_DIR/../../../make-fmwk.sh"
VERSION="1.11"

# Get the source code if not already checked out
echo "Checking out source code..."
if [ ! -d "$CHECKOUT_DIR" ]; then
    svn checkout http://gdata-objectivec-client.googlecode.com/svn/trunk/ "$CHECKOUT_DIR"
fi

# Check if the source code could be checked out
if [ ! -d "$CHECKOUT_DIR" ]; then
    echo "Source code checkout failure"
    exit 1
fi

# Cleanup generated project directory before creating it again
echo "Copying source files..."
if [ -d "$GENERATED_SOURCE_DIR" ]; then
    rm -rf "$GENERATED_SOURCE_DIR"
fi
mkdir -p "$GENERATED_SOURCE_DIR"

# Copy the required source files, remove unncessary ones
cp -r "$CHECKOUT_DIR/Source/" "$GENERATED_SOURCE_DIR"
rm -rf "$GENERATED_SOURCE_DIR/build"
rm -rf "$GENERATED_SOURCE_DIR/GData.xcodeproj"
rm -rf "$GENERATED_SOURCE_DIR/GDataOAuthTouchStaticLibrary.xcodeproj"
rm "$GENERATED_SOURCE_DIR/ReleaseNotes.txt"
rm -rf "$GENERATED_SOURCE_DIR/Resources"
rm -rf "$GENERATED_SOURCE_DIR/Tests"
rm -rf "$GENERATED_SOURCE_DIR/Tools"

# Build the framework
echo "Creating frameworks..."
cd "$GENERATED_PROJECT_DIR"
"$MAKE_SCRIPT" -u "$VERSION" Release
"$MAKE_SCRIPT" -u "$VERSION" -s Debug
