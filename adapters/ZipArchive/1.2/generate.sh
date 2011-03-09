#!/bin/bash

SCRIPT_FILE_DIR=`dirname $0`
SCRIPT_FILE_DIR=`cd $SCRIPT_FILE_DIR; pwd`
CHECKOUT_DIR="$SCRIPT_FILE_DIR/checkout/ZipArchive"
GENERATED_PROJECT_DIR="$SCRIPT_FILE_DIR/ZipArchiveLib"
GENERATED_SOURCE_DIR="$GENERATED_PROJECT_DIR/Sources"
MAKE_SCRIPT="$SCRIPT_FILE_DIR/../../../make-fmwk.sh"
VERSION="1.2"

# Get the source code if not already checked out
echo "Checking out source code..."
if [ ! -d "$CHECKOUT_DIR" ]; then
    svn checkout http://ziparchive.googlecode.com/svn/trunk/ "$CHECKOUT_DIR"
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

# Copy the required source files, remove unnecessary ones
cp -r "$CHECKOUT_DIR/" "$GENERATED_SOURCE_DIR"
rm -r "$GENERATED_SOURCE_DIR/minizip/ChangeLogUnzip"
rm -r "$GENERATED_SOURCE_DIR/minizip/Makefile"

# Comment out NSLog calls (bad in production code!). Some deprecated code remains, but replacing it as well is not worth
# the price (after all, it is deprecated, but it works)
cat "$GENERATED_SOURCE_DIR/ZipArchive.mm" | sed -E 's/(NSLog\(.*\);)/\/\/\1/g' > "$GENERATED_SOURCE_DIR/ZipArchive.mm.tmp"
mv "$GENERATED_SOURCE_DIR/ZipArchive.mm.tmp" "$GENERATED_SOURCE_DIR/ZipArchive.mm"

# Complete paths to include files are not necessary when using XCode
cat "$GENERATED_SOURCE_DIR/ZipArchive.h" | sed -E 's/#include "minizip\//#import "/g' > "$GENERATED_SOURCE_DIR/ZipArchive.h.tmp"
mv "$GENERATED_SOURCE_DIR/ZipArchive.h.tmp" "$GENERATED_SOURCE_DIR/ZipArchive.h"

# Build the framework
echo "Creating frameworks..."
cd "$GENERATED_PROJECT_DIR"
"$MAKE_SCRIPT" -u "$VERSION" Release
"$MAKE_SCRIPT" -u "$VERSION" Debug
"$MAKE_SCRIPT" -u "$VERSION" -s Debug
