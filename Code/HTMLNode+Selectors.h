//
//  HTMLNode+Selectors.h
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLNode.h"

typedef BOOL (^CSSSelectorPredicate)(HTMLElementNode *node);

extern CSSSelectorPredicate SelectorFunctionForString(NSString* selectorString);


extern struct mb {int m; int b;} parseNth(NSString *nthString);

@interface CSSSelector : NSObject

+ (instancetype)selectorForString:(NSString *)selectorString;

- (instancetype)initWithString:(NSString *)selectorString;

//String built from the parsing process representing the filter function built
//
//Hopefully the same as the input, possibly without whitespace
@property (readonly) NSString *parsedEquivalent;

//Parsing error
@property (readonly) NSError *error;

@end

@interface HTMLNode (Selectors)

-(NSArray*)nodesForSelectorString:(NSString*)selectorString;
-(NSArray*)nodesForSelector:(CSSSelector*)selector;

@end
