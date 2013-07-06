//
//  HTMLNode.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLNode.h"
#import "HTMLString.h"

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

- (NSArray *)childNodes
{
    return [_childNodes copy];
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

- (NSArray *)attributes
{
    return [_attributes copy];
}

- (void)addAttribute:(HTMLAttribute *)attribute
{
    [_attributes addObject:attribute];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLElementNode *copy = [super copyWithZone:zone];
    copy->_tagName = self.tagName;
    [copy->_attributes addObjectsFromArray:self.attributes];
    return copy;
}

#pragma mark NSObject

- (NSString *)description
{
    NSString *attributes = @"";
    if (_attributes.count > 0) {
        attributes = [[_attributes valueForKey:@"keyValueDescription"] componentsJoinedByString:@" "];
        attributes = [@" " stringByAppendingString:attributes];
    }
    return [NSString stringWithFormat:@"<%@: %p <%@%@> %@ child node%@>", self.class, self, self.tagName,
            attributes, @(self.childNodes.count), self.childNodes.count == 1 ? @"" : @"s"];
}

- (BOOL)isEqual:(HTMLElementNode *)other
{
    return ([other isKindOfClass:[HTMLElementNode class]] &&
            [other.childNodes isEqual:self.childNodes] &&
            [other.tagName isEqualToString:self.tagName] &&
            [other.attributes isEqual:self.attributes]);
}

- (NSUInteger)hash
{
    return self.tagName.hash ^ self.attributes.hash ^ self.childNodes.hash;
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

- (BOOL)isEqual:(HTMLTextNode *)other
{
    return ([other isKindOfClass:[HTMLTextNode class]] &&
            [other.childNodes isEqual:self.childNodes] &&
            [other.data isEqualToString:self.data]);
}

- (NSUInteger)hash
{
    return _data.hash;
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

- (BOOL)isEqual:(HTMLCommentNode *)other{
    return ([other isKindOfClass:[HTMLCommentNode class]] &&
            [other.childNodes isEqual:self.childNodes] &&
            [other.data isEqualToString:self.data]);
}

- (NSUInteger)hash
{
    return self.childNodes.hash ^ _data.hash;
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

- (BOOL)isEqual:(HTMLDocumentTypeNode *)other
{
    #define AreEqualOrNil(a, b) (((a) == nil && (b) == nil) || [(a) isEqual:(b)])
    return ([other isKindOfClass:[HTMLDocumentTypeNode class]] &&
            [other.childNodes isEqual:self.childNodes] &&
            [other.name isEqualToString:self.name] &&
            AreEqualOrNil(other.publicId, self.publicId) &&
            AreEqualOrNil(other.systemId, self.systemId));
}

- (NSUInteger)hash
{
    return self.childNodes.hash ^ _name.hash ^ _publicId.hash ^ _systemId.hash;
}

@end
