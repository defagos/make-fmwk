//
//  SimpleViewController.h
//  PrefixLibrary
//
//  Created by Samuel Défago on 9/12/10.
//  Copyright 2010 Samuel Défago. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 * Designated initializer: init
 */
@interface SimpleViewController : UIViewController {
@private
    UILabel *m_label;
    UIImageView *m_imageView;
}

@property (nonatomic, retain) IBOutlet UILabel *label;
@property (nonatomic, retain) IBOutlet UIImageView *imageView;

@end
