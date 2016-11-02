//  HTMLNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNamespace.h"
#import "HTMLSupport.h"
@class HTMLDocument;
@class HTMLElement;

NS_ASSUME_NONNULL_BEGIN

/**
    HTMLNode is an abstract class representing a node in a parsed HTML tree.
 
    A node maintains strong references to its children and a weak reference to its parents.
 
    @note Copying an HTMLNode does not copy its document, parentElement, or children.
 */
@interface HTMLNode : NSObject <NSCopying>

/// Basically useless on its own; please call a subclass's initializer to initialize a useful HTMLNode.
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/// The document in which this node appears, or nil if the node is not in a tree with a document at its root.
@property (readonly, strong, nonatomic) HTMLDocument * __nullable document;

/// The node's parent, or nil if the node is a root node.
@property (weak, nonatomic) HTMLNode * __nullable parentNode;

/// The node's parent if it is an instance of HTMLElement, otherwise nil. Setter is equivalent to calling -setParentNode:.
@property (weak, nonatomic) HTMLElement * __nullable parentElement;

/// Removes the node from its parent, effectively detaching it from the tree.
- (void)removeFromParentNode;

/// The node's children. Each is an instance of HTMLNode. Key-Value Coding compliant for accessing and mutation.
@property (readonly, copy, nonatomic) HTMLOrderedSetOf(HTMLNode *) *children;

/// Convenience method that returns a mutable proxy for children. The proxy returned by -mutableChildren is much faster than the one obtained by calling -mutableOrderedSetValueForKey: yourself.
@property (readonly, nonatomic) HTMLMutableOrderedSetOf(HTMLNode *) *mutableChildren;

/**
    Add a child to the end of the node's set of children, removing it from its current parentNode's set of children. If the child is already in the node's set of children, nothing happens.
 */
- (void)addChild:(HTMLNode *)child;

/**
    Remove a child from the node's set of children. If the child is not in the node's set of children, nothing happens.
 */
- (void)removeChild:(HTMLNode *)child;

/**
    The number of nodes that have the node as their parent.
 
    This method is faster than calling `aNode.children.count`.
 */
@property (readonly, assign, nonatomic) NSUInteger numberOfChildren;

/**
    Returns a child of the node. Throws an NSRangeException if index is out of bounds.
 
    This method is faster than calling `[aNode.children objectAtIndex:]`.
 */
- (HTMLNode *)childAtIndex:(NSUInteger)index;

/**
    Returns the location of a child, or NSNotFound if the node is not the child's parent.
 
    This method is faster than calling `[aNode.children indexOfObject:]`.
 */
- (NSUInteger)indexOfChild:(HTMLNode *)child;

/// The node's children which are instances of HTMLElement.
@property (readonly, copy, nonatomic) HTMLArrayOf(HTMLElement *) *childElementNodes;

/**
    Emits in tree order the nodes in the subtree rooted at the node.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/infrastructure.html#tree-order
 */
- (HTMLEnumeratorOf(HTMLNode *) *)treeEnumerator;

/// Emits in tree order the nodes in the subtree rooted at the node, except that children are enumerated back to front.
- (HTMLEnumeratorOf(HTMLNode *) *)reversedTreeEnumerator;

/**
    The combined text content of the node and its descendants. The setter replaces the node's text, removing all descendants.
 
    For more information, see http://dom.spec.whatwg.org/#dom-node-textcontent
 */
@property (copy, nonatomic) NSString *textContent;

/**
    Returns the contents of each child text node. Only direct children are considered; no further descendants are included.
 */
@property (readonly, copy, nonatomic) HTMLArrayOf(NSString *) *textComponents;

/**
    Convenience method for either adding a string to an existing text node or creating a new text node.
 
    @param string         The text to insert.
    @param childNodeIndex The desired location of the text. If a new text node is created, this is where it will be inserted.
 */
- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)childNodeIndex;

@end

NS_ASSUME_NONNULL_END
