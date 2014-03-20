//  HTMLNode.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
@class HTMLDocument;
@class HTMLElement;
#import "HTMLNamespace.h"

/**
 * HTMLNode is an abstract class whose instances represent a single element, block of text, comment, or document type.
 */
@interface HTMLNode : NSObject <NSCopying>

@property (strong, nonatomic) HTMLDocument *document;

@property (strong, nonatomic) HTMLElement *parentElement;

@property (readonly, copy, nonatomic) NSOrderedSet *children;

- (NSMutableOrderedSet *)mutableChildren;

- (NSUInteger)countOfChildren;

- (void)insertObject:(HTMLNode *)node inChildrenAtIndex:(NSUInteger)index;

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index;

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

- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)childNodeIndex;

@end
