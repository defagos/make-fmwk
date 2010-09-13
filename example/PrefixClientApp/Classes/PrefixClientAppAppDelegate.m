//
//  PrefixClientAppAppDelegate.m
//  PrefixClientApp
//
//  Created by Samuel Défago on 9/12/10.
//  Copyright Samuel Défago 2010. All rights reserved.
//

#import "PrefixClientAppAppDelegate.h"

// Framework public headers are imported using the < > syntax. We here use the framework obtained by compiling
// the PrefixLibrary static library project using the Debug configuration and the public headers defined in the
// PrefixLibrary publicHeaders.txt file. The framework is obtained by running the make-fmwk.sh command from
// the PrefixLibrary main directory:
//                 /path/where/the/script/is/located/make-fmwk.sh Debug publicHeaders.txt
// The framework is saved into the PrefixLibrary/build/framework directory.
//
// You will probably have to restore the link between this project and the framework (the framework should appear
// in red in the project explorer):
//   1) In the project explorer tree, remove the framework reference under "Frameworks", and add the .framework
//      you have just created.
//   2) Restore the resource links by emptying the "Framework Resources/PrefixLibrary-Debug" folder of the project
//      explorer tree, and by adding the contents of the Resources folder of the .framework bundle you have just
//      created.
#import <PrefixLibrary-Debug/SimpleViewController.h>

@interface PrefixClientAppAppDelegate ()

@property (nonatomic, retain) SimpleViewController *simpleViewController;

@end

@implementation PrefixClientAppAppDelegate

#pragma mark Object creation and destruction

- (id)init
{
    if (self = [super init]) {
        
    }
    return self;
}

- (void)dealloc
{
    self.window = nil;
    self.simpleViewController = nil;
    [super dealloc];
}

#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
    // This is a framework object using its own resources (xib, image, localized string). These resources do not get
    // copied into the client application bundle just by adding the framework. We need to add the resource files
    // explicitly to the project (see "Framework Resources" folder in the project explorer). This way the framework
    // resources get copied into the client application bundle (see "Copy Bundle Resources" under the main target
    // defined for this project), and everything works!
    self.simpleViewController = [[[SimpleViewController alloc] init] autorelease];
	[self.window addSubview:self.simpleViewController.view];
    
    [self.window makeKeyAndVisible];
	return YES;
}

#pragma mark Accessors and mutators

@synthesize window = m_window;

@synthesize simpleViewController = m_simpleViewController;

@end
