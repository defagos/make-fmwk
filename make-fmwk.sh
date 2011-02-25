#!/bin/bash

# Constants
VERSION_NBR=1.2
SCRIPT_NAME=`basename $0`
# Directory from which the script is executed
EXECUTION_DIR=`pwd`
BUILD_DIR="$EXECUTION_DIR/build"
DEFAULT_BOOTSTRAP_FILE="$EXECUTION_DIR/bootstrap.txt"
DEFAULT_OUTPUT_DIR="$HOME/StaticFrameworks"
DEFAULT_PUBLIC_HEADERS_FILE="$EXECUTION_DIR/publicHeaders.txt"
FORCE_LINK_TAG="FILE_FORCE_LINK"        

# Global variables
param_bootstrap_file=""
param_code_version=""
param_source_files=false
param_log_dir=""
param_lock_output=false
param_omit_version_in_name=false
param_output_dir=""
param_project_name=""
param_public_headers_file=""
param_sdk_version=""
param_target_name=""

log_dir=""
output_dir=""
project_name=""
sdk_version=""

# User manual
usage() {
    echo ""
    echo "This script compiles and packages a static library project into a reusable"
    echo ".staticframework for iOS projects. The script must be launched from the directory"
    echo "containing the .xcodeproj of a static library project, and will generate"
    echo "a pseudo-bundle which can be easily deployed."
    echo ""
    echo ".staticframeworks are built on a per-configuration basis since a universal binary"
    echo "file can contain at most one binary per platform. Details about the compilation"
    echo "process are packed into the framework itself (as a plist manifest file)."
    echo ""
    echo "A file listing all headers to be made public is required. Based on this file,"
    echo "this script also generate a global framework header, usually imported in"
    echo "precompiled header files."
    echo ""
    echo "In some cases, the Objective-C linker will never be able to link code from a"
    echo "library (e.g. source files containing a category for a class defined outside"
    echo "the library). In such cases linkage must usually be forced by setting the -ObjC"
    echo "linker flag in the target settings of the client project. This forces all library"
    echo "object files to be loaded, for all libraries used by this project. Since this can"
    echo "lead to larger executable files than necessary (and to more project configuration"
    echo "steps), this script provides a way to mark only those files for which linkage must"
    echo "be forced (bootstrap file, boostrap.txt by default). Note that the bootstrap file"
    echo "is not required when the source code is packed into the .staticframework."
    echo ""
    echo "To avoid conflicting names when merging framework resources with other"
    echo "framework resources or with application resources, all resource files"
    echo "should be prefixed with the name of the framework. The script generates"
    echo "warnings if this is not the case."
    echo ""
    echo "By default the generated .staticframework file is saved under a common"
    echo " ~/StaticFrameworks directory acting as a framework repository. You can"
    echo "still change the output directory using the -o option. Other build products"
    echo "are still saved under the build directory."
    echo ""
    echo "Usage: $SCRIPT_NAME [-p project_name][-k sdk_version] [-t target_name]"
    echo "         [-u code_version] [-o output_dir] [-l log_dir] [-f public_headers_file]"
    echo "         [-b bootstrap_file] [-n] [-s] [-v] [-h] [-L] configuration_name"
    echo ""
    echo "Mandatory parameters:"
    echo "   configuration_name     The name of the configuration to use"
    echo ""
    echo "Options:"
    echo "   -b:                    Path to the bootstrap file. This file lists"
    echo "                          all source files for which linkage must be forced,"
    echo "                          one per line, e.g.:"
    echo "                              file1.m"
    echo "                              file2.m"
    echo "                                 ..."
    echo "                              fileN.m"
    echo "                          If omitted, the script looks for a file named"
    echo "                          bootstrap.txt in the project directory (if any"
    echo "                          exists)"
    echo "   -f:                    A file containing the list of headers used to"
    echo "                          create the framework public interface, one per"
    echo "                          line:"
    echo "                              header1.h"
    echo "                              header2.h"
    echo "                                 ..."
    echo "                              headerN.h"
    echo "                          If omitted, the script looks for a file named"
    echo "                          publicHeaders.txt in the project directory"
    echo "   -h:                    Display this documentation"
    echo "   -k:                    By default the compilation is made against the most"
    echo "                          recent version of the iOS SDK. Use this option to"
    echo "                          use a specific version number, e.g. 4.0"
    echo "   -l:                    Output directory for log files (build directory"
    echo "                          if omitted)"
    echo "   -L:                    Lock the .staticframework output files to prevent from"
    echo "                          accidental changes"
    echo "   -n:                    By default, if the code version is specified it is"
    echo "                          appended to the framework name. This allows projects"
    echo "                          to be bound to specific framework versions. If -n"
    echo "                          is used, the version number is not appended (if the"
    echo "                          -t option was not used, -n has no effect)"
    echo "   -o                     Output directory where the .staticframework will be"
    echo "                          saved. If not specified, ~/StaticFrameworks is used"
    echo "   -p:                    If you have multiple projects in the same directory,"
    echo "                          indicate which one must be used using this option"
    echo "                          (without the .xcodeproj extension)"
    echo "   -s:                    Pack the complete source code into the static framework."
    echo "                          Useful for debugging purposes"
    echo "   -t:                    Target to be used. If not specified the first target"
    echo "                          will be built"
    echo "   -u                     Tag identifying the version of the code which has"
    echo "                          been compiled. Added to framework.info and appended"
    echo "                          to the framework name if -n is not used"
    echo "   -v:                    Print the script version number"
    echo ""
}

# Set internal field separator for for loops; otherwise for loops on paths arrays won't work
# if a path contains a space (since the default IFS contains space as well)
# TODO: Should be more local or replaced by find -exec {}. This can have undesired global effects
#       we should strive to avoid
IFS=$'\n'

# Checking that the name of a file, given its path, begins with a given prefix
#   @param $1 the resource path
#   @param $2 the prefix
check_prefix() {
    file_name="${1##*/}"
        echo "$file_name" | grep "^${2}_" &> /dev/null
        if [ "$?" -ne "0" ]; then
            echo "[Warning] The resource file $file_name should be prefixed with ${2}_"
            echo "          to avoid conflicts with other resources"
        fi
}

# Processing command-line parameters
while getopts b:f:hk:l:Lno:p:st:u:v OPT; do
    case "$OPT" in
        b)
            param_bootstrap_file="$OPTARG"
            ;;  
        f)
            param_public_headers_file="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        k)
            param_sdk_version="$OPTARG"
            ;;
        l)
            param_log_dir="$OPTARG"
            ;;
        L)
            param_lock_output=true
            ;;
        n)
            param_omit_version_in_name=true;
            ;;
        o)
            param_output_dir="$OPTARG"
            ;;
        p) 
            param_project_name="$OPTARG"
            ;;
        s)
            param_source_files=true
            ;;
        t)
            param_target_name="$OPTARG"
            ;;
        u)
            param_code_version="$OPTARG"
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
    else
       usage
       exit 1
    fi
done

# If the last argument is not filled, incomplete command line
if [ -z "$configuration_name" ]; then
    usage
    exit 1
fi

# Public headers file
if [ -z "$param_public_headers_file" ]; then
    public_headers_file="$DEFAULT_PUBLIC_HEADERS_FILE"
else
    public_headers_file="$param_public_headers_file"
fi

# Check that the public header file exists
if [ ! -f "$public_headers_file" ]; then
    echo "[Error] The public header file $public_headers_file does not exist"
    exit 1
fi

# Bootstrap file
if [ -z "$param_bootstrap_file" ]; then
    bootstrap_file="$DEFAULT_BOOTSTRAP_FILE"
else
    # Check that the specified file exists
    if [ ! -f "$param_bootstrap_file" ]; then
        echo "[Error] The specified bootstrap file $param_bootstrap_file does not exist"
        exit 1
    fi
    bootstrap_file="$param_bootstrap_file"
fi

# If project name not specified, find it
if [ -z "$param_project_name" ]; then
    # Find all .xcodeproj directories. ls does not provide a way to list directories only,
    # we must do this manually
    xcodeproj_list=`ls -l | grep ".xcodeproj" | grep "^d"`
    
    # Not found
    if [ "$?" -ne "0" ]; then
        echo "[Error] No .xcodeproj directory found"
        exit 1
    fi
    
    # Several projects found
    if [ `echo "$xcodeproj_list" | wc -l` -ne "1" ]; then
        echo "[Error] Several .xcodeproj directories found; use the -p option for disambiguation"
        exit 1
    fi
    
    # Extract the project name, stripping off the .xcodeproj
    project_name=`echo "$xcodeproj_list" | awk '{print $9}' | sed 's/.xcodeproj//g'`
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
    sdk_version=`xcodebuild -showsdks | grep iphoneos | tail -n 1 | sed -E 's/^.*iphoneos([0-9.]*)\s*$/\1/g'`
# Check that the SDK specified exists
else
    xcodebuild -showsdks | grep -w "iphoneos$param_sdk_version" > /dev/null
    if [ "$?" -ne "0" ]; then
        echo "[Error] Incorrect SDK version, or SDK version not available on this computer"
        exit 1
    fi
    sdk_version="$param_sdk_version"
fi

# Output directory
if [ -z "$param_output_dir" ]; then
    output_dir="$DEFAULT_OUTPUT_DIR"
else
    output_dir="$param_output_dir"
fi

# Create the output directory if it does not exist
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

# Log directory (same as build directory if not specified)
if [ -z "$param_log_dir" ]; then
    log_dir="$BUILD_DIR"
else
    log_dir="$param_log_dir"
fi

# Create the log directory if it does not exist
if [ ! -d "$log_dir" ]; then
    mkdir -p "$log_dir"
fi

# Target parameter
if [ ! -z "$param_target_name" ]; then
    target_parameter="-target $param_target_name"
fi

# Framework name matches project name; by default the code version (if available) is appended, except
# if this behavior is overriden (no warning, the user knows what shes is doing)
framework_name="$project_name"
if [ ! -z "$param_code_version" ]; then
    if $param_omit_version_in_name; then
        framework_full_name="$framework_name-$configuration_name"
    else
        framework_full_name="$framework_name-$param_code_version-$configuration_name"
    fi
# Warns if no version specified (good practice)
else
    echo "[Info] You should provide a code version for better traceability; use the -u option"
    framework_full_name="$framework_name-$configuration_name"
fi

# If sources are packaged within the framework, appends an additional extension
if $param_source_files; then
    framework_full_name="$framework_full_name-src"
fi

# Create framework
echo "Creating framework pseudo-bundle..."

# Framework directory
framework_output_dir="$output_dir/$framework_full_name.staticframework"

# Cleanup framework if it already existed
if [ -d "$framework_output_dir" ]; then
    echo "Framework already exists. Cleaning up first..."
    
    # Restore write permissions (if any were set)
    find "$output_dir" -path "*/$framework_full_name.staticframework/*" -exec chmod u+w {} \;
    
    rm -rf "$framework_output_dir"
fi

# Create the main framework directory
mkdir -p "$framework_output_dir"

# Creation of the bootstrap code for selective forced linking (not required when the source code has been included;
# in this case the linker will find everything it needs)
if ! $param_source_files; then
    echo "Generating bootstrap code..."
    bootstrap_output_dir="$framework_output_dir/Bootstrap"
    mkdir -p "$bootstrap_output_dir"
    bootstrap_output_file="$bootstrap_output_dir/${framework_name}_bootstrap.m"
    echo "// This file is automatically generated; please do not modify" > "$bootstrap_output_file"
    
    # Bootstrap function name is framework name without characters forbidden for function names
    framework_name_clean=`echo "$framework_name" | sed 's/[-+]//g'`
    
    # Begin of the bootstrap function code
    bootstrap_function="\nvoid ${framework_name_clean}_bootstrap()\n{"
    
    # Add bootstrapping code to all classes listed in the bootstrap file (if any)
    if [ -f "$bootstrap_file" ]; then
        bootstrapped_files_arr=(`cat "$bootstrap_file" | grep -v '^$'`)
        for bootstrapped_file in ${bootstrapped_files_arr[@]}
        do
            # Locate the source file
            bootstrapped_path=`find "$EXECUTION_DIR" -name "$bootstrapped_file" -not -path "*/build/*"`
            if [ -z "$bootstrapped_path" ]; then
                echo "[Warning] The source file $bootstrapped_file appearing in the bootstrap file $bootstrap_file does not exist"
                continue
            fi
            
            # Make a backup copy first, we will add some dummy class to the source file to force linkage with it
            cp "$bootstrapped_path" "$bootstrapped_path.backup"
            
            # Extract file name witout extension
            file_name=`basename $bootstrapped_path`
            file_name=${file_name%.*}
            
            # Class name is file name without characters forbidden for class names
            file_name_clean=`echo "$file_name" | sed 's/[-+]//g'`
            
            # Add a dummy class declaration and definition to the source file. This definition is added at the end of the file
            # to leave line numbers intact in comparison to the original source files (useful if the original code logs source
            # file line numbers for debugging purposes)
            linker_class_interface="\n@interface ${file_name_clean}_Linker\n+ (void)link;\n@end\n"
            linker_class_implementation="\n@implementation ${file_name_clean}_Linker\n+ (void)link {}\n@end\n"
            echo -e "$linker_class_interface" >> "$bootstrapped_path"
            echo -e "$linker_class_implementation" >> "$bootstrapped_path"
            
            # Repeat dummy class interface in bootstrap file; this way we avoid the need for a common header file listing all
            # dummy classes
            echo -e "$linker_class_interface" >> "$bootstrap_output_file"
            
            # Call the static dummy class method from the bootstrap function
            bootstrap_function="$bootstrap_function\n\t[${file_name_clean}_Linker link];"
        done
    else
        echo "[Info] No bootstrap file has been provided"
    fi
    
    # End of the bootstrap function; add it to the bootstrap source file
    bootstrap_function="$bootstrap_function\n}"
    echo -e "$bootstrap_function" >> "$bootstrap_output_file"
fi

# Run the builds (with bootstrap code if any). The build directory (SYMROOT) overrides the one in the .pbxproj. This way we do
# not have to parse the .pbxproj to find the SYMROOT to use with the lipo command (see below)
build_failure=false
echo "Building $project_name simulator binaries for $configuration_name configuration (SDK $sdk_version)..."
xcodebuild -configuration "$configuration_name" -project "$project_name.xcodeproj" -sdk "iphonesimulator$sdk_version" \
    $target_parameter "SYMROOT=$BUILD_DIR" &> "$log_dir/$framework_full_name-simulator.buildlog" 
if [ "$?" -ne "0" ]; then
    echo "Simulator build failed. Check the logs"
    build_failure=true
fi

echo "Building $project_name device binaries for $configuration_name configuration (SDK $sdk_version)..."
xcodebuild -configuration "$configuration_name" -project "$project_name.xcodeproj" -sdk "iphoneos$sdk_version" \
    $target_parameter "SYMROOT=$BUILD_DIR" &> "$log_dir/$framework_full_name-device.buildlog"
if [ "$?" -ne "0" ]; then
    echo "Device build failed. Check the logs"
    build_failure=true
fi

# Restore the original source code without bootstrapping code (only if source code not bundled, see above)
if ! $param_source_files; then
    if [ -f "$bootstrap_file" ]; then
        bootstrapped_files_arr=(`cat "$bootstrap_file" | grep -v '^$'`)
        for bootstrapped_file in ${bootstrapped_files_arr[@]}
        do
            # Locate the source file
            bootstrapped_path=`find "$EXECUTION_DIR" -name "$bootstrapped_file" -not -path "*/build/*"`
            if [ -z "$bootstrapped_path" ]; then
                # We already issued a warning previously, just skip
                continue
            fi
            
            # Restore the original file
            mv "$bootstrapped_path.backup" "$bootstrapped_path"
        done
    fi
fi

# Exit on failure
if $build_failure; then
    exit 1
fi

# Create .framework directory
dot_framework_output_dir="$framework_output_dir/$framework_name.framework"

# .framework files have in general a complicated internal structure for supporting multiple versions
# (see http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPFrameworks/Tasks/CreatingFrameworks.htm).
# In the case of a static library framework, we do not need this whole structure since the .framework we define is
# not standardized (in fact it just bears the .framework extension, but it is neither a framework, nor a bundle). To be 
# able to use it with Xcode we just need two conditions to be fulfilled:
#   a) The universal binary to link against must be located at the root of the framework
#   b) A Headers directory must exist, containing all public headers for the library
# This way, when the .framework file is added to an Xcode project, the header files will immediately be available
# and the linker will find the static library.
headers_output_dir="$dot_framework_output_dir/Headers"
mkdir -p "$headers_output_dir"

# Packing static libraries as universal binaries. For the linker to be able to find the static unversal binaries in the 
# framework bundle, the universal binaries must bear the exact same name as the framework
echo "Packing binaries..."
lipo -create "$BUILD_DIR/$configuration_name-iphonesimulator/lib$project_name.a" \
    "$BUILD_DIR/$configuration_name-iphoneos/lib$project_name.a" \
    -o "$dot_framework_output_dir/$framework_name"

# Load the public header file list into an array (remove blank lines if anys)
echo "Copying public header files..."
public_headers_arr=(`cat "$public_headers_file" | grep -v '^$'`)

# Locate each public file and add it to the framework bundle
for header_file in ${public_headers_arr[@]}
do
    # Header files are also copied into the build directories, need to omit those files
    header_path=`find "$EXECUTION_DIR" -name "$header_file" -not -path "*/build/*"`
    if [ -z "$header_path" ]; then
        echo "[Warning] The header file $header_file appearing in $public_headers_file does not exist"
        continue
    fi
    
    # Copy the header into the bundle
    cp "$header_path" "$headers_output_dir" > /dev/null
    # The copy might fail, most notably if the header file appears several times in the source tree
    if [ "$?" -ne "0" ]; then
        echo "[Warning] Failed to copy $header_path; does this file appear once in your source tree?"
        continue
    fi
done

# Create a global header file bearing the name of the framework
global_header_file="$headers_output_dir/$framework_name.h"
if [ ! -f "$global_header_file" ]; then
    echo "// This file is automatically generated; please do not modify" > "$global_header_file"

    # The precompiled header file (if any) is header for all files; start the global header with its contents
    precompiled_header_files=(`find "$EXECUTION_DIR" -name "*.pch"`)
    
    # One precompiled header file should exist, not several. Anyway, looping over the results does not hurt,
    # and correctly deals with the case where no such file exists
    for precompiled_header_file in ${precompiled_header_files[@]}
    do
        cat "$precompiled_header_file" | grep "#import" >> "$global_header_file"
    done
    
    # Include all public headers
    for header_file in ${public_headers_arr[@]}
    do
        echo "#import <$framework_name/$header_file>" >> "$global_header_file"
    done
# Warn if a public header with this name already exists
else
    echo "[Warning] A public header file bearing the same name as the framework already exists; cannot create"
    echo "          the global framework header"
fi

# Resources files are packed in the .framework directory for convenience (so that all files related to the library
# are collected in a single location), but they still must be added to the project manually. The reason is that the
# static library .framework we create is not a bundle like a real .framework is. A bundle namely must contain executable
# code in order to be loaded, but a static library is not loabdable. A corollary is that there is no way to create bundles
# in the iOS world (except the main bundle which is created for us) since executable code in non-main bundles means dynamic
# libraries. But dynamic libraries cannot be created for iOS (which is also the reason why normal frameworks cannot be 
# made for iOS)!
# Prefixing the resource folder with the library is here just a trick to make it more convenient to use with Xcode (no 
# renaming needed when the library resources are added, and easier to identify in the project explorer)
resources_output_dir="$framework_output_dir/Resources"
mkdir -p "$resources_output_dir"

# Copy all resource files. Since a resource file can be almost anything, we define a resource file:
#   - neither to be a hidden file, nor to be contained in a hidden directory (use find . -not -path "*/.*"). This
#     in particular filters out revision control system files
#   - not to be contained in the build directory
#   - not to be a source file (.m, .h, .c, .C, .cpp, .mm or .pch)
#   - not to be contained in the <ProjectName>.xcodeproj folder
#   - not the file listing public headers
#   - not the bootstrap file
# All those files are put in a common flat directory. Localized resources need a special treatment, see below. Note
# that the exclusion patterns below do not remove directories (since they end up with /*), but since cp is used 
# (and not cp -r) they won't be copied. Had we simply used "*/build*"-like patterns, then directories like */buildxyz
# would have been excluded as well, which is incorrect 
echo "Copying resource files..."
resource_files=(`find "$EXECUTION_DIR" \
    -not -path "*/.*" \
    -not -path "*/build/*" \
    -not -path "*.xcodeproj/*" \
    -not -path "*.lproj/*" \
    -not -name "*.m" \
    -not -name "*.mm" \
    -not -name "*.c" \
    -not -name "*.cpp" \
    -not -name "*.h" \
    -not -name "*.pch" \
    -not -path "$public_headers_file" \
    -not -name "$public_headers_file" \
    -not -path "$bootstrap_file" \
    -not -name "$bootstrap_file"`)
for resource_file in ${resource_files[@]}
do
    cp "$resource_file" "$resources_output_dir" &> /dev/null
    
    # Those files which could be copied are resources; check that their name begin with a prefix (strongly advised)
    if [ "$?" -eq "0" ]; then
        check_prefix "$resource_file" "$framework_name"
    fi
done

# Copy localized resources, preserving the directory structure
echo "Copying localized resource files..."
localized_resource_files=(`find . -path "*.lproj/*" -not -path "*/.*" -not -path "*/build/*"`)
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
    
    # Those files which could be copied are resources; check that their name begin with a prefix (strongly advised)
    if [ "$?" -eq "0" ]; then
        check_prefix "$localized_resource_file" "$framework_name"
    fi
done

# Copy only sources if desired (useful for debugging purposes)
if $param_source_files; then
    echo "Copying source code..."

    # As for resources, prefixing the source folder with the framework name makes it more convenient to
    # work with Xcode
    sources_output_dir="$framework_output_dir/Sources"
    mkdir -p "$sources_output_dir"
    
    # Copy all source files
    source_files=(`find "$EXECUTION_DIR" \( -name "*.m" -o -name "*.mm" -o -name "*.c" -o -name "*.C" -o -name "*.cpp" \) -not -path "*/build/*"`)
    for source_file in ${source_files[@]}
    do
        cp "$source_file" "$sources_output_dir"
    done
    
    # Copy all header files (omit duplicates in build directory)
    header_files=(`find "$EXECUTION_DIR" -name "*.h" -not -path "*/build/*"`)
    for header_file in ${header_files[@]}
    do
        cp "$header_file" "$sources_output_dir"
    done
fi

# Add a manifest file
echo "Creating manifest file..."
manifest_file="$dot_framework_output_dir/$framework_name-staticframework-Info.plist"
echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" >> "$manifest_file"
echo "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/echo PropertyList-1.0.dtd\">" >> "$manifest_file"
echo "<plist version=\"1.0\">" >> "$manifest_file"
echo "<dict>" >> "$manifest_file"
echo "	<key>Project compiled</key>" >> "$manifest_file"
echo "	<string>$project_name</string>" >> "$manifest_file"
if [ ! -z "$param_code_version" ]; then
    echo "	<key>Code version</key>" >> "$manifest_file"
    echo "	<string>$param_code_version</string>" >> "$manifest_file"
fi
echo "	<key>Configuration used</key>" >> "$manifest_file"
echo "	<string>$configuration_name</string>" >> "$manifest_file"
echo "	<key>iOS SDK version used</key>" >> "$manifest_file"
echo "	<string>$sdk_version</string>" >> "$manifest_file"
echo "	<key>make-fmwk version</key>" >> "$manifest_file"
echo "	<string>$VERSION_NBR</string>" >> "$manifest_file"
echo "	<key>Creation date and time</key>" >> "$manifest_file"
echo "	<string>`date`</string>" >> "$manifest_file"

# List all framework dependencies; those are created before running make_fmwk.sh by using the link_fmwk.sh script. The generated
# symbolic links are always saved under ./StaticFrameworks
if [ -d "./StaticFrameworks" ]; then
    echo "  <key>Static framework dependencies</key>" >> "$manifest_file"
    echo "  <array>" >> "$manifest_file"
    static_framework_dependencies=(`ls -1 "./StaticFrameworks"`)
    for static_framework_dependency in ${static_framework_dependencies[@]}
    do
        echo "    <string>$static_framework_dependency</string>" >> "$manifest_file"
    done
    echo "  </array>" >> "$manifest_file"
fi

echo "</dict>" >> "$manifest_file"
echo "</plist>" >> "$manifest_file"

# Lock all .staticframework contents to prevent the user from accidentally editing them within Xcode
if $param_lock_output; then
    find "$output_dir" -path "*/$framework_full_name.staticframework/*" -exec chmod a-w {} \;
fi

# Done
echo "Done creating $framework_full_name."
