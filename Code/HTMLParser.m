//
//  HTMLParser.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLParser.h"
#import "HTMLTokenizer.h"

@implementation HTMLParser
{
    HTMLTokenizer *_tokenizer;
    HTMLDocument *_document;
    HTMLElementNode *_context;
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    if (!(self = [super init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _context = context;
    return self;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    HTMLTreeConstructor *treeConstructor = [[HTMLTreeConstructor alloc] initWithDocument:_document
                                                                                 context:_context];
    for (id token in _tokenizer) {
        [treeConstructor resume:token];
    }
    return _document;
}

@end
