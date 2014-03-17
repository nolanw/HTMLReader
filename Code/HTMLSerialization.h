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
 * This is what's described as "the HTML fragment serialization algorithm" by the spec.
 */
- (NSString *)innerHTML;

/**
 * Returns the serialized HTML fragment of this node. Subclasses must override.
 */
- (NSString *)serializedFragment;

@end
