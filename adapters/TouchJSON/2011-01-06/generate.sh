#!/bin/bash

SCRIPT_FILE_DIR=`dirname $0`
SCRIPT_FILE_DIR=`cd $SCRIPT_FILE_DIR; pwd`
CHECKOUT_DIR="$SCRIPT_FILE_DIR/checkout/TouchJSON"
GENERATED_PROJECT_DIR="$SCRIPT_FILE_DIR/TouchJSON"
GENERATED_SOURCE_DIR="$GENERATED_PROJECT_DIR/Sources"
MAKE_SCRIPT="$SCRIPT_FILE_DIR/../../../make-fmwk.sh"

# TouchJSON lacks version numbers; instead, we pick up a commit version number as well as the corresponding date,
# and we will use this date as version number (using the commit number would be slightly better, but it is so ugly…)
COMMIT_VERSION_NBR="0bb94d374e3d269e44d"
COMMIT_DATE="2011-01-06"

# Get the source code if not already checked out
echo "Checking out source code..."
if [ ! -d "$CHECKOUT_DIR" ]; then
    git clone https://github.com/schwa/TouchJSON.git "$CHECKOUT_DIR"
fi

# Check if the source code could be checked out
if [ ! -d "$CHECKOUT_DIR" ]; then
    echo "Source code checkout failure"
    exit 1
fi

# Checking out some version
cd "$CHECKOUT_DIR"
git checkout "$COMMIT_VERSION_NBR"

# Cleanup generated project directory before creating it again
echo "Copying source files..."
if [ -d "$GENERATED_SOURCE_DIR" ]; then
    rm -rf "$GENERATED_SOURCE_DIR"
fi
mkdir -p "$GENERATED_SOURCE_DIR"

# Copy the required source files, remove unnecessary ones
cp -r "$CHECKOUT_DIR/Source/" "$GENERATED_SOURCE_DIR"

# Build the framework
echo "Creating frameworks..."
cd "$GENERATED_PROJECT_DIR"
"$MAKE_SCRIPT" -u "$COMMIT_DATE" Release
"$MAKE_SCRIPT" -u "$COMMIT_DATE" -s Debug
