//  HTMLNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

/**
 * HTML knows of three namespaces.
 */
typedef NS_ENUM(NSInteger, HTMLNamespace)
{
    /**
     * The default namespace is HTML.
     */
    HTMLNamespaceHTML,
    
    /**
     * Most elements within <math> tags are in the MathML namespace.
     */
    HTMLNamespaceMathML,
    
    /**
     * Most elements within <svg> tags are in the SVG namespace.
     */
    HTMLNamespaceSVG,
};

/**
 * HTMLNode is an abstract class whose instances represent a single element, block of text, comment, or document type.
 */
@interface HTMLNode : NSObject <NSCopying>

/**
 * This node's parent, or nil if this node is a root node.
 */
@property (readonly, weak, nonatomic) HTMLNode *parentNode;

/**
 * The root node of this node's tree. (Usually an HTMLDocument.)
 */
@property (readonly, strong, nonatomic) HTMLNode *rootNode;

/**
 * This node's children, in document order.
 */
@property (readonly, copy, nonatomic) NSArray *childNodes;

/**
 * This node's element children, in document order.
 */
@property (readonly, copy, nonatomic) NSArray *childElementNodes;

/**
 * Returns an enumerator that returns all nodes in the subtree rooted at this node, in tree order.
 *
 * http://www.whatwg.org/specs/web-apps/current-work/multipage/infrastructure.html#tree-order
 */
- (NSEnumerator *)treeEnumerator;

/**
 * Returns an enumerator that returns all nodes in the subtree rooted at this node, in reverse tree order.
 */
- (NSEnumerator *)reversedTreeEnumerator;

/**
 * Returns nil. See -[HTMLElementNode objectForKeyedSubscript:].
 */
- (id)objectForKeyedSubscript:(id)key;

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

- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)childNodeIndex;

@end
