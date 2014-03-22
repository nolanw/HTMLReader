//  HTMLTreeEnumerator.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
@class HTMLNode;

/**
 * An HTMLTreeEnumerator emits HTMLNode instances in tree order (preorder, depth-first) or reverse tree order (preorder, depth-first starting with the last child).
 */
@interface HTMLTreeEnumerator : NSEnumerator

/**
 * This is the designated initializer.
 */
- (id)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed;

@end
