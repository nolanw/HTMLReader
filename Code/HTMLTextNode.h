//  HTMLTextNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLTextNode represents a contiguous sequence of one or more characters.
 */
@interface HTMLTextNode : HTMLNode

/**
 * Returns an initialized HTMLTextNode. This is the designated initializer.
 *
 * @param data The text.
 */
- (id)initWithData:(NSString *)data;

/**
 * The node's text.
 */
@property (readonly, copy, nonatomic) NSString *data;

- (void)appendString:(NSString *)string;

@end
