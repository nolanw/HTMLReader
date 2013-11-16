//  HTMLMutability.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * HTMLNode instances are immutable except during parsing.
 */
@interface HTMLNode (HTMLParser)

/**
 * Add a node to this node's children.
 *
 * @param child The node to add.
 */
- (void)appendChild:(HTMLNode *)child;

/**
 * Insert a node into this node's children.
 *
 * @param child The node to insert.
 * @param index The index for the inserted node.
 */
- (void)insertChild:(HTMLNode *)child atIndex:(NSUInteger)index;

/**
 * Remove a node from this node's children.
 *
 * @param child The node to remove.
 */
- (void)removeChild:(HTMLNode *)child;

@property (readonly, assign, nonatomic) NSUInteger childNodeCount;

- (void)insertCharacter:(UTF32Char)character atChildNodeIndex:(NSUInteger)childNodeIndex;

@end

/**
 * HTMLElementNode instances are immutable except during parsing.
 */
@interface HTMLElementNode (HTMLParser)

/**
 * Add an attribute to this element.
 *
 * @param attribute The attribute to add.
 */
- (void)addAttribute:(HTMLAttribute *)attribute;

/**
 * Get or set this element's namespace.
 */
@property (assign, nonatomic) HTMLNamespace namespace;

@end

/**
 * HTMLTextNode instances are immutable except during parsing.
 */
@interface HTMLTextNode (HTMLParser)

/**
 * Append a character to this text node's data.
 *
 * @param character The character to append.
 */
- (void)appendLongCharacter:(UTF32Char)character;

@end
