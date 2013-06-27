//
//  HTMLDocument.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLDocument.h"
#import "HTMLTreeConstructor.h"

@implementation HTMLDocument

- (id)initWithString:(NSString *)string
{
    return [self initWithString:string context:nil];
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    (void)string, (void)context;
    return nil;
}

@end
