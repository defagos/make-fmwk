#!/bin/bash

# This script must be started from the main project directory (the one containing the xcodeproj)

# Directory from which the script is executed
EXECUTION_DIR=`pwd`

# Inputs
# TODO: Read from script parameters
CONFIGURATION_NAME="Debug"

# Framework name matches project name
# TODO: Read from xcodeproj
FRAMEWORK_NAME="MyFramework"

# Directory where all frameworks will be saved (for all possible configurations)
FRAMEWORK_COMMON_OUTPUT_DIR="$EXECUTION_DIR/build/framework"

# Framework directory ( 
FRAMEWORK_OUTPUT_DIR="$FRAMEWORK_COMMON_OUTPUT_DIR/$FRAMEWORK_NAME-$CONFIGURATION_NAME.framework"

# Begin framework creation
echo "Creating framework..."

# Cleanup framework if it already existed
if [ -d "$FRAMEWORK_OUTPUT_DIR" ]; then
    rm -rf "$FRAMEWORK_OUTPUT_DIR"
fi

# Create the main framework directory
mkdir -p "$FRAMEWORK_OUTPUT_DIR"

# Create the framework internal structure and symbolic links
# (see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.htm)
mkdir -p "$FRAMEWORK_OUTPUT_DIR/Versions/A/Headers"
mkdir -p "$FRAMEWORK_OUTPUT_DIR/Versions/A/Resources"

# Symbolic links. The link target has to be given as a relative path to where the link file is located,
# otherwise links would break when the framework is moved
ln -s "./A" "$FRAMEWORK_OUTPUT_DIR/Versions/Current"
ln -s "./Versions/Current/Headers" "$FRAMEWORK_OUTPUT_DIR/Headers"
ln -s "./Versions/Current/Resources" "$FRAMEWORK_OUTPUT_DIR/Resources" 
ln -s "./Versions/Current/$FRAMEWORK_NAME" "$FRAMEWORK_OUTPUT_DIR/$FRAMEWORK_NAME"

# TODO: Find .a file names for assembling into universal file
