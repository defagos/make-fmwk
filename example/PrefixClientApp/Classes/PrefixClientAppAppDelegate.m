//
//  PrefixClientAppAppDelegate.m
//  PrefixClientApp
//
//  Created by Samuel Défago on 9/12/10.
//  Copyright Samuel Défago 2010. All rights reserved.
//

#import "PrefixClientAppAppDelegate.h"

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
    // Create an object from the library, here a view controller
    self.simpleViewController = [[[SimpleViewController alloc] init] autorelease];
	[self.window addSubview:self.simpleViewController.view];
    
    [self.window makeKeyAndVisible];
	return YES;
}

#pragma mark Accessors and mutators

@synthesize window = m_window;

@synthesize simpleViewController = m_simpleViewController;

@end
