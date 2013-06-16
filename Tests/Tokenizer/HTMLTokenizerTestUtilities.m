//
//  HTMLTokenizerAssertions.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-16.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTokenizer.h"

NSArray * ReifiedTokensForTestTokens(NSArray *testTokens)
{
    NSMutableArray *tokens = [NSMutableArray new];
    for (id test in testTokens) {
        if ([test isKindOfClass:[NSString class]]) {
            [tokens addObject:[NSClassFromString([NSString stringWithFormat:@"HTML%@Token", test]) new]];
            continue;
        }
        NSString *tokenType = test[0];
        if ([tokenType isEqualToString:@"Character"]) {
            [tokens addObject:[[HTMLCharacterToken alloc] initWithData:test[1]]];
            continue;
        }
        [tokens addObject:[NSNull null]];
    }
    return tokens;
}

HTMLTokenizerState StateNamed(NSString *name)
{
    static NSDictionary *states;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        states = @{
            @"RCDATA state": @(HTMLTokenizerRCDATAState),
            @"RAWTEXT state": @(HTMLTokenizerRAWTEXTState),
            @"PLAINTEXT state": @(HTMLTokenizerPLAINTEXTState),
        };
    });
    return [states[name] integerValue];
}
