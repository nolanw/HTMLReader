//
//  HTMLTreeConstructor.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTreeConstructor.h"

typedef NS_ENUM(NSInteger, HTMLInsertionMode)
{
    HTMLInitialInsertionMode,
    HTMLBeforeHtmlInsertionMode,
    HTMLBeforeheadInsertionMode,
    HTMLInHeadInsertionMode,
    HTMLInHeadNoscriptInsertionMode,
    HTMLAfterHeadInsertionMode,
    HTMLInBodyInsertionMode,
    HTMLTextInsertionMode,
    HTMLInTableInsertionMode,
    HTMLInTableTextInsertionMode,
    HTMLInCaptionInsertionMode,
    HTMLInColumnGroupInsertionMode,
    HTMLInTableBodyInsertionMode,
    HTMLInRowInsertionMode,
    HTMLInCellInsertionMode,
    HTMLInSelectInsertionMode,
    HTMLInSelectInTableInsertionMode,
    HTMLInTemplateInsertionMode,
    HTMLAfterBodyInsertionMode,
    HTMLInFramesetInsertionMode,
    HTMLAfterFramesetInsertionMode,
    HTMLAfterAfterBodyInsertionMode,
    HTMLAfterAfterFramesetInsertionMode,
};

@implementation HTMLTreeConstructor
{
    HTMLInsertionMode _insertionMode;
    HTMLElementNode *_context;
}

- (id)initWithDocument:(HTMLDocument *)document context:(HTMLElementNode *)context
{
    if (!(self = [super init])) return nil;
    _document = document;
    _insertionMode = HTMLInitialInsertionMode;
    _context = context;
    return self;
}

- (void)resume:(id)token
{
    (void)token;
}

@end

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

- (id)initWithData:(NSString *)data
{
    if (!(self = [super init])) return nil;
    _data = [data copy];
    return self;
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

@end
