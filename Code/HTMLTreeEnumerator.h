//  HTMLTreeEnumerator.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
@class HTMLNode;

@interface HTMLTreeEnumerator : NSEnumerator

- (id)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed;

@property (readonly, nonatomic) HTMLNode *node;

@end
