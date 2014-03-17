//  HTMLComment.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLCommentNode represents a comment.
 */
@interface HTMLComment : HTMLNode

/**
 * Returns an initialized HTMLCommentNode. This is the designated initializer.
 *
 * @param data The comment text.
 */
- (id)initWithData:(NSString *)data;

/**
 * The comment's text.
 */
@property (readonly, copy, nonatomic) NSString *data;

@end
