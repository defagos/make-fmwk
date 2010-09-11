#!/bin/bash

# Constants
VERSION_NBR=1.0
SCRIPT_NAME=`basename $0`

# Directory from which the script is executed
EXECUTION_DIR=`pwd`

# User manual
usage() {
    echo ""
    echo "This script packages a static library project into a reusable .framework"
    echo "for iOS projects. It must be launched from the directory containing the"
    echo ".xcodeproj directory, and will generate framework bundles in the"
    echo "build/framework directory."
    echo ""
    echo "Frameworks are built on a per-configuration basis. The name of the"
    echo "configuration which has been used to generate a framework will be appended"
    echo "to its name."
    echo ""
    echo "Usage: $SCRIPT_NAME [-s] [-a] [-c configuration_name] [-v] [-h]"
    echo ""
    echo "Options:"
    echo "   -a:                 Build frameworks for all configurations defined"
    echo "                       by the project"
    echo "   -c:                 Build the framework for a specific configuration."
    echo "                       Ignored if -a is used"
    echo "   -h:                 Display this documentation"
    echo "   -s:                 Add source code to the bundle file. Useful"
    echo "                       for debug binaries"
    echo "   -v:                 Print the version number"
    echo ""
}

# Function for generating the framework for a single configuration
# @param $1 configuration name
generate_framework_for_configuration() {
    configuration_name="$1"
    
    # Framework name matches project name
    # TODO: Read from xcodeproj; move outside of this function
    PROJECT_NAME="MyProject"
    
    # Directory where all frameworks will be saved (for all possible configurations)
    framework_common_output_dir="$EXECUTION_DIR/build/framework"
    
    # Framework directory ( 
    framework_output_dir="$framework_common_output_dir/$PROJECT_NAME-$configuration_name.framework"
    
    # Begin framework creation
    echo "Creating framework..."
    
    # Cleanup framework if it already existed
    if [ -d "$framework_output_dir" ]; then
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
}

# Processing command-line parameters
while getopts ac:hsv OPT; do
    case "$OPT" in
        a)
            # TODO: Implement
            exit 0
            ;;
        c)
            # TODO: Move outside this case
            generate_framework_for_configuration "$OPTARG"
            exit 0
            ;;
        h)
            usage
            exit 0
            ;;
        s)
            # TODO: Implement
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


