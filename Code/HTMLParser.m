//
//  HTMLParser.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLParser.h"
#import "HTMLTokenizer.h"

typedef NS_ENUM(NSInteger, HTMLInsertionMode)
{
    HTMLInitialInsertionMode,
    HTMLBeforeHtmlInsertionMode,
    HTMLBeforeHeadInsertionMode,
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

@implementation HTMLParser
{
    HTMLTokenizer *_tokenizer;
    HTMLInsertionMode _insertionMode;
    HTMLElementNode *_context;
    NSMutableArray *_stackOfOpenElements;
    HTMLElementNode *_headElementPointer;
    HTMLDocument *_document;
    NSMutableArray *_errors;
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    if (!(self = [super init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _insertionMode = HTMLInitialInsertionMode;
    _context = context;
    _stackOfOpenElements = [NSMutableArray new];
    _errors = [NSMutableArray new];
    return self;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    for (id token in _tokenizer) {
        [self resume:token];
    }
    return _document;
}

- (NSArray *)errors
{
    return [_errors copy];
}

- (void)resume:(id)nextToken
{
    switch (_insertionMode) {
        case HTMLInitialInsertionMode:
            if ([nextToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = nextToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([nextToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = nextToken;
                [_document addChildNode:[[HTMLCommentNode alloc] initWithData:token.data]];
            } else if ([nextToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                HTMLDOCTYPEToken *token = nextToken;
                if (DOCTYPEIsParseError(token)) {
                    [self addParseError];
                }
                _document.doctype = [[HTMLDocumentTypeNode alloc] initWithName:token.name ?: @""
                                                                      publicId:token.publicIdentifier ?: @""
                                                                      systemId:token.systemIdentifier ?: @""];
                _document.quirksMode = QuirksModeForDOCTYPE(token);
                [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
            } else {
                [self addParseError];
                _document.quirksMode = HTMLQuirksMode;
                [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
                [self resume:nextToken];
            }
            break;
            
        case HTMLBeforeHtmlInsertionMode:
            if ([nextToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = nextToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([nextToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                [self addParseError];
                return;
            } else if ([nextToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = nextToken;
                [_document addChildNode:[[HTMLCommentNode alloc] initWithData:token.data]];
            } else if ([nextToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[nextToken tagName] isEqualToString:@"html"])
            {
                HTMLStartTagToken *token = nextToken;
                HTMLElementNode *html = [[HTMLElementNode alloc] initWithTagName:@"html"];
                for (HTMLAttribute *attribute in token.attributes) {
                    [html addAttribute:attribute];
                }
                [_document addChildNode:html];
                [_stackOfOpenElements addObject:html];
                [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
            } else if ([nextToken isKindOfClass:[HTMLEndTagToken class]] &&
                       !([[nextToken tagName] isEqualToString:@"head"] ||
                         [[nextToken tagName] isEqualToString:@"body"] ||
                         [[nextToken tagName] isEqualToString:@"html"] ||
                         [[nextToken tagName] isEqualToString:@"br"]))
            {
                [self addParseError];
                return;
            } else {
                HTMLElementNode *html = [[HTMLElementNode alloc] initWithTagName:@"html"];
                [_document addChildNode:html];
                [_stackOfOpenElements addObject:html];
                [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
                [self resume:nextToken];
            }
            break;
            
        case HTMLBeforeHeadInsertionMode:
            if ([nextToken isKindOfClass:[HTMLCharacterToken class]]) {
                HTMLCharacterToken *token = nextToken;
                switch (token.data) {
                    case '\t':
                    case '\n':
                    case '\f':
                    case '\r':
                    case ' ':
                        return;
                }
            }
            if ([nextToken isKindOfClass:[HTMLCommentToken class]]) {
                HTMLCommentToken *token = nextToken;
                HTMLCommentNode *comment = [[HTMLCommentNode alloc] initWithData:token.data];
                HTMLElementNode *currentNode = _stackOfOpenElements.lastObject;
                [currentNode addChildNode:comment];
            } else if ([nextToken isKindOfClass:[HTMLDOCTYPEToken class]]) {
                [self addParseError];
                return;
            } else if ([nextToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[nextToken tagName] isEqualToString:@"html"])
            {
                HTMLStartTagToken *token = nextToken;
                [self addParseError];
                HTMLElementNode *topElement = _stackOfOpenElements[0];
                for (HTMLAttribute *attribute in token.attributes) {
                    if (![[topElement.attributes valueForKey:@"name"] containsObject:attribute.name]) {
                        [topElement addAttribute:attribute];
                    }
                }
            } else if ([nextToken isKindOfClass:[HTMLStartTagToken class]] &&
                       [[nextToken tagName] isEqualToString:@"head"])
            {
                HTMLStartTagToken *token = nextToken;
                HTMLElementNode *head = [[HTMLElementNode alloc] initWithTagName:@"head"];
                for (HTMLAttribute *attribute in token.attributes) {
                    [head addAttribute:attribute];
                }
                [_stackOfOpenElements.lastObject addChildNode:head];
                _headElementPointer = head;
                [self switchInsertionMode:HTMLInHeadInsertionMode];
            } else if ([nextToken isKindOfClass:[HTMLEndTagToken class]] &&
                       !([[nextToken tagName] isEqualToString:@"head"] ||
                         [[nextToken tagName] isEqualToString:@"body"] ||
                         [[nextToken tagName] isEqualToString:@"html"] ||
                         [[nextToken tagName] isEqualToString:@"br"]))
            {
                [self addParseError];
                return;
            } else {
                HTMLElementNode *head = [[HTMLElementNode alloc] initWithTagName:@"head"];
                [_stackOfOpenElements.lastObject addChildNode:head];
                _headElementPointer = head;
                [self switchInsertionMode:HTMLInHeadInsertionMode];
                [self resume:nextToken];
            }
            break;
            
        case HTMLInHeadInsertionMode:
        case HTMLInHeadNoscriptInsertionMode:
        case HTMLAfterHeadInsertionMode:
        case HTMLInBodyInsertionMode:
        case HTMLTextInsertionMode:
        case HTMLInTableInsertionMode:
        case HTMLInTableTextInsertionMode:
        case HTMLInCaptionInsertionMode:
        case HTMLInColumnGroupInsertionMode:
        case HTMLInTableBodyInsertionMode:
        case HTMLInRowInsertionMode:
        case HTMLInCellInsertionMode:
        case HTMLInSelectInsertionMode:
        case HTMLInSelectInTableInsertionMode:
        case HTMLInTemplateInsertionMode:
        case HTMLAfterBodyInsertionMode:
        case HTMLInFramesetInsertionMode:
        case HTMLAfterFramesetInsertionMode:
        case HTMLAfterAfterBodyInsertionMode:
        case HTMLAfterAfterFramesetInsertionMode:
            // TODO
            break;
    }
}

- (void)switchInsertionMode:(HTMLInsertionMode)insertionMode
{
    _insertionMode = insertionMode;
}

static BOOL DOCTYPEIsParseError(HTMLDOCTYPEToken *t)
{
    NSString *name = t.name, *public = t.publicIdentifier, *system = t.systemIdentifier;
    if (![name isEqualToString:@"html"]) return YES;
    if ([public isEqualToString:@"-//W3C//DTD HTML 4.0//EN"] &&
        (!system || [system isEqualToString:@"http://www.w3.org/TR/REC-html40/strict.dtd"]))
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD HTML 4.01//EN"] &&
        (!system || [system isEqualToString:@"http://www.w3.org/TR/html4/strict.dtd"]))
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD XHTML 1.0 Strict//EN"] &&
        [system isEqualToString:@"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"])
    {
        return NO;
    }
    if ([public isEqualToString:@"-//W3C//DTD XHTML 1.1//EN"] &&
        [system isEqualToString:@"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd"])
    {
        return NO;
    }
    if (public) return YES;
    if (system && ![system isEqualToString:@"about:legacy-compat"]) return YES;
    return NO;
}

static HTMLDocumentQuirksMode QuirksModeForDOCTYPE(HTMLDOCTYPEToken *t)
{
    if (t.forceQuirks) return HTMLQuirksMode;
    if (![t.name isEqualToString:@"html"]) return HTMLQuirksMode;
    static NSString * Prefixes[] = {
        @"+//Silmaril//dtd html Pro v0r11 19970101//",
        @"-//AdvaSoft Ltd//DTD HTML 3.0 asWedit + extensions//",
        @"-//AS//DTD HTML 3.0 asWedit + extensions//",
        @"-//IETF//DTD HTML 2.0 Level 1//",
        @"-//IETF//DTD HTML 2.0 Level 2//",
        @"-//IETF//DTD HTML 2.0 Strict Level 1//",
        @"-//IETF//DTD HTML 2.0 Strict Level 2//",
        @"-//IETF//DTD HTML 2.0 Strict//",
        @"-//IETF//DTD HTML 2.0//",
        @"-//IETF//DTD HTML 2.1E//",
        @"-//IETF//DTD HTML 3.0//",
        @"-//IETF//DTD HTML 3.2 Final//",
        @"-//IETF//DTD HTML 3.2//",
        @"-//IETF//DTD HTML 3//",
        @"-//IETF//DTD HTML Level 0//",
        @"-//IETF//DTD HTML Level 1//",
        @"-//IETF//DTD HTML Level 2//",
        @"-//IETF//DTD HTML Level 3//",
        @"-//IETF//DTD HTML Strict Level 0//",
        @"-//IETF//DTD HTML Strict Level 1//",
        @"-//IETF//DTD HTML Strict Level 2//",
        @"-//IETF//DTD HTML Strict Level 3//",
        @"-//IETF//DTD HTML Strict//",
        @"-//IETF//DTD HTML//",
        @"-//Metrius//DTD Metrius Presentational//",
        @"-//Microsoft//DTD Internet Explorer 2.0 HTML Strict//",
        @"-//Microsoft//DTD Internet Explorer 2.0 HTML//",
        @"-//Microsoft//DTD Internet Explorer 2.0 Tables//",
        @"-//Microsoft//DTD Internet Explorer 3.0 HTML Strict//",
        @"-//Microsoft//DTD Internet Explorer 3.0 HTML//",
        @"-//Microsoft//DTD Internet Explorer 3.0 Tables//",
        @"-//Netscape Comm. Corp.//DTD HTML//",
        @"-//Netscape Comm. Corp.//DTD Strict HTML//",
        @"-//O'Reilly and Associates//DTD HTML 2.0//",
        @"-//O'Reilly and Associates//DTD HTML Extended 1.0//",
        @"-//O'Reilly and Associates//DTD HTML Extended Relaxed 1.0//",
        @"-//SoftQuad Software//DTD HoTMetaL PRO 6.0::19990601::extensions to HTML 4.0//",
        @"-//SoftQuad//DTD HoTMetaL PRO 4.0::19971010::extensions to HTML 4.0//",
        @"-//Spyglass//DTD HTML 2.0 Extended//",
        @"-//SQ//DTD HTML 2.0 HoTMetaL + extensions//",
        @"-//Sun Microsystems Corp.//DTD HotJava HTML//",
        @"-//Sun Microsystems Corp.//DTD HotJava Strict HTML//",
        @"-//W3C//DTD HTML 3 1995-03-24//",
        @"-//W3C//DTD HTML 3.2 Draft//",
        @"-//W3C//DTD HTML 3.2 Final//",
        @"-//W3C//DTD HTML 3.2//",
        @"-//W3C//DTD HTML 3.2S Draft//",
        @"-//W3C//DTD HTML 4.0 Frameset//",
        @"-//W3C//DTD HTML 4.0 Transitional//",
        @"-//W3C//DTD HTML Experimental 19960712//",
        @"-//W3C//DTD HTML Experimental 970421//",
        @"-//W3C//DTD W3 HTML//",
        @"-//W3O//DTD W3 HTML 3.0//",
        @"-//WebTechs//DTD Mozilla HTML 2.0//",
        @"-//WebTechs//DTD Mozilla HTML//",
    };
    for (size_t i = 0; i < sizeof(Prefixes) / sizeof(Prefixes[0]); i++) {
        if ([t.publicIdentifier hasPrefix:Prefixes[i]]) {
            return HTMLQuirksMode;
        }
    }
    if ([t.publicIdentifier isEqualToString:@"-//W3O//DTD W3 HTML Strict 3.0//EN//"] ||
        [t.publicIdentifier isEqualToString:@"-/W3C/DTD HTML 4.0 Transitional/EN"] ||
        [t.publicIdentifier isEqualToString:@"HTML"])
    {
        return HTMLQuirksMode;
    }
    if ([t.systemIdentifier isEqualToString:@"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"]) {
        return HTMLQuirksMode;
    }
    if (!t.systemIdentifier) {
        if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
            [t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
        {
            return HTMLQuirksMode;
        }
    }
    if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD XHTML 1.0 Frameset//"] ||
        [t.publicIdentifier hasPrefix:@"-//W3C//DTD XHTML 1.0 Transitional//"])
    {
        return HTMLLimitedQuirksMode;
    }
    if (t.systemIdentifier) {
        if ([t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
            [t.publicIdentifier hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
        {
            return HTMLLimitedQuirksMode;
        }
    }
    return HTMLNoQuirksMode;
}

- (void)addParseError
{
    [_errors addObject:[NSNull null]];
}

@end
