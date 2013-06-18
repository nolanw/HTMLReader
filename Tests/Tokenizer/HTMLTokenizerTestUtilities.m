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
        if ([test isKindOfClass:[NSString class]] && [test isEqual:@"ParseError"]) {
            [tokens addObject:[HTMLParseErrorToken new]];
            continue;
        }
        NSString *tokenType = test[0];
        if ([tokenType isEqualToString:@"Character"]) {
            [tokens addObject:[[HTMLCharacterToken alloc] initWithData:test[1]]];
        } else if ([tokenType isEqualToString:@"Comment"]) {
            [tokens addObject:[[HTMLCommentToken alloc] initWithData:test[1]]];
        } else if ([tokenType isEqualToString:@"StartTag"]) {
            HTMLStartTagToken *startTag = [[HTMLStartTagToken alloc] initWithTagName:test[1]];
            for (NSString *name in test[2]) {
                [startTag addAttributeWithName:name value:[test[2] objectForKey:name]];
            }
            startTag.selfClosingFlag = [test count] == 4;
            [tokens addObject:startTag];
        } else if ([tokenType isEqualToString:@"EndTag"]) {
            [tokens addObject:[[HTMLEndTagToken alloc] initWithTagName:test[1]]];
        } else if ([tokenType isEqualToString:@"DOCTYPE"]) {
            HTMLDOCTYPEToken *doctype = [HTMLDOCTYPEToken new];
            [doctype setValue:test[1] forKey:@"name"];
            [doctype setValue:test[2] forKey:@"publicIdentifier"];
            [doctype setValue:test[3] forKey:@"systemIdentifier"];
            doctype.forceQuirks = ![test[4] boolValue];
        }
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
