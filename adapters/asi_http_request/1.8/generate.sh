#!/bin/bash

SCRIPT_FILE_DIR=`dirname $0`
SCRIPT_FILE_DIR=`cd $SCRIPT_FILE_DIR; pwd`
CHECKOUT_DIR="$SCRIPT_FILE_DIR/checkout/asi-http-request"
GENERATED_PROJECT_DIR="$SCRIPT_FILE_DIR/asi_http_request"
GENERATED_SOURCE_DIR="$GENERATED_PROJECT_DIR/Sources"
MAKE_SCRIPT="$SCRIPT_FILE_DIR/../../../make-fmwk.sh"

# Get the source code if not already checked out
echo "Checking out source code..."
if [ ! -d "$CHECKOUT_DIR" ]; then
    git clone git://github.com/pokeb/asi-http-request.git "$CHECKOUT_DIR"
fi

# Check if the source code could be checked out
if [ ! -d "$CHECKOUT_DIR" ]; then
    echo "Source code checkout failure"
    exit 1
fi

# Checking out some recent 1.8 version (the first 1.8 version is incorrectly identified as 1.7, and contains some annoying bugs)
cd "$CHECKOUT_DIR"
git checkout 341fb853b66e7ef7263e38382197402f7ae0a944

# Cleanup generated project directory before creating it again
echo "Copying source files..."
if [ -d "$GENERATED_SOURCE_DIR" ]; then
    rm -rf "$GENERATED_SOURCE_DIR"
fi
mkdir -p "$GENERATED_SOURCE_DIR"

# Copy the required source files, remove unnecessary ones
cp -r "$CHECKOUT_DIR/Classes/" "$GENERATED_SOURCE_DIR"
rm -r "$GENERATED_SOURCE_DIR/Tests"
cp -r "$CHECKOUT_DIR/External/Reachability" "$GENERATED_SOURCE_DIR"

# Find the exact version number
asi_http_request_version=`cat "$GENERATED_SOURCE_DIR/ASIHTTPRequest.m" | grep "ASIHTTPRequestVersion" | sed -E 's/.*"v(.*)".*/\1/g' | sed -E 's/[[:space:]]/_/g'`
echo "Version found: $asi_http_request_version"

# Build the framework
echo "Creating frameworks..."
cd "$GENERATED_PROJECT_DIR"
"$MAKE_SCRIPT" -u "$asi_http_request_version" Release
"$MAKE_SCRIPT" -u "$asi_http_request_version" Debug
"$MAKE_SCRIPT" -u "$asi_http_request_version" -s Debug
