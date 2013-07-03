//
//  HTMLDocument.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLDocument.h"

@implementation HTMLDocument
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

- (void)addChildNode:(id)node
{
    [_childNodes addObject:node];
}

- (void)setDoctype:(HTMLDocumentTypeNode *)doctype
{
    _doctype = doctype;
    [_childNodes addObject:doctype];
}

@end
