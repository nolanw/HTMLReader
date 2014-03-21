//  HTMLTextNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLTextNode represents text.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html#insert-a-character
 */
@interface HTMLTextNode : HTMLNode

/**
 * This is the designated initializer.
 */
- (id)initWithData:(NSString *)data;

/**
 * The text.
 */
@property (readonly, copy, nonatomic) NSString *data;

/**
 * Adds a string to the end of the node's text.
 */
- (void)appendString:(NSString *)string;

@end
