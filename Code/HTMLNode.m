//
//  HTMLNode.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLNode.h"
#import "HTMLString.h"

@implementation HTMLElementNode
{
    NSMutableArray *_childNodes;
    NSMutableArray *_attributes;
}

- (id)initWithTagName:(NSString *)tagName
{
    if (!(self = [super init])) return nil;
    _tagName = [tagName copy];
    _childNodes = [NSMutableArray new];
    _attributes = [NSMutableArray new];
    return self;
}

- (NSArray *)childNodes
{
    return [_childNodes copy];
}

- (void)addChildNode:(id)node
{
    [_childNodes addObject:node];
}

- (NSArray *)attributes
{
    return [_attributes copy];
}

- (void)addAttribute:(HTMLAttribute *)attribute
{
    [_attributes addObject:attribute];
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

@end

@implementation HTMLTextNode
{
    NSMutableString *_data;
}

- (id)initWithData:(NSString *)data
{
    if (!(self = [super init])) return nil;
    _data = [NSMutableString stringWithString:data];
    return self;
}

- (void)appendLongCharacter:(UTF32Char)character
{
    if (!_data) _data = [NSMutableString new];
    AppendLongCharacter(_data, character);
}

- (NSString *)data
{
    return [_data copy];
}

@end

@implementation HTMLCommentNode

- (id)initWithData:(NSString *)data
{
    if (!(self = [super init])) return nil;
    _data = [data copy];
    return self;
}

@end

@implementation HTMLDocumentTypeNode

- (id)initWithName:(NSString *)name publicId:(NSString *)publicId systemId:(NSString *)systemId
{
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _publicId = [publicId copy];
    _systemId = [systemId copy];
    return self;
}

@end
