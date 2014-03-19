//  HTMLNode.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"
#import "HTMLElement.h"
#import "HTMLTextNode.h"
#import "HTMLTreeEnumerator.h"

@implementation HTMLNode
{
    NSMutableArray *_childNodes;
}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    _childNodes = [NSMutableArray new];
    
    return self;
}

- (HTMLNode *)rootNode
{
	HTMLNode *target = self;
	
	while (target.parentNode != nil)
	{
		target = target.parentNode;
	}
	
	return target;
}

- (NSArray *)childNodes
{
    return _childNodes;
}

- (void)setChildNodes:(NSArray *)childNodes
{
    [_childNodes setArray:childNodes];
}

- (NSUInteger)childNodeCount
{
    return _childNodes.count;
}

- (void)appendChild:(HTMLNode *)child
{
    [child.parentNode removeChild:child];
    [_childNodes addObject:child];
    child->_parentNode = self;
}

- (void)insertChild:(HTMLNode *)child atIndex:(NSUInteger)index
{
    [self appendChild:child];
    [_childNodes exchangeObjectAtIndex:index withObjectAtIndex:_childNodes.count - 1];
}

- (void)removeChild:(HTMLNode *)child
{
    NSUInteger i = [_childNodes indexOfObject:child];
    if (i != NSNotFound) {
        [_childNodes removeObjectAtIndex:i];
        child->_parentNode = nil;
    }
}

- (void)insertString:(NSString *)string atChildNodeIndex:(NSUInteger)index
{
    id candidate = index > 0 ? _childNodes[index - 1] : nil;
    HTMLTextNode *textNode;
    if ([candidate isKindOfClass:[HTMLTextNode class]]) {
        textNode = candidate;
    } else {
        textNode = [HTMLTextNode new];
        [self insertChild:textNode atIndex:index];
    }
    [textNode appendString:string];
}

- (NSArray *)childElementNodes
{
	NSMutableArray *ret = [NSMutableArray arrayWithCapacity:_childNodes.count];
	
	for (id node in _childNodes)
	{
		if ([node isKindOfClass:[HTMLElement class]])
		{
			[ret addObject:node];
		}
	}
	
	return ret;
}

- (NSEnumerator *)treeEnumerator
{
    return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:NO];
}

- (NSEnumerator *)reversedTreeEnumerator
{
	return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:YES];
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    // Implemented so we can subscript HTMLNode instances, even though only HTMLElementNode instances have attributes.
    return nil;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[self.class allocWithZone:zone] init];
}

@end
