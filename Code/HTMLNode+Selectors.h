//
//  HTMLNode+Selectors.h
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLNode.h"

/*
 
Unsupported -> :link, :visited, :active, :hover, :focus, :target, :lang
 
*/

typedef BOOL (^CSSSelectorPredicate)(HTMLElementNode *node);

@interface CSSSelector : NSObject

+ (instancetype)selectorForString:(NSString *)selectorString;

- (instancetype)initWithString:(NSString *)selectorString;

//Parsing error
@property (readonly) NSError *error;

@end

@interface HTMLNode (Selectors)

-(NSArray*)nodesForSelectorString:(NSString*)selectorString;
-(NSArray*)nodesForSelector:(CSSSelector*)selector;

@end
