#!/bin/bash

# Constants
VERSION_NBR=1.0
SCRIPT_NAME=`basename $0`
# Directory from which the script is executed
EXECUTION_DIR=`pwd`                     
# Directory where all frameworks are saved (for all possible configurations)
FRAMEWORK_COMMON_OUTPUT_DIR="$EXECUTION_DIR/build/framework"

# Global variables
param_copy_source_files=false

# User manual
usage() {
    echo ""
    echo "This script packages a static library project into a reusable .framework"
    echo "for iOS projects. It must be launched from the directory containing the"
    echo ".xcodeproj of a static library project, and will generate framework bundles"
    echo "under build/framework"
    echo ""
    echo "Frameworks are built on a per-configuration basis since a universal binary"
    echo "file can contain at most one binary per platform. The configuration which"
    echo "has been used to generate a framework is appended to its name."
    echo ""
    echo "Usage: $SCRIPT_NAME [-s] [-v] [-h] configuration_name public_headers_file"
    echo ""
    echo "Mandatory parameters:"
    echo "   configuration_name     The name of the configuration to use"
    echo "   public_headers_file    A file containing the list of headers use to"
    echo "                          create the framework public interface, one per"
    echo "                          line:"
    echo "                              header1.h"
    echo "                              header2.h"
    echo "                                 ..."
    echo "                              headerN.h"
    echo ""
    echo "Options:"
    echo "   -h:                    Display this documentation"
    echo "   -s:                    Add the complete source code to the bundle file."
    echo "                          Useful for frameworks compiled with debug symbols"
    echo "   -v:                    Print the version number"
    echo ""
}

# Processing command-line parameters
while getopts hsv OPT; do
    case "$OPT" in
        h)
            usage
            exit 0
            ;;
        s)
            param_copy_source_files=true
            exit 0
            ;;
        v)
            echo "$SCRIPT_NAME version $VERSION_NBR"
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

# Read the remaining mandatory parameters
shift `expr $OPTIND - 1`
for arg in "$@"; do
    if [ -z "$configuration_name" ]; then
        configuration_name="$arg"
    elif [ -z "$public_headers_file" ]; then
        public_headers_file="$arg"
    else
       usage
       exit 1
    fi
done

# The last argument is still not filled, incomplete command line
if [ -z "$public_headers_file" ]; then
    usage
    exit 1
fi

# Framework name matches project name
# TODO: Read from xcodeproj; move outside of this function
PROJECT_NAME="MyProject"

# Framework directory ( 
framework_output_dir="$FRAMEWORK_COMMON_OUTPUT_DIR/$PROJECT_NAME-$configuration_name.framework"

# Begin framework creation
echo "Creating framework for configuration $configuration_name..."

# Cleanup framework if it already existed
if [ -d "$framework_output_dir" ]; then
    echo "Framework already exists for configuration $configuration_name. Cleaning up..."
    rm -rf "$framework_output_dir"
fi

# Create the main framework directory
mkdir -p "$framework_output_dir"

# Create the framework internal structure and symbolic links
# (see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.htm)
mkdir -p "$framework_output_dir/Versions/A/Headers"
mkdir -p "$framework_output_dir/Versions/A/Resources"

# Symbolic links. The link target has to be given as a relative path to where the link file is located,
# otherwise links will break when the framework is moved
ln -s "./A" "$framework_output_dir/Versions/Current"
ln -s "./Versions/Current/Headers" "$framework_output_dir/Headers"
ln -s "./Versions/Current/Resources" "$framework_output_dir/Resources" 
ln -s "./Versions/Current/$PROJECT_NAME" "$framework_output_dir/$PROJECT_NAME"

# TODO: Find .a file names for assembling into universal file

# Done
echo "Framework created for configuration $configuration_name"