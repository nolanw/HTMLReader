//  HTMLTextNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

NS_ASSUME_NONNULL_BEGIN

/**
    An HTMLTextNode represents text.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html#insert-a-character
 */
@interface HTMLTextNode : HTMLNode

/// Initializes a text node with some initial contents.
- (instancetype)initWithData:(NSString *)data NS_DESIGNATED_INITIALIZER;

/// The text.
@property (readonly, copy, nonatomic) NSString *data;

/// Adds a string to the end of the node's text.
- (void)appendString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
