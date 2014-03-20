//  HTMLNode.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"
#import "HTMLDocument.h"
#import "HTMLTextNode.h"
#import "HTMLTreeEnumerator.h"

@implementation HTMLNode
{
    HTMLDocument *_document;
    HTMLElement *_parentElement;
    NSMutableOrderedSet *_children;
}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    _children = [NSMutableOrderedSet new];
    
    return self;
}

- (HTMLDocument *)document
{
    return _document ?: self.parentElement.document;
}

- (void)setDocument:(HTMLDocument *)document
{
    if (document == self.document) return;
    [[_parentElement mutableChildren] removeObject:self];
    [[_document mutableChildren] removeObject:self];
    
    _document = document;
    _parentElement = nil;
    
    [[document mutableChildren] addObject:self];
}

- (void)setParentElement:(HTMLElement *)parentElement
{
    if (parentElement == _parentElement) return;
    [[_parentElement mutableChildren] removeObject:self];
    [[_document mutableChildren] removeObject:self];
    
    _parentElement = parentElement;
    _document = nil;
    
    [[parentElement mutableChildren] addObject:self];
}

- (NSOrderedSet *)children
{
    return [_children copy];
}

- (NSMutableOrderedSet *)mutableChildren
{
    return [self mutableOrderedSetValueForKey:@"children"];
}

- (NSUInteger)countOfChildren
{
    return _children.count;
}

- (void)insertObject:(HTMLNode *)node inChildrenAtIndex:(NSUInteger)index
{
    [_children insertObject:node atIndex:index];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index
{
    [_children removeObjectAtIndex:index];
}

- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)index
{
    id candidate = index > 0 ? _children[index - 1] : nil;
    HTMLTextNode *textNode;
    if ([candidate isKindOfClass:[HTMLTextNode class]]) {
        textNode = candidate;
    } else {
        textNode = [HTMLTextNode new];
        [[self mutableChildren] insertObject:textNode atIndex:index];
    }
    [textNode appendString:string];
}

- (NSArray *)childElementNodes
{
	NSMutableArray *childElements = [NSMutableArray arrayWithCapacity:_children.count];
	for (id node in _children) {
		if ([node isKindOfClass:[HTMLElement class]]) {
			[childElements addObject:node];
		}
	}
	return childElements;
}

- (NSEnumerator *)treeEnumerator
{
    return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:NO];
}

- (NSEnumerator *)reversedTreeEnumerator
{
	return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:YES];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[self.class allocWithZone:zone] init];
}

@end
