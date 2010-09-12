//
//  SimpleViewController.m
//  PrefixLibrary
//
//  Created by Samuel Défago on 9/12/10.
//  Copyright 2010 Samuel Défago. All rights reserved.
//

#import "SimpleViewController.h"

@implementation SimpleViewController

#pragma mark Object creation and destruction

- (id)init
{
    // Bundle is nil, i.e. main bundle. The PrefixLibrary framework is designed in such a way that its use
    // requires the client to merge its resources into the main bundle. To avoid name conflicts we add a 
    // prefix to all framework resources
    if (self = [super initWithNibName:@"PrefixLibrary_SimpleViewController" bundle:nil]) {
        
    }
    return self;
}

- (void)dealloc
{
    self.label = nil;
    self.imageView = nil;
    [super dealloc];
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    // As for any resources of the PrefixLibrary framework, localization files end up merged into the main
    // bundle. We must use a separate localization file with a prefix for avoiding conflicts with the usual
    // Localizable.strings file we can probably expect client applications to use. This of course means
    // that we must use the appropriate macro for getting the localized string.
    self.label.text = NSLocalizedStringFromTable(@"HelloWorld", @"PrefixLibrary_Localizable", @"Hello, World!");
    
    // As for any resource files, images must bear the framework prefix as well
    self.imageView.image = [UIImage imageNamed:@"PrefixLibrary_apple.jpg"];
}

#pragma mark Accessors and mutators

@synthesize label = m_label;

@synthesize imageView = m_imageView;

@end
