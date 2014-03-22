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
 * The document in which this node appears, or nil if the node is not in a tree with a document at its root.
 */
@property (readonly, strong, nonatomic) HTMLDocument *document;

/**
 * The node's parent, or nil if the node is a root node.
 */
@property (strong, nonatomic) HTMLNode *parentNode;

/**
 * The node's parent if it is an instance of HTMLElement, otherwise nil. Setter is equivalent to calling -setParentNode:.
 */
@property (strong, nonatomic) HTMLElement *parentElement;

/**
 * The node's children. Each is an instance of HTMLNode. Key-Value Coding compliant for accessing and mutation.
 */
@property (readonly, copy, nonatomic) NSOrderedSet *children;

/**
 * Convenience method that returns a mutable proxy for children. The proxy returned by -mutableChildren is much faster than the one obtained by calling -mutableOrderedSetValueForKey: yourself.
 */
- (NSMutableOrderedSet *)mutableChildren;

/**
 * The number of nodes that have the node as their parent.
 *
 * This method is faster than calling `aNode.children.count`.
 */
- (NSUInteger)numberOfChildren;

/**
 * Returns a child of the node. Throws an NSRangeException if index is out of bounds.
 *
 * This method is faster than calling `[aNode.children objectAtIndex:]`.
 */
- (HTMLNode *)childAtIndex:(NSUInteger)index;

/**
 * The node's children which are instances of HTMLElement.
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
