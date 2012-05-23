### Introduction

Xcode offers a framework creation project template for MacOS applications, but no such template is provided for iOS. This probably stems from the fact that a framework is an `NSBundle` containing code, of which no other instance than the main bundle usually exists on iOS.

But still one should have a way of reusing library code. And in fact there is one, since Xcode provides a static library project template. But working with static libraries has some drawbacks:

* you can only link with one `.a` at once. How do you manage multiple architectures each with its `.a` file?
* header files for the library must be provided separately and included by the client project
* resources must also be provided separately

Usually, to avoid these drawbacks, projects directly import the source code of a library into their own source code. But this does not work so well either:
 
* there is a strong likelihood that the programmer is tempted to change the library source code directly within her project
* the number of source files to be compiled and the compilation time increase. Often, programmers just delete those source files they are not interested in, but this is not really convenient. Moreover, when the library is updated, the set of source code files required may change
* frameworks whose source code must be kept secret cannot be used this way
* as compiler tools evolve and default project settings are tightened, new warnings are likely to appear when compiling library code, cluttering your own project logs
    
Though there is no way to build a framework around a static library using an official Xcode template (alternatives exist, see e.g. https://github.com/kstenerud/iOS-Universal-Framework), it is still possible to package binaries, headers and resources for easier reuse. This is just what `make-fmwk` is made for.

The following is inspired by Pete Goodliffe's article published on accu.org: http://accu.org/index.php/articles/1594

### Background

When a standard `.framework` directory (created using the Xcode template for MacOS) is added to Xcode, two things happen:

* Xcode looks for a dynamic library file located at the root of this directory, and bearing the same name as the `.framework`
* Xcode also looks for a `Headers` directory containing the headers defining the framework public interface. These can then be imported by clients using `#import <framework_name/header_name.h>`. More precisely, the structure of a MacOS framework is made of symbolic links and directories to handle various versions of a library within the same `.framework`. Refer to the MacOS framework programming guide for more information.

The binary file located at the root of the `.framework` directory does not need to be diretctly executable, though. It can also be a universal binary file, created by the `lipo` command which brings together binaries compiled for different architectures. The linker then just figures out which `.a` it needs when a project is compiled, and extracts it from the universal binary file. Therefore, it is possible to create "fake" frameworks wrapping a static library. Though these frameworks are not frameworks in the Xcode sense, Xcode will happily deal with them and discover their content. For iOS frameworks (which do not embed a dynamic library), we do not need to create the whole directory structure and symbolic links needed to support different versions. Only one version will always be available, creating such a structure would therefore be overkill.

Based on this knowledge, the `make-fmwk` script creates a "static" `.framework` (i.e. containing a static library) with the internal structure expected by Xcode. This framework, in fact a directory with the `.staticframework` extension, can then be simply added to an Xcode project and contains everything the library needs (including resources if any).

The `.staticframework` being added to the project directly, the resources it contains will be copied at the root level of the final application bundle when the application is assembled. Having all resources merged in the same bundle root directory means that we must strive to avoid conflicting resources. The best approach is to use a bundle to pack library resources. This is not required by `make-fmwk`, though, but if you do not use a bundle `make-fmwk` will display warnings if you do not prefix all resources with `<LibraryName>_` to avoid conflicts.

### How to create a static framework

Here is how you usually should setup a project so that `make-fmwk` can be run on it to create a `.staticframework`:

* Create a static library project for iOS
* Add files as you normally do. You can create any physical / logical structure you want. You should create a bundle for your resources (I recommend using a dedicated project which your static library project must depend on). Alternatively you may choose to prefix all resource files with `<LibraryName>_`, but this leads to issues if you have localized files (you then need to manage those localization files in your client application to avoid keeping those you do not need. This is not required if the localized source files are hidden in a bundle)
* Create a `publicHeaders.txt` file listing all headers building the framework public interface. This file is usually stored in the project root directory
* If linkage issues arise (in general because of source files containing only a category, or with classes meant to be used in nibs), create a `bootstrap.txt` file, stored in the project root directory, and listing all source files for which linkage must be forced
* Run `make-fmwk.sh` from the project root directory to create the `.staticframework`. Use the `-o` flag to save it in the directory of your choice, and the `-u` flag to provide a version number
     
### How to use a static framework

* Open an iOS application project
* Add the `.staticframework` of your library to your project (by adding it to your project file tree, or by drag and drop)
* When you need to include a library header file, use the `#import <file.h>` syntax. `make-fmwk` also creates a global header file from the public headers declared by the library, I usually recommend adding this file to your project precompiled header file

### Working with static framework versions

It is strongly advised to tag frameworks using the `-u` option. Projects using static frameworks can then specify which version they are using since (by default) the version number is appended to the `.staticframework` name.

### Linkage considerations

Due to the highly dynamic nature of the Objective-C language, any method defined in a library might be called, explicitly or in hidden ways (e.g. by using `objc_msgSend`). Unlike C / C++, we would therefore expect the linker to be especially careful when stripping dead-code from Objective-C static libraries. In some cases, though, the linker still drops code it considers to be unused. Such code can still be referenced from an application, though, and I ran into the following issues:

* Categories defined for objects not in the library: If such categories are defined "alone" in a source file, the linker will not load the corresponding code, and you will get an "Unrecognized selector" exception at runtime. This problem can also arise even if the category is not alone, provided the linker has no other reason to link with the object file it is contained in. For more information, refer to the following article: http://developer.apple.com/library/mac/#qa/qa2006/qa1490.html
* When using library objects in Interface Builder, you might get an "Unknown class <class> in Interface Builder file" error in the console at runtime. If the library class inherits from an existing `UIKit` class, your application will not crash, but you will not get the new functionality your class implements, leading to incorrect behavior.

The article mentioned above gives a solution to this problem: Add the `-ObjC` flag to the "Other linker flags" setting. For categories the `-all_load` also had to be added, as explained in the article, but this has been fixed by the new LLVM compiler.

Tweaking linker flags works but is far from being optimal, though:

* it leads to unnecessarily larger executable sizes
* it affects all libraries which a client application is linked against
* it has to be set manually for each client project
* it has to be documented when you distribute a library, and you can expect users to forget or not set these flags correctly. Moreover, users can easily set parameters incorrectly for some but not all of their targets, which can lead to unpleasant debugging nights
     
There is a way to avoid having to set those linker flags, though. It is namely possible to fool the linker into thinking an object file must not be discarded. This is made possible by the fact that if the linker really seems to require something from a file, it will link all of it, even if the code in the remaining of the file is not directly required.

To achieve this result, this script proceeds as follows:

* The script reads a file as input (`bootstrap.txt` by default), which lists all source files for which linking must be forced.
* Each of these source files is then appended a dummy class (whose name comprises the name of the file to avoid clashes). Both the definitions and the declarations are added to the source file in order to avoid the need for an additional header. A backup of the original source file is made, and the dummy class is appended to its end so that the original line numbers are kept intact (debugging can therefore still be performed with the original set of source files). The dummy class itself does nothing more than exposing an empty class method.
* The library is compiled with the modified source code files, then the original files are restored.
* A bootstrap source file is created, which repeats the dummy class definitions (we namely have no header files for them). A dummy function is added to call the class method for all dummy classes. This file is saved into the static framework package as is.

When a static framework is added to a project, the bootstrap code gets compiled as well. Even if the dummy function it contains is not used, the linker will happily load all dummy classes it references since their class method is called. This prevents the linker from discarding the translation units they are defined in, leading to the desired effect.
 
#### Remark

When the source code is bundled into the `.staticframework`, no bootstrapping is needed. Since the whole source code is available, the linking will not be as aggressive as it is when linking to a static library. In such cases the bootstrapping file will be ignored, even if provided.
 
### Troubleshooting

#### 'I get an “Unknown class <class> in Interface Builder file" error in the console at runtime' or 'I get a "selector not recognized" exception when calling a category method stemming from a static library'

This probably means that some of the source files should be added to your bootstrap definition file. If you have access to the framework code, identify those files (in general they contain a category or a class which can is meant to be used in Interface Builder), update the bootstrap definition file and build the framework again. Alternatively you can add the `-ObjC` (and maybe `-all_load`) flag to your project target(s) and start the build again, but keep in mind this will result in increased executable size.

### Example

For an example of a project which can be compiled using `make-fmwk`, check out my CoconutKit project (https://github.com/defagos/CoconutKit).

### Known issues

In general, with a default Xcode static library project, the name of the `.a` file matches the one of the `.xcodeproj` itself. An exception to this rule is when a project name contains hyphens. In such cases those are replaced by underscores to obtain the name of the `.a` file. In such cases the script will not work since it assumes that the library name is the same as the project name when locating the `.a` files for the lipo command.

The same issue affects projects for which the output file name has been changed and does not match the one of the `.xcodeproj` anymore. In such cases, you will have to rename the output file in your project file.

Finally, you might encounter linker issues when using some static frameworks. Those can currently (and sadly) only be solved by editing your client project settings to fix the linker behavior (within Xcode, double-click the project, and under the "Build" tab search for the "Other Linker Flags" setting). Most notably:

* if the static framework uses `libxml` internally, you need either to add `-lxml2` to your project "Other Linker Flags" setting, or to add `libxml2.dylib` to your project frameworks, otherwise you will get unresolved symbols. You will also need to add `$(SDKROOT)/usr/include/libxml2` to your project "Header search path" if one of the `libxml` headers is included from a framework header file
* if the static framework was created by compiling C++ files, the client project cannot know it must link against the C++ runtime, and you will get unresolved symbols. This is fixed by adding `-lstdc++` to your project "Other Linker Flags" setting

### Adapters

Since this tool is not mainstream (and is unlikely to be), some projects cannot be used as is with the `make-fmwk` command. For some projets I find helpful, I will provide adapters which checkout the original source code and create a project that `make-fmwk` will be happy to deal with. Those are found under the `adapters` directory, and you simply need to run the provided `generate.sh` script to checkout the code, create the project and build the `.staticframework`s (which are saved into `~/StaticFrameworks`).

### Version history

* 1.0 (September 2010): Initial release
* 1.1 (October 2010): Convention over configuration philosophy. Easier to use
* 1.2 (October 2010): Ability to force link for specific files. Other minor improvements
* 1.3 (May 2012): Minor fixes for Xcode 4, removal of the useless `link-fmwk.sh` command, and shortened documentation
