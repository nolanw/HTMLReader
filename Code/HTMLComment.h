//  HTMLComment.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLCommentNode represents a comment.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html#comments
 */
@interface HTMLComment : HTMLNode

/**
 * This is the designated initializer.
 */
- (id)initWithData:(NSString *)data;

/**
 * The comment itself.
 */
@property (readonly, copy, nonatomic) NSString *data;

@end
