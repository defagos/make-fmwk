//
//  PrettyString.m
//  PrefixLibrary
//
//  Created by Samuel Défago on 11/1/10.
//  Copyright 2010 Samuel Défago. All rights reserved.
//

#import "PrettyString.h"

@implementation NSString (Pretty)

- (NSString *)prettyString
{
    return [NSString stringWithFormat:@"I'm a pretty string: %@", self];
}

@end
