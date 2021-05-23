//  HTMLTreeEnumerator.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLSupport.h"
@class HTMLNode;

NS_ASSUME_NONNULL_BEGIN

/// An HTMLTreeEnumerator emits HTMLNode instances in tree order (preorder, depth-first) or reverse tree order (preorder, depth-first starting with the last child).
@interface HTMLTreeEnumerator : HTMLEnumeratorOf(HTMLNode *)

/// Initializes an enumerator rooted at a particular node.
- (instancetype)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
