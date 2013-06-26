//
//  HTMLTokenizerAssertions.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-16.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTokenizer.h"

static id TokenForTest(id test)
{
    if ([test isKindOfClass:[NSString class]] && [test isEqual:@"ParseError"]) {
        return [HTMLParseErrorToken new];
    }
    NSString *tokenType = test[0];
    if ([tokenType isEqualToString:@"Character"]) {
        return [[HTMLCharacterToken alloc] initWithData:test[1]];
    } else if ([tokenType isEqualToString:@"Comment"]) {
        return [[HTMLCommentToken alloc] initWithData:test[1]];
    } else if ([tokenType isEqualToString:@"StartTag"]) {
        HTMLStartTagToken *startTag = [[HTMLStartTagToken alloc] initWithTagName:test[1]];
        for (NSString *name in test[2]) {
            [startTag addAttributeWithName:name value:[test[2] objectForKey:name]];
        }
        startTag.selfClosingFlag = [test count] == 4;
        return startTag;
    } else if ([tokenType isEqualToString:@"EndTag"]) {
        return [[HTMLEndTagToken alloc] initWithTagName:test[1]];
    } else if ([tokenType isEqualToString:@"DOCTYPE"]) {
        HTMLDOCTYPEToken *doctype = [HTMLDOCTYPEToken new];
        #define NilOutNull(o) ([[NSNull null] isEqual:(o)] ? nil : o)
        doctype.name = NilOutNull(test[1]);
        doctype.publicIdentifier = NilOutNull(test[2]);
        doctype.systemIdentifier = NilOutNull(test[3]);
        doctype.forceQuirks = ![test[4] boolValue];
        return doctype;
    } else {
        return nil;
    }
}

NSArray * ReifiedTokensForTestTokens(NSArray *testTokens)
{
    NSMutableArray *tokens = [NSMutableArray new];
    for (id test in testTokens) {
        [tokens addObject:TokenForTest(test)];
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
