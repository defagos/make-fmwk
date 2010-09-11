#!/bin/bash

# Constants
VERSION_NBR=1.0
SCRIPT_NAME=`basename $0`
# Directory from which the script is executed
EXECUTION_DIR=`pwd`                     
# Build directory
BUILD_DIR="$EXECUTION_DIR/build"
# Directory where all frameworks are saved (for all possible configurations)
FRAMEWORK_COMMON_OUTPUT_DIR="$BUILD_DIR/framework"

# Global variables
param_copy_source_files=false
param_project_name=""
param_sdk_version=""

project_name=""
sdk_version=""

# User manual
usage() {
    echo ""
    echo "This script compiles and packages a static library project into a reusable"
    echo ".framework for iOS projects. The script must be launched from the directory"
    echo "containing the .xcodeproj of a static library project, and will generate"
    echo "framework bundles under the build/framework directory. Build logs will be"
    echo "saved in this directory as well"
    echo ""
    echo "Frameworks are built on a per-configuration basis since a universal binary"
    echo "file can contain at most one binary per platform. The configuration which"
    echo "has been used to generate a framework is appended to its name."
    echo ""
    echo "Usage: $SCRIPT_NAME [-p project_name] [-s] [-v] [-h] configuration_name public_headers_file"
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
    echo "   -k:                    By default the compilation is made against the most"
    echo "                          recent version of the iOS SDK. Use this option to"
    echo "                          use a specific version number, e.g. 4.0"
    echo "   -p:                    If you have multiple projects in the same directory,"
    echo "                          indicate which one must be used using this option"
    echo "   -s:                    Add the complete source code to the bundle file."
    echo "                          Useful for frameworks compiled with debug symbols"
    echo "   -v:                    Print the version number"
    echo ""
}

# Processing command-line parameters
while getopts hk:p:sv OPT; do
    case "$OPT" in
        h)
            usage
            exit 0
            ;;
        k)
            param_sdk_version="$OPTARG"
            ;;  
        p) 
            param_project_name="$OPTARG"
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

# If the last argument is not filled, incomplete command line
if [ -z "$public_headers_file" ]; then
    usage
    exit 1
fi

# Check that the public header file exists
if [ ! -f "$public_headers_file" ]; then
    echo "[Error] The public header file $public_headers_file does not exist"
    exit 1
fi

# If project name not specified, find it
if [ -z "$param_project_name" ]; then
    # Find all .xcodeproj directories. ls does not provide a way to list directories only,
    # we must do this manually
    xcodeproj_list=`ls -l | grep ".xcodeproj" | grep "^d" | awk '{print $9}'`
    
    # Only one project must exist if the -p option is not used
    if [ `echo "$xcodeproj_list" | wc -l` -ne "1" ]; then
        echo "[Error] Several .xcodeproj directories found; use the -p option for disambiguation"
        exit 1
    fi
    
    # We have found our project; strip off the .xcodeproj
    project_name=`echo "$xcodeproj_list" | sed 's/.xcodeproj//g'`
# Else check that the project specified exists
else
    if [ ! -d "$EXECUTION_DIR/$param_project_name.xcodeproj" ]; then
        echo "[Error] The project $param_project_name does not exist"
        exit 1
    fi
    
    project_name="$param_project_name"
fi

# If no SDK version specified, use the latest available
if [ -z "$param_sdk_version" ]; then
    # The showsdks command seems to return SDKs from the oldest to the most recent one. Just
    # keep the last line and extract the version
    sdk_version=`xcodebuild -showsdks | grep iphoneos | tail -n 1 | awk '{print $6}' | sed 's/iphoneos//g'`
# Check that the SDK specified exists
else
    xcodebuild -showsdks | grep -w "iphoneos$param_sdk_version" > /dev/null
    if [ "$?" -ne "0" ]; then
        echo "[Error] Incorrect SDK version, or SDK version not available on this computer"
        exit 1
    fi
    sdk_version="$param_sdk_version"
fi

# Create the main output directory for framework stuff if it does not already exist
if [ ! -d "$FRAMEWORK_COMMON_OUTPUT_DIR" ]; then
    mkdir -p "$FRAMEWORK_COMMON_OUTPUT_DIR"
fi

# Framework name contains build flavor to avoid confusion
framework_name="$project_name-$configuration_name"

# Run the builds
echo "Building $project_name simulator binaries for $configuration_name configuration (SDK $sdk_version)..."
xcodebuild -configuration "$configuration_name" -target "$project_name" -sdk "iphonesimulator$sdk_version" \
    &> "$FRAMEWORK_COMMON_OUTPUT_DIR/$framework_name-simulator.buildlog" 
if [ "$?" -ne "0" ]; then
    echo "Simulator build failed. Check the logs"
    exit 1
fi

echo "Building $project_name device binaries for $configuration_name configuration (SDK $sdk_version)..."
xcodebuild -configuration "$configuration_name" -target "$project_name" -sdk "iphoneos$sdk_version" \
    &> "$FRAMEWORK_COMMON_OUTPUT_DIR/$framework_name-device.buildlog"
if [ "$?" -ne "0" ]; then
    echo "Device build failed. Check the logs"
    exit 1
fi

# Create framework
echo "Creating framework bundle..."

# Framework directory
framework_output_dir="$FRAMEWORK_COMMON_OUTPUT_DIR/$framework_name.framework"

# Cleanup framework if it already existed
if [ -d "$framework_output_dir" ]; then
    echo "Framework already exists. Cleaning up first..."
    rm -rf "$framework_output_dir"
fi

# Create the main framework directory
mkdir -p "$framework_output_dir"

# Create the framework internal structure and symbolic links
# (see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.htm)
mkdir -p "$framework_output_dir/Versions/A/Headers"
mkdir -p "$framework_output_dir/Versions/A/Resources"

# Symbolic links to directories. The link target has to be given as a relative path to where the link file is located,
# otherwise links will break when the framework is moved
ln -s "./A" "$framework_output_dir/Versions/Current"
ln -s "./Versions/Current/Headers" "$framework_output_dir/Headers"
ln -s "./Versions/Current/Resources" "$framework_output_dir/Resources"

# Packing static libraries as universal binaries. For the linker to be able to find the static unversal binaries in the 
# framework bundle, the universal binaries must bear the exact same name as the framework
echo "Packing binaries…"
lipo -create "$BUILD_DIR/$configuration_name-iphonesimulator/lib$project_name.a" \
    "$BUILD_DIR/$configuration_name-iphoneos/lib$project_name.a" \
    -o "$framework_output_dir/Versions/A/$framework_name"
ln -s "./Versions/Current/$framework_name" "$framework_output_dir/$framework_name"

# Load the public header file list into an array (remove blank lines if anys)
echo "Copying public header files…"
public_headers_arr=(`cat "$public_headers_file" | grep -v '^$'`)

# Locate each public file and add it to the framework bundle
for header_file in ${public_headers_arr[@]}
do
    # Header files are copied into the build directories, omit those results
    header_path=`find "$EXECUTION_DIR" -name "$header_file" | grep -v build`
    if [ "$?" -ne "0" ]; then
        echo "[Warning] The header file $header_file appearing in $public_headers_file does not exist"
        continue
    fi
    
    # Copy the header into the bundle
    cp "$header_path" "$framework_output_dir/Versions/A/Headers"
done

# Done
echo "Done."