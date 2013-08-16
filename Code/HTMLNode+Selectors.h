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

@interface HTMLNode (Selectors)

-(NSArray*)nodesForSelectorString:(NSString*)selectorString;
-(NSArray*)nodesForSelectorFilter:(CSSSelectorPredicate)selector;

@end
