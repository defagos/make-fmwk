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
param_framework_name=""
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
    echo "a framework pseudo-bundle under the build/framework directory (along with"
    echo "build logs)."
    echo ""
    echo "Frameworks are built on a per-configuration basis since a universal binary"
    echo "file can contain at most one binary per platform. Details about the compilation"
    echo "process are packed into the framework itself."
    echo ""
    echo "Usage: $SCRIPT_NAME [-p project_name] [-o framework_name] [-s] [-v] [-h]"
    echo "                    configuration_name public_headers_file"
    echo ""
    echo "Mandatory parameters:"
    echo "   configuration_name     The name of the configuration to use"
    echo "   public_headers_file    A file containing the list of headers used to"
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
    echo "   -o                     The name of the framework file; if omitted then the"
    echo "                          project name will be used"
    echo "   -p:                    If you have multiple projects in the same directory,"
    echo "                          indicate which one must be used using this option"
    echo "   -s:                    Add the complete source code to the bundle file."
    echo "                          Useful for frameworks compiled with debug symbols"
    echo "                          and intended for in-house developers"
    echo "   -v:                    Print the version number"
    echo ""
}

# Processing command-line parameters
while getopts hk:o:p:sv OPT; do
    case "$OPT" in
        h)
            usage
            exit 0
            ;;
        k)
            param_sdk_version="$OPTARG"
            ;;
        o)
            param_framework_name="$OPTARG"
            ;;
        p) 
            param_project_name="$OPTARG"
            ;;
        s)
            param_copy_source_files=true
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

# If framework name not specified, use project name
if [ -z "$param_framework_name" ]; then
    framework_name="$project_name"
else
    framework_name="$param_framework_name"
fi

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

# .framework files have in general a complicated internal structure for supporting multiple versions
# (see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.htm).
# In the case of a static library framework, we do not need this whole structure since the .framework we define is
# not standardized (in fact it just bears the .framework extension, but it is neither a framework, nor a bundle). To be 
# able to use it with Xcode we just need two conditions to be fulfilled:
#   a) The universal binary to link against must be located at the root of the framework
#   b) A Headers directory must exist, containing all public headers for the library
# This way, when the .framework file is added to an Xcode project, the header files will immediately be available
# and the linker will find the static library.
mkdir -p "$framework_output_dir/Headers"

# Packing static libraries as universal binaries. For the linker to be able to find the static unversal binaries in the 
# framework bundle, the universal binaries must bear the exact same name as the framework
echo "Packing binaries..."
# TODO: These are the standard paths / filenames. In general we should retrieve them from the pbxproj
lipo -create "$BUILD_DIR/$configuration_name-iphonesimulator/lib$project_name.a" \
    "$BUILD_DIR/$configuration_name-iphoneos/lib$project_name.a" \
    -o "$framework_output_dir/$framework_name"

# Load the public header file list into an array (remove blank lines if anys)
echo "Copying public header files..."
public_headers_arr=(`cat "$public_headers_file" | grep -v '^$'`)

# Locate each public file and add it to the framework bundle
for header_file in ${public_headers_arr[@]}
do
    # Header files are also copied into the build directories, need to omit those files
    header_path=`find "$EXECUTION_DIR" -name "$header_file" -not -ipath "*/build/*"`
    if [ -z "$header_path" ]; then
        echo "[Warning] The header file $header_file appearing in $public_headers_file does not exist"
        continue
    fi
    
    # Copy the header into the bundle
    cp "$header_path" "$framework_output_dir/Headers" > /dev/null
    # The copy might fail, most notably if the header file appears several times in the source tree
    if [ "$?" -ne "0" ]; then
        echo "[Warning] Failed to copy $header_path; does this file appear once in your source tree?"
        continue
    fi
done

# Resources files are packed in the .framework directory for convenience (so that all files related to the library
# are collected in a single location), but they still must be added to the project manually. The reason is that the
# static library .framework we create is not a bundle like a real .framework is. A bundle namely must contain executable
# code in order to be loaded, but a static library is not loabdable. A corollary is that there is no way to create bundles
# in the iOS world (except the main bundle which is created for us) since executable code in non-main bundles means dynamic
# libraries. But dynamic libraries cannot be created for iOS (which is also the reason why normal frameworks cannot be 
# made for iOS)!
# Prefixing the resource folder with the library is here just a trick to make it more convenient to use with Xcode (no 
# renaming needed when the library resources are added, and easier to identify in the project explorer)
resources_output_dir="$framework_output_dir/${framework_name}Resources"
mkdir -p "$resources_output_dir"

# Copy all resource files. Since a resource file can be almost anything, we define a resource file:
#   - neither to be a hidden file, nor to be contained in a hidden directory (use find . -not -ipath "*/.*"). This
#     in particular filters out revision control system files
#   - not to be contained in the build directory
#   - not to be a source file (.m, .h or .pch)
#   - not to be contained in the <ProjectName>.xcodeproj folder
#   - not the file listing public headers
# All those files are put in a common flat directory. Localized resources need a special treatment, see below. Note
# that the exclusion patterns below do not remove directories (since they end up with /*), but since cp is used 
# (and not cp -r) they won't be copied. Had we simply used "*/build*"-like patterns, then directories like */buildxyz
# would have been excluded as well, which is incorrect 
echo "Copying resource files..."
resource_files=(`find "$EXECUTION_DIR" \
    -not -ipath "*/.*" \
    -not -ipath "*/build/*" \
    -not -ipath "*.xcodeproj/*" \
    -not -ipath "*.lproj/*" \
    -not -iname "*.m" \
    -not -iname "*.h" \
    -not -iname "*.pch" \
    -not -iname "$public_headers_file"`)
for resource_file in ${resource_files[@]}
do
    cp "$resource_file" "$resources_output_dir" &> /dev/null
done

# Copy localized resources, preserving the directory structure
echo "Copying localized resource files..."
localized_resource_files=(`find . -ipath "*.lproj/*" -not -ipath "*/.*" -not -ipath "*/build/*"`)
for localized_resource_file in ${localized_resource_files[@]}
do
    # Tokenize the path
    path_tokens_arr=(`echo "$localized_resource_file" | tr "/" "\n"`)
    
    # Find the localization directory name
    token_nbr=${#path_tokens_arr[*]}
    localization_dir_name="${path_tokens_arr[$token_nbr-2]}"
    
    # Create the localization directory if it does not exist
    framework_localization_dir_name="$resources_output_dir/$localization_dir_name"
    if [ ! -d "$framework_localization_dir_name" ]; then
        mkdir -p "$framework_localization_dir_name"
    fi
    
    # Copy the resource file
    cp "$localized_resource_file" "$framework_localization_dir_name"
done

# Copy sources if desired (useful when compiled with debugging information)
if $param_copy_source_files; then
    echo "Copying source code..."

    # As for resources, prefixing the source folder with the framework name makes it more convenient to
    # work with Xcode
    sources_output_dir="$framework_output_dir/${framework_name}Sources"
    mkdir -p "$sources_output_dir"
    
    # Copy all source files
    source_files=(`find "$EXECUTION_DIR" -name "*.m"`)
    for source_file in ${source_files[@]}
    do
        cp "$source_file" "$sources_output_dir"
    done
    
    # Copy all header files (omit duplicates in build directory)
    header_files=(`find "$EXECUTION_DIR" -name "*.h" -not -ipath "*/build/*"`)
    for header_file in ${header_files[@]}
    do
        cp "$header_file" "$sources_output_dir"
    done
fi

# Done
echo "Done."