//
//  HTMLTokenizer.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-14.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTokenizer.h"

@interface HTMLTokenizer ()

@property (copy, nonatomic) NSString *string;

@end


@implementation HTMLTokenizer

+ (instancetype)tokenizerWithString:(NSString *)string
{
    HTMLTokenizer *tokenizer = [self new];
    tokenizer.string = string;
    return tokenizer;
}

- (id)nextObject
{
    if (self.string) {
        return @[ @[ @"Character", self.string ] ];
    } else {
        return nil;
    }
}

@end
