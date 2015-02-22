//  HTMLComment.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
    An HTMLComment represents a comment.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html#comments
 */
@interface HTMLComment : HTMLNode

/// Initializes a comment with some text.
- (instancetype)initWithData:(NSString *)data NS_DESIGNATED_INITIALIZER;

/// The comment text.
@property (copy, nonatomic) NSString *data;

@end
