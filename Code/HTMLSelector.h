//
//  HTMLSelector.h
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import "HTMLNode.h"

/**
 * The HTMLSelector class concisely locates a set of nodes in an HTMLDocument.
 *
 * It implements (CSS) Selectors Level 3 http://www.w3.org/TR/css3-selectors/ with the following exceptions:
 *
 *     The link pseudo-classes (:link, :visited) are not supported.
 *     The user action pseudo-classes (:active, :hover, :focus) are not supported.
 *     The target pseudo-class (:target) is not supported.
 *     The :lang() pseudo-class is not supported.
 *     The pseudo-elements ::first-line, ::first-leter, ::before, ::after are not supported.
 */
@interface HTMLSelector : NSObject

/**
 * Initializes a new selector by parsing its string representation.
 *
 * This is the designated initializer.
 *
 * @param selectorString The string representation of a selector.
 *
 * @return An initialized selector that matches the described nodes.
 */
- (id)initWithString:(NSString *)selectorString;

/**
 * Creates and initializes a new selector.
 */
+ (instancetype)selectorForString:(NSString *)selectorString;

/**
 * `nil` if the selector string parsed succesfully, or an NSError instance on failure.
 */
@property (readonly, strong, nonatomic) NSError *parseError;

@end

/**
 * HTMLSelector expands the HTMLNode class to match nodes in the subtree rooted at an instance of HTMLNode.
 */
@interface HTMLNode (HTMLSelector)

/**
 * Returns the nodes matched by selectorString, or nil if the string could not be parsed.
 */
- (NSArray *)nodesForSelectorString:(NSString *)selectorString;

/**
 * Returns the nodes matched by selector, or nil if the selector has a parse error.
 */
- (NSArray *)nodesForSelector:(HTMLSelector *)selector;

@end

/**
 * HTMLNthExpression represents the expression in an :nth-child (or similar) pseudo-class.
 */
typedef struct {
    
    /**
     * The coefficient.
     */
    NSInteger n;
    
    /**
     * The constant.
     */
    NSInteger c;
} HTMLNthExpression;

/**
 * Returns an initialized HTMLNthExpression.
 *
 * @param n The coefficient.
 * @param c The constant.
 */
extern HTMLNthExpression HTMLNthExpressionMake(NSInteger n, NSInteger c);

/**
 * Returns YES if the two expressions are equal, or NO otherwise.
 */
extern BOOL HTMLNthExpressionEqualToNthExpression(HTMLNthExpression a, HTMLNthExpression b);

/**
 * An HTMLNthExpression equivalent to the expression "odd".
 */
extern const HTMLNthExpression HTMLNthExpressionOdd;

/**
 * An HTMLNthExpression equivalent to the expression "even".
 */
extern const HTMLNthExpression HTMLNthExpressionEven;

/**
 * An invalid HTMLNthExpression.
 */
extern const HTMLNthExpression HTMLNthExpressionInvalid;
