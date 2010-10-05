#!/bin/bash

# Constants
VERSION_NBR=1.1
SCRIPT_NAME=`basename $0`
EXECUTION_DIR=`pwd`
DEFAULT_FRAMEWORK_LIST_FILE="$EXECUTION_DIR/frameworks.txt"
DEFAULT_FRAMEWORK_REPOSITORY_DIR="$HOME/StaticFrameworks"

# Global variables
param_framework_list_file=""
param_framework_repository_dir=""

framework_list_file=""
framework_repository_dir=""

# User manual
usage() {
    echo ""
    echo "This script generates symbolic links to static frameworks listed by a simple text"
    echo "file. It is intended to make the creation of Xcode project files using frameworks,"
    echo "easier, so that those projects can be compiled anywhere with minimal configuration."
    echo "By storing symbolic links to static frameworks into the project directory (the one"
    echo "containing the .xcodeproj) and by adding those links to the project instead of the"
    echo "frameworks directly, one can namely eliminate system-dependent framework paths from"
    echo "the .pbxproj, making it universal"
    echo "On any computer on which the project is deployed, it then suffices to generate the"
    echo "symbolic links again so that they point to the location of the frameworks on this"
    echo "machine (provided these frameworks are available, of course)."
    echo ""
    echo "The script $SCRIPT_NAME just starts from a text file listing all frameworks required"
    echo "by a project, and looks for the frameworks in a directory in which all frameworks"
    echo "are expected to reside (framework repository)."
    echo ""
    echo "Since the symbolic links themselves are system dependent (they are used to extract"
    echo "all system-dependent paths from the .pbxproj file), they are best added to the"
    echo "list of files to be ignored when committing files to your source code repository."
    echo "One good practice is to create a directory at the same level as the .xcodeproj for"
    echo "symbolic links. This way only this directory has to be ignored. Moreover, if"
    echo "frameworks are replaced, dead links must be discarded, which is easily achieved"
    echo "by getting rid of the directory before generating symbolic links again. For those"
    echo "reasons this script generates all symbolic links into an output directory called"
    echo "StaticFrameworks rooted in the project main directory. The file listing all "
    echo "frameworks required by the project therefore best resides next to the .xcodeproj."
    echo ""
    echo "This script must be started from a directory containing (at least) one .xcodeproj"
    echo ""
    echo "Usage: $SCRIPT_NAME [-f framework_list_file] [-r framework_repository] [-h] [-v]"
    echo ""
    echo "Options:"
    echo "   -f                     A file containing the list of frameworks to generate"
    echo "                          links for, one per line (and without the .staticframework"
    echo "                          extension):"
    echo "                              framework1"
    echo "                              framework2"
    echo "                                 ..."
    echo "                              frameworkN"
    echo "                          If omitted then the script looks for a frameworks.txt"
    echo "                          file in the project directory"    
    echo "   -h:                    Display this documentation"
    echo "   -r                     The location of the framework repository, ~/StaticFrameworks"
    echo "                          if omitted. The directory is not searched recursively"
    echo "   -v:                    Print the script version number"
    echo ""
}

# Processing command-line parameters
while getopts f:hr:v OPT; do
    case "$OPT" in
        f)
            param_framework_list_file="$OPTARG"
            ;;
        h)
            usage
            exit 0
            ;;
        r)
            param_framework_repository_dir="$OPTARG"
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

# Read the remaining mandatory parameters (none)
shift `expr $OPTIND - 1`
for arg in "$@"; do
    usage
    exit 1
done

# Framework list file
if [ -z "$param_framework_list_file" ]; then
    framework_list_file="$DEFAULT_FRAMEWORK_LIST_FILE"
else
    framework_list_file="$param_framework_list_file"
fi

# Framework repository
if [ -z "$param_framework_repository_dir" ]; then
    framework_repository_dir="$DEFAULT_FRAMEWORK_REPOSITORY_DIR"
else
    framework_repository_dir="$param_framework_repository_dir"
fi

# Check that the framework list file exists
if [ ! -f "$framework_list_file" ]; then
    echo "[Error] The framework list file $framework_list_file does not exist"
    exit 1
fi

# Check that the framework repository exists
if [ ! -d "$framework_repository_dir" ]; then
    echo "[Error] The framework repository $framework_repository_dir does not exist"
    exit 1
fi

# Check existence of a .xcodeproj in the directory from which the script is executed
ls "$EXECUTION_DIR" | grep "\.xcodeproj" > /dev/null
if [ "$?" -ne "0" ]; then
    echo "[Error] No Xcode project exists in the current directory"
    exit 1
fi

# Output directory
output_dir="$EXECUTION_DIR/StaticFrameworks"

# Cleanup the output directory if it already existed, ensuring that old framework links are removed
if [ -d "$output_dir" ]; then
    rm -rf "$output_dir"
fi

# Create the output directory
mkdir -p "$output_dir"

# Load the framework list file into an array (remove blank lines if anys)
framework_files_arr=(`cat "$framework_list_file" | grep -v '^$'`)
for framework_file in ${framework_files_arr[@]}
do
    # Check that the static framework exists
    framework_file_path="$framework_repository_dir/$framework_file.staticframework"
    if [ ! -d "$framework_file_path" ]; then
        echo "[Warning] The framework $framework_file_path does not exist"
        continue
    fi
    
    # Create the symbolic link (no link file name specified; it will therefore bear the same name as the
    # directory it points at)
    ln -s "$framework_file_path" "$output_dir"
done