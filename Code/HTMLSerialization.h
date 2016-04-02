//  HTMLSerialization.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

NS_ASSUME_NONNULL_BEGIN

/// Turns an HTMLNode (back) into a string.
@interface HTMLNode (Serialization)

/// Describes the entire subtree rooted at the node.
@property (readonly, copy, nonatomic) NSString *recursiveDescription;

/**
    Returns the serialized HTML fragment of this node's children.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#serializing-html-fragments
 */
@property (readonly, copy, nonatomic) NSString *innerHTML;

/**
    Returns the serialized HTML fragment of this node.
 
    This is effectively outerHTML. (See http://www.w3.org/TR/DOM-Parsing/#widl-Element-outerHTML, though no exception will be thrown by -serializedFragment.)
 */
@property (readonly, copy, nonatomic) NSString *serializedFragment;

@end

NS_ASSUME_NONNULL_END
