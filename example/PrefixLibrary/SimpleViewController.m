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
    // Bundle is here nil, i.e. the main bundle (the only one we can access on iOS). To avoid name
    // conflicts when framework resources are merged with application resources (and maybe resources
    // stemming from other frameworks), resources are prefixed with the library name.
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
    // Localization files are resources and must be prefixed (see above). This of course means that we must 
    // use the appropriate macro for getting the localized string.
    self.label.text = NSLocalizedStringFromTable(@"HelloWorld", @"PrefixLibrary_Localizable", @"Hello, World!");
    
    // As for any resource files, images must bear the framework prefix as well
    self.imageView.image = [UIImage imageNamed:@"PrefixLibrary_apple.jpg"];
}

#pragma mark Accessors and mutators

@synthesize label = m_label;

@synthesize imageView = m_imageView;

@end
