//  HTMLNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
@class HTMLDocument;
@class HTMLElement;
#import "HTMLNamespace.h"

/**
 * HTMLNode is an abstract class representing a node in a parsed HTML tree.
 *
 * @note Copying an HTMLNode does not copy its document, parentElement, or children.
 */
@interface HTMLNode : NSObject <NSCopying>

/**
 * The document in which this node appears. May be nil, in which case either the node is not part of any document or is itself an HTMLDocument.
 */
@property (strong, nonatomic) HTMLDocument *document;

/**
 * The node's parent, if it is an element. If the node's parent is an HTMLDocument, parentElement will be nil.
 *
 * @see -document
 */
@property (strong, nonatomic) HTMLElement *parentElement;

/**
 * The node's children, all instances of HTMLNode.
 *
 * children is a mutable Key-Value Coding compliant to-many relationship.
 */
@property (readonly, copy, nonatomic) NSOrderedSet *children;

/**
 * Returns a mutable set suitable for adding, moving, or removing child nodes.
 */
- (NSMutableOrderedSet *)mutableChildren;

/**
 * The number of children.
 *
 * This method is faster than `aNode.children.count` because no copying is involved.
 */
- (NSUInteger)countOfChildren;

/**
 * Subclasses may override to customize behavior when child nodes are added. They must call super.
 */
- (void)insertObject:(HTMLNode *)node inChildrenAtIndex:(NSUInteger)index;

/**
 * Subclasses may override to customize behavior when childnodes are removed. They must call super.
 */
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index;

/**
 * The children which are instances of HTMLElement.
 */
@property (readonly, copy, nonatomic) NSArray *childElementNodes;

/**
 * Returns an enumerator that emits the subtree rooted at the node in tree order.
 *
 * http://www.whatwg.org/specs/web-apps/current-work/multipage/infrastructure.html#tree-order
 */
- (NSEnumerator *)treeEnumerator;

/**
 * Returns an enumerator that emits the subtree rooted at the node in a reversed tree order (preorder, depth-first, but starting with the last child instead of the first).
 */
- (NSEnumerator *)reversedTreeEnumerator;

/**
 * Convenience method for either adding a string to an existing text node or creating a new text node.
 *
 * @param string         The text to insert.
 * @param childNodeIndex The desired location of the text. If a new text node is created, this is where it will be inserted.
 */
- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)childNodeIndex;

@end
