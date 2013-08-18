//
//  HTMLSelector.h
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import "HTMLNode.h"

typedef BOOL (^CSSSelectorPredicate)(HTMLElementNode *node);

extern CSSSelectorPredicate SelectorFunctionForString(NSString* selectorString);

@interface CSSSelector : NSObject

+ (instancetype)selectorForString:(NSString *)selectorString;

- (id)initWithString:(NSString *)selectorString;

@property (readonly, strong, nonatomic) NSError *parseError;

@end

@interface HTMLNode (HTMLSelector)

- (NSArray*)nodesForSelectorString:(NSString *)selectorString;

- (NSArray*)nodesForSelector:(CSSSelector *)selector;

@end
