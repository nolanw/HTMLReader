//
//  HTMLNode.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//

#import "HTMLNode.h"
#import "HTMLString.h"

@interface HTMLTreeEnumerator : NSEnumerator

- (id)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed;

@property (readonly, nonatomic) HTMLNode *node;

@end

@implementation HTMLNode
{
    NSMutableArray *_childNodes;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _childNodes = [NSMutableArray new];
    return self;
}

-(HTMLNode *)rootNode
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
    return [_childNodes copy];
}

- (void)setChildNodes:(NSArray *)childNodes
{
    [_childNodes setArray:childNodes];
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

- (NSEnumerator *)treeEnumerator
{
    return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:NO];
}

-(NSEnumerator *)reversedTreeEnumerator
{
	return [[HTMLTreeEnumerator alloc] initWithNode:self reversed:YES];
}

- (NSString *)recursiveDescription
{
    NSMutableString *string = [NSMutableString new];
    [self appendRecursiveDescriptionToString:string withIndentLevel:0];
    return string;
}

- (void)appendRecursiveDescriptionToString:(NSMutableString *)string
                           withIndentLevel:(NSInteger)indentLevel
{
    if (indentLevel > 0) {
        [string appendString:[@"\n|" stringByPaddingToLength:indentLevel * 4 + 2
                                                  withString:@" "
                                             startingAtIndex:0]];
    }
    [string appendString:self.description];
    for (HTMLNode *node in _childNodes) {
        [node appendRecursiveDescriptionToString:string withIndentLevel:indentLevel + 1];
    }
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[self.class allocWithZone:zone] init];
}

@end

@implementation HTMLElementNode
{
    NSMutableArray *_attributes;
}

- (id)initWithTagName:(NSString *)tagName
{
    if (!(self = [super init])) return nil;
    _tagName = [tagName copy];
    _attributes = [NSMutableArray new];
    return self;
}

- (id)init
{
    return [self initWithTagName:nil];
}

#pragma mark Element Attributes

- (NSArray *)attributes
{
    return [_attributes copy];
}

- (void)addAttribute:(HTMLAttribute *)attribute
{
    [_attributes addObject:attribute];
}

- (HTMLAttribute*)attributeNamed:(NSString*)name
{
	for (HTMLAttribute *attribute in _attributes)
	{
		if ([[attribute name] compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame)
		{
			return attribute;
		}
	}
	
	return nil;
}

- (id)valueForKey:(NSString *)key
{
	//If the key is in the format "[key]" get the attribute value for "key"
	if ([key hasPrefix:@"["] && [key hasSuffix:@"]"]) return [self attributeNamed:[key substringWithRange:NSMakeRange(1, key.length - 2)]].value;
	else return [super valueForKey:key];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLElementNode *copy = [super copyWithZone:zone];
    copy->_tagName = self.tagName;
    copy->_attributes = [NSMutableArray arrayWithArray:_attributes];
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSString *namespace = @"";
    if (self.namespace == HTMLNamespaceMathML) {
        namespace = @"math ";
    } else if (self.namespace == HTMLNamespaceSVG) {
        namespace = @"svg ";
    }
    NSString *attributes = @"";
    if (_attributes.count > 0) {
        attributes = [[_attributes valueForKey:@"keyValueDescription"] componentsJoinedByString:@" "];
        attributes = [@" " stringByAppendingString:attributes];
    }
    return [NSString stringWithFormat:@"<%@: %p <%@%@%@> %@ child node%@>", self.class, self,
            namespace, self.tagName, attributes,
            @(self.childNodes.count), self.childNodes.count == 1 ? @"" : @"s"];
}

@end

@implementation HTMLTextNode
{
    NSMutableString *_data;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _data = [NSMutableString new];
    return self;
}

- (id)initWithData:(NSString *)data
{
    if (!(self = [self init])) return nil;
    [_data setString:data];
    return self;
}

- (void)appendLongCharacter:(UTF32Char)character
{
    AppendLongCharacter(_data, character);
}

- (NSString *)data
{
    return [_data copy];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLTextNode *copy = [super copyWithZone:zone];
    [copy->_data setString:_data];
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSString *truncatedData = self.data;
    if (truncatedData.length > 37) {
        truncatedData = [[truncatedData substringToIndex:37] stringByAppendingString:@"…"];
    }
    return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, truncatedData];
}

@end

@implementation HTMLCommentNode

- (id)initWithData:(NSString *)data
{
    if (!(self = [super init])) return nil;
    _data = [data copy];
    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLCommentNode *copy = [super copyWithZone:zone];
    copy->_data = self.data;
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSString *truncatedData = self.data;
    if (truncatedData.length > 37) {
        truncatedData = [[truncatedData substringToIndex:37] stringByAppendingString:@"…"];
    }
    return [NSString stringWithFormat:@"<%@: %p <!-- %@ --> >", self.class, self, truncatedData];
}

@end

@implementation HTMLDocumentTypeNode

- (id)initWithName:(NSString *)name publicId:(NSString *)publicId systemId:(NSString *)systemId
{
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _publicId = [publicId copy] ?: @"";
    _systemId = [systemId copy] ?: @"";
    return self;
}

- (id)init
{
    return [self initWithName:nil publicId:nil systemId:nil];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLDocumentTypeNode *copy = [super copyWithZone:zone];
    copy->_name = self.name;
    copy->_publicId = self.publicId;
    copy->_systemId = self.systemId;
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p <!DOCTYPE %@ '%@' '%@'> >",
            self.class, self, self.name, self.publicId, self.systemId];
}

@end

@implementation HTMLTreeEnumerator
{
	BOOL _isReversed;
    NSIndexPath *_nextNodePath;
}

- (id)initWithNode:(HTMLNode *)node reversed:(BOOL)reversed
{
    if (!(self = [super init])) return nil;
    _node = node;
	_isReversed = reversed;
    return self;
}

- (id)nextObject
{
    HTMLNode *currentNode = _node;
    if (!_nextNodePath) {
        _nextNodePath = [NSIndexPath indexPathWithIndex:0];
        return currentNode;
    }
    for (NSUInteger i = 0; i < [_nextNodePath length] - 1; i++) {
		int index = _isReversed ?  [currentNode childNodes].count - [_nextNodePath indexAtPosition:i] - 1 : [_nextNodePath indexAtPosition:i];
        currentNode = currentNode.childNodes[index];
    }
    NSUInteger lastIndex = [_nextNodePath indexAtPosition:[_nextNodePath length] - 1];
    if (lastIndex >= [currentNode.childNodes count]) {
        NSIndexPath *chopped = [_nextNodePath indexPathByRemovingLastIndex];
        if ([chopped length] == 0) return nil;
        NSUInteger newLast = [chopped indexAtPosition:[chopped length] - 1];
        _nextNodePath = [[chopped indexPathByRemovingLastIndex] indexPathByAddingIndex:newLast + 1];
        return [self nextObject];
    }
    _nextNodePath = [_nextNodePath indexPathByAddingIndex:0];
	int index = _isReversed ?  [currentNode childNodes].count - lastIndex - 1 :lastIndex;
    return currentNode.childNodes[index];
}

@end
