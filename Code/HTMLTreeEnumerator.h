//  HTMLTreeEnumerator.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
@class HTMLNode;
#import "HTMLSupport.h"

/// An HTMLTreeEnumerator emits HTMLNode instances in tree order (preorder, depth-first) or reverse tree order (preorder, depth-first starting with the last child).
@interface HTMLTreeEnumerator : NSEnumerator

/// Initializes an enumerator rooted at a particular node.
- (instancetype)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed NS_DESIGNATED_INITIALIZER;

@end
