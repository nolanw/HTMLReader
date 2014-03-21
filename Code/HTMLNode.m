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

// In order to quickly mutate the children set, we need to pull some shenanigans. From the Key-Value Coding Programming Guide:
//
// > When the default implementation of valueForKey: is invoked on a receiver, the following search pattern is used:
// >
// > 1. Searches the class of the receiver for an accessor method whose name matches the pattern get<Key>, <key>, or is<Key>, in that order. If such a method is found it is invoked.…
// > 2. Otherwise (no simple accessor method is found), searches the class of the receiver for methods whose names match the patterns countOf<Key> and objectIn<Key>AtIndex: … and <key>AtIndexes:….
// > If the countOf<Key> method and at least one of the other two possible methods are found, a collection proxy object that responds to all NSArray [sic] methods is returned. Each NSArray [sic] message sent to the collection proxy object will result in some combination of countOf<Key>, objectIn<Key>AtIndex:, and <key>AtIndexes: messages being sent to the original receiver of valueForKey:.
//
// From this, we can see that implementing -children stops us at step 1, and our implementation involves copying the set so it is slow. To work around this, we become KVC-compliant for the key "HTMLMutableChildren" and implement the accessors for that key. Since we don't implement -HTMLMutableChildren (step 1), our accessors are used instead (step 2), and all is well.
//
// Note that -mutableOrderedSetValueForKey: will still work for the key "children", it'll just be slow.

- (NSMutableOrderedSet *)mutableChildren
{
    return [self mutableOrderedSetValueForKey:@"HTMLMutableChildren"];
}

- (NSUInteger)countOfChildren
{
    return _children.count;
}

- (void)insertObject:(HTMLNode *)node inChildrenAtIndex:(NSUInteger)index
{
    [self insertObject:node inHTMLMutableChildrenAtIndex:index];
}

- (void)removeObjectFromChildrenAtIndex:(NSUInteger)index
{
    [self removeObjectFromHTMLMutableChildrenAtIndex:index];
}

- (NSUInteger)countOfHTMLMutableChildren
{
    return _children.count;
}

- (HTMLNode *)objectInHTMLMutableChildrenAtIndex:(NSUInteger)index
{
    return _children[index];
}

- (void)insertObject:(HTMLNode *)node inHTMLMutableChildrenAtIndex:(NSUInteger)index
{
    [_children insertObject:node atIndex:index];
}

- (void)removeObjectFromHTMLMutableChildrenAtIndex:(NSUInteger)index
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
