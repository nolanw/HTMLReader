//  HTMLSerialization.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

@interface HTMLNode (Serialization)

/**
 * Describes the entire subtree rooted at the node.
 */
- (NSString *)recursiveDescription;

/**
 * Returns the serialized HTML fragment of this node's children.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#serializing-html-fragments
 */
- (NSString *)innerHTML;

/**
 * Returns the serialized HTML fragment of this node.
 */
- (NSString *)serializedFragment;

@end
