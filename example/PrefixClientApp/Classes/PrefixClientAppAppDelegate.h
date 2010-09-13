//
//  PrefixClientAppAppDelegate.h
//  PrefixClientApp
//
//  Created by Samuel Défago on 9/12/10.
//  Copyright Samuel Défago 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

// Forward declarations
@class SimpleViewController;

/**
 * Designated initializer: init
 */
@interface PrefixClientAppAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *m_window;
    SimpleViewController *m_simpleViewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

