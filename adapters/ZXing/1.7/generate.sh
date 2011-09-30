#!/bin/bash

SCRIPT_FILE_DIR=`dirname $0`
SCRIPT_FILE_DIR=`cd $SCRIPT_FILE_DIR; pwd`
CHECKOUT_DIR="$SCRIPT_FILE_DIR/checkout/ZXingWidget"
IPHONE_CHECKOUT_DIR="$CHECKOUT_DIR/iphone/ZXingWidget"
FRAMEWORK_SETUP_DIR="$SCRIPT_FILE_DIR/FrameworkSetup"
MAKE_SCRIPT="$SCRIPT_FILE_DIR/../../../make-fmwk.sh"
ZXING_VERSION="1.7"

# Get the source code if not already checked out
echo "Checking out source code..."
if [ ! -d "$CHECKOUT_DIR" ]; then
    # Corresponds to v1.7 (no tag has sadly been created :-( )
    svn co http://zxing.googlecode.com/svn/trunk -r 1816 "$CHECKOUT_DIR"
fi

# Check if the source code could be checked out
if [ ! -d "$CHECKOUT_DIR" ]; then
    echo "Source code checkout failure"
    exit 1
fi

# The sources can be used as is. Simply copy files needed by make-fmwk into the source tree
cp "$FRAMEWORK_SETUP_DIR/publicHeaders.txt" "$IPHONE_CHECKOUT_DIR"
cp "$FRAMEWORK_SETUP_DIR/bootstrap.txt" "$IPHONE_CHECKOUT_DIR"

# Build the framework
echo "Creating frameworks..."
cd "$IPHONE_CHECKOUT_DIR"
"$MAKE_SCRIPT" -u "$ZXING_VERSION" Release
"$MAKE_SCRIPT" -u "$ZXING_VERSION" Debug
"$MAKE_SCRIPT" -u "$ZXING_VERSION" -s Debug
