//
//  HTMLParser.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLParser.h"
#import "HTMLString.h"
#import "HTMLTokenizer.h"

@interface HTMLMarker : NSObject <NSCopying>

+ (instancetype)marker;

@end

typedef NS_ENUM(NSInteger, HTMLInsertionMode)
{
    HTMLInvalidInsertionMode, // SPEC This insertion mode is just for us.
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
    HTMLAfterBodyInsertionMode,
    HTMLInFramesetInsertionMode,
    HTMLAfterFramesetInsertionMode,
    HTMLAfterAfterBodyInsertionMode,
    HTMLAfterAfterFramesetInsertionMode,
};

static inline NSString * NSStringFromHTMLInsertionMode(HTMLInsertionMode mode)
{
    switch (mode) {
        case HTMLInvalidInsertionMode:
            return @"invalidInsertionMode";
        case HTMLInitialInsertionMode:
            return @"initialInsertionMode";
        case HTMLBeforeHtmlInsertionMode:
            return @"beforeHtmlInsertionMode";
        case HTMLBeforeHeadInsertionMode:
            return @"beforeHeadInsertionMode";
        case HTMLInHeadInsertionMode:
            return @"inHeadInsertionMode";
        case HTMLInHeadNoscriptInsertionMode:
            return @"inHeadNoscriptInsertionMode";
        case HTMLAfterHeadInsertionMode:
            return @"afterHeadInsertionMode";
        case HTMLInBodyInsertionMode:
            return @"inBodyInsertionMode";
        case HTMLTextInsertionMode:
            return @"textInsertionMode";
        case HTMLInTableInsertionMode:
            return @"inTableInsertionMode";
        case HTMLInTableTextInsertionMode:
            return @"inTableTextInsertionMode";
        case HTMLInCaptionInsertionMode:
            return @"inCaptionInsertionMode";
        case HTMLInColumnGroupInsertionMode:
            return @"inColumnGroupInsertionMode";
        case HTMLInTableBodyInsertionMode:
            return @"inTableBodyInsertionMode";
        case HTMLInRowInsertionMode:
            return @"inRowInsertionMode";
        case HTMLInCellInsertionMode:
            return @"inCellInsertionMode";
        case HTMLInSelectInsertionMode:
            return @"inSelectInsertionMode";
        case HTMLInSelectInTableInsertionMode:
            return @"inSelectInTableInsertionMode";
        case HTMLAfterBodyInsertionMode:
            return @"afterBodyInsertionMode";
        case HTMLInFramesetInsertionMode:
            return @"inFramesetInsertionMode";
        case HTMLAfterFramesetInsertionMode:
            return @"afterFramesetInsertionMode";
        case HTMLAfterAfterBodyInsertionMode:
            return @"afterAfterBodyInsertionMode";
        case HTMLAfterAfterFramesetInsertionMode:
            return @"afterAfterFramesetInsertionMode";
    }
}

@implementation HTMLParser
{
    HTMLTokenizer *_tokenizer;
    HTMLInsertionMode _insertionMode;
    HTMLInsertionMode _originalInsertionMode;
    HTMLElementNode *_context;
    NSMutableArray *_stackOfOpenElements;
    HTMLElementNode *_headElementPointer;
    HTMLElementNode *_formElementPointer;
    HTMLDocument *_document;
    NSMutableArray *_errors;
    NSMutableArray *_tokensToReconsume;
    BOOL _framesetOkFlag;
    BOOL _ignoreNextTokenIfLineFeed;
    NSMutableArray *_activeFormattingElements;
    NSMutableArray *_pendingTableCharacterTokens;
    BOOL _fosterParenting;
    BOOL _done;
    BOOL _fragmentParsingAlgorithm;
}

- (id)initWithString:(NSString *)string
{
    if (!(self = [self init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    return self;
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    if (!(self = [self init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _context = context;
    _fragmentParsingAlgorithm = YES;
    return self;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _insertionMode = HTMLInitialInsertionMode;
    _stackOfOpenElements = [NSMutableArray new];
    _errors = [NSMutableArray new];
    _tokensToReconsume = [NSMutableArray new];
    _framesetOkFlag = YES;
    _activeFormattingElements = [NSMutableArray new];
    return self;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    void (^reconsumeAll)(void) = ^{
        while (_tokensToReconsume.count > 0) {
            id again = _tokensToReconsume[0];
            [_tokensToReconsume removeObjectAtIndex:0];
            [self resume:again];
        }
    };
    for (id token in _tokenizer) {
        if (_done) break;
        [self resume:token];
        reconsumeAll();
    }
    [_tokensToReconsume addObject:[HTMLEOFToken new]];
    if (!_done) reconsumeAll();
    return _document;
}

- (NSArray *)errors
{
    return [_errors copy];
}

static inline BOOL IsSpaceCharacterToken(HTMLCharacterToken *token)
{
    UTF32Char data = token.data;
    return data == '\t' || data == '\n' || data == '\f' || data == '\r' || data == ' ';
}

#pragma mark The "initial" insertion mode

- (void)initialInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (!IsSpaceCharacterToken(token)) {
        [self initialInsertionModeHandleAnythingElse:token];
    }
}

- (void)initialInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_document];
}

- (void)initialInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    NSString *name = token.name;
    NSString *public = token.publicIdentifier;
    NSString *system = token.systemIdentifier;
    if (^{
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
    }())
    {
        [self addParseError];
    }
    _document.doctype = [[HTMLDocumentTypeNode alloc] initWithName:token.name
                                                          publicId:token.publicIdentifier
                                                          systemId:token.systemIdentifier];
    [_document appendChild:_document.doctype];
    _document.quirksMode = ^{
        if (token.forceQuirks) return HTMLQuirksMode;
        if (![name isEqualToString:@"html"]) return HTMLQuirksMode;
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
            if ([public hasPrefix:Prefixes[i]]) {
                return HTMLQuirksMode;
            }
        }
        if ([public isEqualToString:@"-//W3O//DTD W3 HTML Strict 3.0//EN//"] ||
            [public isEqualToString:@"-/W3C/DTD HTML 4.0 Transitional/EN"] ||
            [public isEqualToString:@"HTML"])
        {
            return HTMLQuirksMode;
        }
        if ([system isEqualToString:@"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"]) {
            return HTMLQuirksMode;
        }
        if (!system) {
            if ([public hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
                [public hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
            {
                return HTMLQuirksMode;
            }
        }
        if ([public hasPrefix:@"-//W3C//DTD XHTML 1.0 Frameset//"] ||
            [public hasPrefix:@"-//W3C//DTD XHTML 1.0 Transitional//"])
        {
            return HTMLLimitedQuirksMode;
        }
        if (system) {
            if ([public hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
                [public hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
            {
                return HTMLLimitedQuirksMode;
            }
        }
        return HTMLNoQuirksMode;
    }();
    [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
}

- (void)initialInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError];
    _document.quirksMode = HTMLQuirksMode;
    [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
    [self reprocess:token];
}

#pragma mark The "before html" insertion mode

- (void)beforeHtmlInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)beforeHtmlInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_document];
}

- (void)beforeHtmlInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (!IsSpaceCharacterToken(token)) {
        [self beforeHtmlInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHtmlInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        HTMLElementNode *html = [self createElementForToken:token];
        [_document appendChild:html];
        [_stackOfOpenElements addObject:html];
        [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
    } else {
        [self beforeHtmlInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHtmlInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"head", @"body", @"html", @"br" ] containsObject:token.tagName]) {
        [self beforeHtmlInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError];
    }
}

- (void)beforeHtmlInsertionModeHandleAnythingElse:(id)token
{
    HTMLElementNode *html = [[HTMLElementNode alloc] initWithTagName:@"html"];
    [_document appendChild:html];
    [_stackOfOpenElements addObject:html];
    [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
    [self reprocess:token];
}

#pragma mark The "before head" insertion mode

- (void)beforeHeadInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (!IsSpaceCharacterToken(token)) {
        [self beforeHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)beforeHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)beforeHeadInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"head"]) {
        HTMLElementNode *head = [self insertElementForToken:token];
        _headElementPointer = head;
        [self switchInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self beforeHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"head", @"body", @"html", @"br" ] containsObject:token.tagName]) {
        [self beforeHeadInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError];
    }
}

- (void)beforeHeadInsertionModeHandleAnythingElse:(id)token
{
    [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"head"]];
    HTMLElementNode *head = [[HTMLElementNode alloc] initWithTagName:@"head"];
    _headElementPointer = head;
    [self switchInsertionMode:HTMLInHeadInsertionMode];
    [self reprocess:token];
}

#pragma mark The "in head" insertion mode

- (void)inHeadInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self insertCharacter:token.data];
    } else {
        [self inHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)inHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inHeadInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([@[ @"base", @"basefont", @"bgsound", @"link" ] containsObject:token.tagName]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"meta"]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"title"]) {
        [self followGenericRCDATAElementParsingAlgorithmForToken:token];
    } else if ([@[ @"noscript", @"noframes", @"style" ] containsObject:token.tagName]) {
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"script"]) {
        NSUInteger index;
        HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
        HTMLElementNode *script = [self createElementForToken:token];
        [adjustedInsertionLocation insertChild:script atIndex:index];
        [_stackOfOpenElements addObject:script];
        _tokenizer.state = HTMLScriptDataTokenizerState;
        [self switchInsertionMode:HTMLTextInsertionMode];
        _originalInsertionMode = _insertionMode;
    } else if ([token.tagName isEqualToString:@"head"]) {
        [self addParseError];
    } else {
        [self inHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)inHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"head"]) {
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLAfterHeadInsertionMode];
    } else if ([@[ @"body", @"html", @"br" ] containsObject:token.tagName]) {
        [self inHeadInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError];
    }
}

- (void)inHeadInsertionModeHandleAnythingElse:(id)token
{
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLAfterHeadInsertionMode];
    [self reprocess:token];
}

#pragma mark The "after head" insertion mode

- (void)afterHeadInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self insertCharacter:token.data];
    } else {
        [self afterHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)afterHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)afterHeadInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"body"]) {
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
        [self switchInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"frameset"]) {
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInFramesetInsertionMode];
    } else if ([@[ @"base", @"basefont", @"bgsound", @"link", @"meta", @"noframes", @"script",
                @"style", @"title" ] containsObject:token.tagName])
    {
        [self addParseError];
        [_stackOfOpenElements addObject:_headElementPointer];
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
        [_stackOfOpenElements removeObject:_headElementPointer];
    } else if ([token.tagName isEqualToString:@"head"]) {
        [self addParseError];
    } else {
        [self afterHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"body", @"html", @"br" ] containsObject:token.tagName]) {
        [self afterHeadInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError];
    }
}

- (void)afterHeadInsertionModeHandleAnythingElse:(id)token
{
    [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"body"]];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocess:token];
}

#pragma mark The "in body" insertion mode

- (void)inBodyInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError];
    } else {
        [self reconstructTheActiveFormattingElements];
        [self insertCharacter:token.data];
        if (!IsSpaceCharacterToken(token)) {
            _framesetOkFlag = NO;
        }
    }
}

- (void)inBodyInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inBodyInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self addParseError];
        HTMLElementNode *element = _stackOfOpenElements.lastObject;
        for (HTMLAttribute *attribute in token.attributes) {
            if (![[element.attributes valueForKey:@"name"] containsObject:attribute.name]) {
                [element addAttribute:attribute];
            }
        }
    } else if ([@[ @"base", @"basefont", @"bgsound", @"link", @"meta", @"noframes", @"script",
                @"style", @"title" ] containsObject:token.tagName])
    {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else if ([token.tagName isEqualToString:@"body"]) {
        [self addParseError];
        if (_stackOfOpenElements.count < 2 ||
            ![[_stackOfOpenElements[1] tagName] isEqualToString:@"body"])
        {
            return;
        }
        _framesetOkFlag = NO;
        HTMLElementNode *body = _stackOfOpenElements[1];
        for (HTMLAttribute *attribute in token.attributes) {
            if (![[body.attributes valueForKey:@"name"] containsObject:attribute.name]) {
                [body addAttribute:attribute];
            }
        }
    } else if ([token.tagName isEqualToString:@"frameset"]) {
        [self addParseError];
        if (_stackOfOpenElements.count < 2 ||
            ![[_stackOfOpenElements[1] tagName] isEqualToString:@"body"])
        {
            return;
        }
        if (!_framesetOkFlag) return;
        [_stackOfOpenElements[0] removeChild:_stackOfOpenElements[1]];
        while (_stackOfOpenElements.count > 1) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInFramesetInsertionMode];
    } else if ([@[ @"address", @"article", @"aside", @"blockquote", @"center", @"details",
                @"dialog", @"dir", @"div", @"dl", @"fieldset", @"figcaption", @"figure", @"footer",
                @"header", @"hgroup", @"main", @"menu", @"nav", @"ol", @"p", @"section",
                @"summary", @"ul" ] containsObject:token.tagName])
    {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
    } else if ([@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:token.tagName]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        if ([@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:
             [_stackOfOpenElements.lastObject tagName]])
        {
            [self addParseError];
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if ([@[ @"pre", @"listing" ] containsObject:token.tagName]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
        _ignoreNextTokenIfLineFeed = YES;
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"form"]) {
        if (_formElementPointer) {
            [self addParseError];
            return;
        }
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        HTMLElementNode *form = [self insertElementForToken:token];
        _formElementPointer = form;
    } else if ([token.tagName isEqualToString:@"li"]) {
        _framesetOkFlag = NO;
        HTMLElementNode *node = _stackOfOpenElements.lastObject;
    loop:
        if ([node.tagName isEqualToString:@"li"]) {
            [self generateImpliedEndTagsExceptForTagsNamed:@"li"];
            if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"li"]) {
                [self addParseError];
            }
            while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"li"]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            goto done;
        }
        if ([@[ @"applet", @"area", @"article", @"aside", @"base", @"basefont", @"bgsound",
             @"blockquote", @"body", @"br", @"button", @"caption", @"center", @"col", @"colgroup",
             @"dd", @"details", @"dir", @"dl", @"dt", @"embed", @"fieldset", @"figcaption", @"figure",
             @"footer", @"form", @"frame", @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6",
             @"head", @"header", @"hgroup", @"hr", @"html", @"iframe", @"img", @"input", @"isindex",
             @"li", @"link", @"listing", @"main", @"marquee", @"menu", @"menuitem", @"meta", @"nav",
             @"noembed", @"noframes", @"noscript", @"object", @"ol", @"param", @"plaintext", @"pre",
             @"script", @"section", @"select", @"source", @"style", @"summary", @"table", @"tbody",
             @"td", @"textarea", @"tfoot", @"th", @"thead", @"title", @"tr", @"track", @"ul", @"wbr",
             @"xmp" ] containsObject:node.tagName])
        {
            goto done;
        }
        node = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:node] - 1];
        goto loop;
    done:
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
    } else if ([@[ @"dd", @"dt" ] containsObject:token.tagName]) {
        _framesetOkFlag = NO;
        for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
            if ([node.tagName isEqualToString:@"dd"]) {
                [self generateImpliedEndTagsExceptForTagsNamed:@"dd"];
                if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"dd"]) {
                    [self addParseError];
                }
                while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"dd"]) {
                    [_stackOfOpenElements removeLastObject];
                }
                [_stackOfOpenElements removeLastObject];
                break;
            } else if ([node.tagName isEqualToString:@"dt"]) {
                [self generateImpliedEndTagsExceptForTagsNamed:@"dt"];
                if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"dt"]) {
                    [self addParseError];
                }
                while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"dt"]) {
                    [_stackOfOpenElements removeLastObject];
                }
                [_stackOfOpenElements removeLastObject];
                break;
            } else if ([@[ @"applet", @"area", @"article", @"aside", @"base", @"basefont",
                        @"bgsound", @"blockquote", @"body", @"br", @"button", @"caption",
                        @"center", @"col", @"colgroup", @"dd", @"details", @"dir", @"dl", @"dt",
                        @"embed", @"fieldset", @"figcaption", @"figure", @"footer", @"form",
                        @"frame", @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head",
                        @"header", @"hgroup", @"hr", @"html", @"iframe", @"img", @"input",
                        @"isindex", @"li", @"link", @"listing", @"main", @"marquee", @"menu",
                        @"menuitem", @"meta", @"nav", @"noembed", @"noframes", @"noscript",
                        @"object", @"ol", @"param", @"plaintext", @"pre", @"script", @"section",
                        @"select", @"source", @"style", @"summary", @"table", @"tbody", @"td",
                        @"textarea", @"tfoot", @"th", @"thead", @"title", @"tr", @"track", @"ul",
                        @"wbr", @"xmp" ] containsObject:node.tagName])
            {
                break;
            }
        }
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"plaintext"]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
        _tokenizer.state = HTMLPLAINTEXTTokenizerState;
    } else if ([token.tagName isEqualToString:@"button"]) {
        if ([self elementInScopeWithTagName:@"button"]) {
            [self addParseError];
            [self generateImpliedEndTags];
            while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"button"]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
        }
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"a"]) {
        for (HTMLElementNode *element in _activeFormattingElements.reverseObjectEnumerator.allObjects) {
            if ([element isEqual:[HTMLMarker marker]]) break;
            if ([element.tagName isEqualToString:@"a"]) {
                [self addParseError];
                if (![self runAdoptionAgencyAlgorithmForTagName:@"a"]) {
                    [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
                    return;
                }
                [self removeElementFromListOfActiveFormattingElements:element];
                [_stackOfOpenElements removeObject:element];
                break;
            }
        }
        [self reconstructTheActiveFormattingElements];
        HTMLElementNode *element = [self insertElementForToken:token];
        [self pushElementOnToListOfActiveFormattingElements:element];
    } else if ([@[ @"b", @"big", @"code", @"em", @"font", @"i", @"s", @"small", @"strike", @"strong",
                @"tt", @"u" ] containsObject:token.tagName])
    {
        [self reconstructTheActiveFormattingElements];
        HTMLElementNode *element = [self insertElementForToken:token];
        [self pushElementOnToListOfActiveFormattingElements:element];
    } else if ([token.tagName isEqualToString:@"nobr"]) {
        [self reconstructTheActiveFormattingElements];
        if ([self elementInScopeWithTagName:@"nobr"]) {
            [self addParseError];
            if (![self runAdoptionAgencyAlgorithmForTagName:@"nobr"]) {
                [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
                return;
            }
            [self reconstructTheActiveFormattingElements];
        }
        HTMLElementNode *element = [self insertElementForToken:token];
        [self pushElementOnToListOfActiveFormattingElements:element];
    } else if ([@[ @"applet", @"marquee", @"object" ] containsObject:token.tagName]) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [self pushMarkerOnToListOfActiveFormattingElements];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"table"]) {
        if (_document.quirksMode != HTMLQuirksMode && [self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([@[ @"area", @"br", @"embed", @"img", @"keygen", @"wbr" ]
                containsObject:token.tagName])
    {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"input"]) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        HTMLAttribute *type;
        for (HTMLAttribute *attribute in token.attributes) {
            if ([attribute.name isEqualToString:@"type"]) {
                type = attribute;
                break;
            }
        }
        if (!type || [type.value caseInsensitiveCompare:@"hidden"] != NSOrderedSame) {
            _framesetOkFlag = NO;
        }
    } else if ([@[ @"menuitem", @"param", @"source", @"track" ] containsObject:token.tagName]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"hr"]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"image"]) {
        [self addParseError];
        [self reprocess:[token copyWithTagName:@"img"]];
    } else if ([token.tagName isEqualToString:@"isindex"]) {
        [self addParseError];
        if (_formElementPointer) return;
        _framesetOkFlag = NO;
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        HTMLElementNode *form = [self insertElementForToken:
                                 [[HTMLStartTagToken alloc] initWithTagName:@"form"]];
        _formElementPointer = form;
        for (HTMLAttribute *attribute in token.attributes) {
            if ([attribute.name isEqualToString:@"action"]) {
                [form addAttribute:attribute];
            }
        }
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"hr"]];
        [_stackOfOpenElements removeLastObject];
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"label"]];
        NSString *prompt = @"This is a searchable index. Enter search keywords: ";
        for (HTMLAttribute *attribute in token.attributes) {
            if ([attribute.name isEqualToString:@"prompt"]) {
                prompt = attribute.value;
                break;
            }
        }
        EnumerateLongCharacters(prompt, ^(UTF32Char character) {
            [self insertCharacter:character];
        });
        HTMLStartTagToken *inputToken = [[HTMLStartTagToken alloc] initWithTagName:@"input"];
        for (HTMLAttribute *attribute in token.attributes) {
            if (![@[ @"name", @"action", @"prompt" ] containsObject:attribute.name]) {
                [inputToken addAttributeWithName:attribute.name value:attribute.value];
            }
        }
        [inputToken addAttributeWithName:@"name" value:@"isindex"];
        [self insertElementForToken:inputToken];
        [_stackOfOpenElements removeLastObject];
        [_stackOfOpenElements removeLastObject];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"hr"]];
        [_stackOfOpenElements removeLastObject];
        [_stackOfOpenElements removeLastObject];
        _formElementPointer = nil;
    } else if ([token.tagName isEqualToString:@"textarea"]) {
        [self insertElementForToken:token];
        _ignoreNextTokenIfLineFeed = YES;
        _tokenizer.state = HTMLRCDATATokenizerState;
        _originalInsertionMode = _insertionMode;
        _framesetOkFlag = NO;
        [self switchInsertionMode:HTMLTextInsertionMode];
    } else if ([token.tagName isEqualToString:@"xmp"]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self reconstructTheActiveFormattingElements];
        _framesetOkFlag = NO;
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"iframe"]) {
        _framesetOkFlag = NO;
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"noembed"]) {
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"select"]) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
        // TODO not sure what's going on here. Processing something as if it was in another state, perhaps? If so, this will fail to pick anything other than the default branch.
        switch (_insertionMode) {
            case HTMLInTableInsertionMode:
            case HTMLInCaptionInsertionMode:
            case HTMLInTableBodyInsertionMode:
            case HTMLInRowInsertionMode:
            case HTMLInCellInsertionMode:
                [self switchInsertionMode:HTMLInSelectInTableInsertionMode];
                break;
            default:
                [self switchInsertionMode:HTMLInSelectInsertionMode];
                break;
        }
    } else if ([@[ @"optgroup", @"option" ] containsObject:token.tagName]) {
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
    } else if ([@[ @"rp", @"rt" ] containsObject:token.tagName]) {
        if ([self elementInScopeWithTagName:@"ruby"]) {
            [self generateImpliedEndTags];
            if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"ruby"]) {
                [self addParseError];
            }
        }
        [self insertElementForToken:token];
    } else if ([@[ @"caption", @"col", @"colgroup", @"frame", @"head", @"tbody", @"td", @"tfoot",
                @"th", @"thead", @"tr" ] containsObject:token.tagName])
    {
        [self addParseError];
    } else {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
    }
}

- (void)inBodyInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    NSArray *list = @[ @"dd", @"dt", @"li", @"p", @"tbody", @"td", @"tfoot", @"th", @"thead",
                       @"tr", @"body", @"html" ];
    for (HTMLElementNode *node in _stackOfOpenElements) {
        if (![list containsObject:node.tagName]) {
            [self addParseError];
            break;
        }
    }
    [self stopParsing];
}

- (void)inBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"body", @"html" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagName:@"body"]) {
            [self addParseError];
            return;
        }
        for (HTMLElementNode *element in _stackOfOpenElements.reverseObjectEnumerator) {
            if (![@[ @"dd", @"dt", @"li", @"optgroup", @"option", @"p", @"rp", @"rt", @"tbody", @"td",
                  @"tfoot", @"th", @"thead", @"tr", @"body", @"html" ] containsObject:element.tagName])
            {
                [self addParseError];
                break;
            }
        }
        [self switchInsertionMode:HTMLAfterBodyInsertionMode];
        if ([token.tagName isEqualToString:@"html"]) {
            [self reprocess:token];
        }
    } else if ([@[ @"address", @"article", @"aside", @"blockquote", @"button", @"center",
                @"details", @"dialog", @"dir", @"div", @"dl", @"fieldset", @"figcaption",
                @"figure", @"footer", @"header", @"hgroup", @"listing", @"main", @"menu", @"nav",
                @"ol", @"pre", @"section", @"summary", @"ul" ] containsObject:token.tagName])
    {
        if (![self elementInScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"form"]) {
        HTMLElementNode *node = _formElementPointer;
        _formElementPointer = nil;
        if (![self isElementInScope:node]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![_stackOfOpenElements.lastObject isEqual:node]) {
            [self addParseError];
        }
        [_stackOfOpenElements removeObject:node];
    } else if ([token.tagName isEqualToString:@"p"]) {
        if (![self elementInButtonScopeWithTagName:@"p"]) {
            [self addParseError];
            [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"p"]];
        }
        [self closePElement];
    } else if ([token.tagName isEqualToString:@"li"]) {
        if (![self elementInListItemScopeWithTagName:@"li"]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTagsExceptForTagsNamed:@"li"];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"li"]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"li"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([@[ @"dd", @"dt" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTagsExceptForTagsNamed:token.tagName];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagNameInArray:@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ]])
        {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [self addParseError];
        }
        while (![@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:
                 [_stackOfOpenElements.lastObject tagName]])
        {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([@[ @"a", @"b", @"big", @"code", @"em", @"font", @"i", @"nobr", @"s", @"small",
                @"strike", @"strong", @"tt", @"u" ] containsObject:token.tagName])
    {
        if (![self runAdoptionAgencyAlgorithmForTagName:token.tagName]) {
            [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
            return;
        }
    } else if ([@[ @"applet", @"marquee", @"object" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self clearActiveFormattingElementsUpToLastMarker];
    } else if ([token.tagName isEqualToString:@"br"]) {
        [self addParseError];
        [self inBodyInsertionModeHandleStartTagToken:
         [[HTMLStartTagToken alloc] initWithTagName:@"br"]];
    } else {
        [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
    }
}

- (void)inBodyInsertionModeHandleAnyOtherEndTagToken:(id)token
{
    HTMLElementNode *node = _stackOfOpenElements.lastObject;
    do {
        if ([node.tagName isEqualToString:[token tagName]]) {
            [self generateImpliedEndTagsExceptForTagsNamed:[token tagName]];
            if (![_stackOfOpenElements.lastObject isKindOfClass:[HTMLElementNode class]] ||
                ![[_stackOfOpenElements.lastObject tagName] isEqualToString:[token tagName]])
            {
                [self addParseError];
            }
            while (![_stackOfOpenElements.lastObject isEqual:node]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            break;
        } else if ([@[ @"address", @"applet", @"area", @"article", @"aside", @"base", @"basefont",
                    @"bgsound", @"blockquote", @"body", @"br", @"button", @"caption", @"center",
                    @"col", @"colgroup", @"dd", @"details", @"dir", @"div", @"dl", @"dt", @"embed",
                    @"fieldset", @"figcaption", @"figure", @"footer", @"form", @"frame",
                    @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"header",
                    @"hgroup", @"hr", @"html", @"iframe", @"img", @"input", @"isindex", @"li",
                    @"link", @"listing", @"main", @"marquee", @"menu", @"menuitem", @"meta",
                    @"nav", @"noembed", @"noframes", @"noscript", @"object", @"ol", @"p", @"param",
                    @"plaintext", @"pre", @"script", @"section", @"select", @"source", @"style",
                    @"summary", @"table", @"tbody", @"td", @"textarea", @"tfoot", @"th", @"thead",
                    @"title", @"tr", @"track", @"ul", @"wbr", @"xmp" ] containsObject:node.tagName])
        {
            [self addParseError];
            return;
        }
        node = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:node] - 1];
    } while (YES);
}

#pragma mark The "text" insertion mode

- (void)textInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    [self insertCharacter:token.data];
}

- (void)textInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self addParseError];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:_originalInsertionMode];
    [self reprocess:token];
}

- (void)textInsertionModeHandleEndTagToken:(__unused HTMLEndTagToken *)token
{
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:_originalInsertionMode];
}

#pragma mark The "in table" insertion mode

- (void)inTableInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if ([@[ @"table", @"tbody", @"tfoot", @"thead", @"tr" ]
         containsObject:[_stackOfOpenElements.lastObject tagName]])
    {
        _pendingTableCharacterTokens = [NSMutableArray new];
        [self switchInsertionMode:HTMLInTableTextInsertionMode];
        _originalInsertionMode = _insertionMode;
        [self reprocess:token];
    } else {
        [self inTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inTableInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inTableInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"caption"]) {
        [self clearStackBackToATableContext];
        [self pushMarkerOnToListOfActiveFormattingElements];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInCaptionInsertionMode];
    } else if ([token.tagName isEqualToString:@"colgroup"]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInColumnGroupInsertionMode];
    } else if ([token.tagName isEqualToString:@"col"]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"colgroup"]];
        [self switchInsertionMode:HTMLInColumnGroupInsertionMode];
        [self reprocess:token];
    } else if ([@[ @"tbody", @"tfoot", @"thead" ] containsObject:token.tagName]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if ([@[ @"td", @"th", @"tr" ] containsObject:token.tagName]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"tbody"]];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        [self reprocess:token];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self addParseError];
        if (![self elementInTableScopeWithTagName:@"table"]) {
            return;
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"table"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocess:token];
    } else if ([@[ @"style", @"script" ] containsObject:token.tagName]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else if ([token.tagName isEqualToString:@"input"]) {
        HTMLAttribute *type;
        for (HTMLAttribute *attribute in token.attributes) {
            if ([attribute.name isEqualToString:@"type"]) {
                type = attribute;
                break;
            }
        }
        if (![type.value isEqualToString:@"hidden"]) {
            [self inTableInsertionModeHandleAnythingElse:token];
            return;
        }
        [self addParseError];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"form"]) {
        [self addParseError];
        if (_formElementPointer) return;
        HTMLElementNode *form = [self insertElementForToken:token];
        _formElementPointer = form;
        [_stackOfOpenElements removeLastObject];
    } else {
        [self inTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"table"]) {
        if (![self elementInTableScopeWithTagName:@"table"]) {
            [self addParseError];
            return;
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"table"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html", @"tbody", @"td", @"tfoot",
                @"th", @"thead", @"tr" ] containsObject:token.tagName])
    {
        [self addParseError];
    } else {
        [self inTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)inTableInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError];
    _fosterParenting = YES;
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    _fosterParenting = NO;
}

#pragma mark The "in table text" insertion mode

- (void)inTableTextInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError];
    } else {
        [_pendingTableCharacterTokens addObject:token];
    }
}

- (void)inTableTextInsertionModeHandleAnythingElse:(id)token
{
    NSUInteger firstNonSpace = [_pendingTableCharacterTokens indexOfObjectPassingTest:
                                ^BOOL(HTMLCharacterToken *c, __unused NSUInteger _, __unused BOOL *__)
    {
        return !IsSpaceCharacterToken(c);
    }];
    if (firstNonSpace != NSNotFound) {
        // Same rules as "anything else" entry in the "in table" insertion mode.
        for (HTMLCharacterToken *token in _pendingTableCharacterTokens) {
            _fosterParenting = YES;
            [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
            _fosterParenting = NO;
        }
    } else {
        for (HTMLCharacterToken *token in _pendingTableCharacterTokens) {
            [self insertCharacter:token.data];
        }
    }
    [self switchInsertionMode:_originalInsertionMode];
    [self reprocess:token];
}

#pragma mark The "in caption" insertion mode

- (void)inCaptionInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"caption"]) {
        if (![self elementInTableScopeWithTagName:@"caption"]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"caption"]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"caption"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self clearActiveFormattingElementsUpToLastMarker];
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self inCaptionInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else if ([@[ @"body", @"col", @"colgroup", @"html", @"tbody", @"td", @"tfoot", @"th",
                @"thead", @"tr" ] containsObject:token.tagName])
    {
        [self addParseError];
    } else {
        [self inCaptionInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCaptionInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"caption", @"col", @"colgorup", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr" ]
         containsObject:token.tagName])
    {
        [self inCaptionInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else {
        [self inCaptionInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCaptionInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:(id)token
{
    [self addParseError];
    if (![self elementInTableScopeWithTagName:@"caption"]) {
        return;
    }
    while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"caption"]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
    [self clearActiveFormattingElementsUpToLastMarker];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocess:token];
}

- (void)inCaptionInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

#pragma mark The "in column group" insertion mode

- (void)inColumnGroupInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self insertCharacter:token.data];
    } else {
        [self inColumnGroupInsertionModeHandleAnythingElse:token];
    }
}

- (void)inColumnGroupInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inColumnGroupInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inColumnGroupInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"col"]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else {
        [self inColumnGroupInsertionModeHandleAnythingElse:token];
    }
}

- (void)inColumnGroupInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"colgroup"]) {
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"colgroup"]) {
            [self addParseError];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([token.tagName isEqualToString:@"col"]) {
        [self addParseError];
    } else {
        [self inColumnGroupInsertionModeHandleAnythingElse:token];
    }
}

- (void)inColumnGroupInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)inColumnGroupInsertionModeHandleAnythingElse:(id)token
{
    if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"colgroup"]) {
        [self addParseError];
        return;
    }
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocess:token];
}

#pragma mark The "in table body" insertion mode

- (void)inTableBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"tr"]) {
        [self clearStackBackToATableBodyContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInRowInsertionMode];
    } else if ([@[ @"th", @"td" ] containsObject:token.tagName]) {
        [self addParseError];
        [self clearStackBackToATableBodyContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"tr"]];
        [self switchInsertionMode:HTMLInRowInsertionMode];
        [self reprocess:token];
    } else if ([@[ @"caption", @"col", @"colgroup", @"tbody", @"tfoot", @"thead" ]
                containsObject:token.tagName])
    {
        [self inTableBodyInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else {
        [self inTableBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"tbody", @"tfoot", @"thead" ] containsObject:token.tagName]) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self clearStackBackToATableBodyContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self inTableBodyInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html", @"td", @"th", @"tr" ]
                containsObject:token.tagName])
    {
        [self addParseError];
    } else {
        [self inTableBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableBodyInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:(id)token
{
    if (![self elementInTableScopeWithTagNameInArray:@[ @"tbody", @"thead", @"tfoot" ]]) {
        [self addParseError];
        return;
    }
    [self clearStackBackToATableBodyContext];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocess:token];
}

- (void)inTableBodyInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInTableInsertionMode];
}

#pragma mark The "in row" insertion mode

- (void)inRowInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"th", @"td" ] containsObject:token.tagName]) {
        [self clearStackBackToATableRowContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInCellInsertionMode];
        [self pushMarkerOnToListOfActiveFormattingElements];
    } else if ([@[ @"caption", @"col", @"colgroup", @"tbody", @"tfoot", @"thead", @"tr" ]
                containsObject:token.tagName])
    {
        [self inRowInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else {
        [self inRowInsertionModeHandleAnythingElse:token];
    }
}

- (void)inRowInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"tr"]) {
        if (![self elementInTableScopeWithTagName:@"tr"]) {
            [self addParseError];
            return;
        }
        [self clearStackBackToATableRowContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self inRowInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else if ([@[ @"tbody", @"tfoot", @"thead" ] containsObject:token.tagName]) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        if (![self elementInTableScopeWithTagName:@"tr"]) {
            return;
        }
        [self clearStackBackToATableRowContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        [self reprocess:token];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html", @"td", @"th" ]
                containsObject:token.tagName])
    {
        [self addParseError];
    } else {
        [self inRowInsertionModeHandleAnythingElse:token];
    }
}

- (void)inRowInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:(id)token
{
    if (![self elementInTableScopeWithTagName:@"tr"]) {
        [self addParseError];
        return;
    }
    [self clearStackBackToATableRowContext];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    [self reprocess:token];
}

- (void)inRowInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInTableInsertionMode];
}

#pragma mark The "in cell" insertion mode

- (void)inCellInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"caption", @"col", @"colgroup", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr" ]
         containsObject:token.tagName])
    {
        if (![self elementInTableScopeWithTagNameInArray:@[ @"td", @"th" ]]) {
            [self addParseError];
            return;
        }
        [self closeTheCell];
        [self reprocess:token];
    } else {
        [self inCellInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCellInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"td", @"th" ] containsObject:token.tagName]) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self generateImpliedEndTags];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [self addParseError];
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self clearActiveFormattingElementsUpToLastMarker];
        [self switchInsertionMode:HTMLInRowInsertionMode];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html" ]
                containsObject:token.tagName])
    {
        [self addParseError];
    } else if ([@[ @"table", @"tbody", @"tfoot", @"thead", @"tr" ]
                containsObject:token.tagName])
    {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError];
            return;
        }
        [self closeTheCell];
        [self reprocess:token];
    } else {
        [self inCellInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCellInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

#pragma mark The "in select" insertion mode

- (void)inSelectInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError];
    } else {
        [self insertCharacter:token.data];
    }
}

- (void)inSelectInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inSelectInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inSelectInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"option"]) {
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"optgroup"]) {
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"optgroup"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"select"]) {
        [self addParseError];
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
    } else if ([@[ @"input", @"keygen", @"textarea" ] containsObject:token.tagName]) {
        [self addParseError];
        if (![self selectElementInSelectScope]) {
            return;
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocess:token];
    } else if ([token.tagName isEqualToString:@"script"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self inSelectInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"optgroup"]) {
        HTMLElementNode *currentNode = _stackOfOpenElements.lastObject;
        HTMLElementNode *beforeIt = _stackOfOpenElements[_stackOfOpenElements.count - 2];
        if ([currentNode.tagName isEqualToString:@"option"] &&
            [beforeIt.tagName isEqualToString:@"optgroup"])
        {
            [_stackOfOpenElements removeLastObject];
        }
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"optgroup"]) {
            [_stackOfOpenElements removeLastObject];
        } else {
            [self addParseError];
            return;
        }
    } else if ([token.tagName isEqualToString:@"option"]) {
        if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        } else {
            [self addParseError];
            return;
        }
    } else if ([token.tagName isEqualToString:@"select"]) {
        if (![self selectElementInSelectScope]) {
            [self addParseError];
            return;
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
    } else {
        [self inSelectInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)inSelectInsertionModeHandleAnythingElse:(__unused id)token
{
    [self addParseError];
}

#pragma mark The "in select in table" insertion mode

- (void)inSelectInTableInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th" ]
         containsObject:token.tagName])
    {
        [self addParseError];
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocess:token];
    } else {
        [self inSelectInTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInTableInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th" ]
         containsObject:token.tagName])
    {
        [self addParseError];
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            return;
        }
        while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocess:token];
    } else {
        [self inSelectInTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInTableInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInSelectInsertionMode];
}

#pragma mark The "after body" insertion mode

- (void)afterBodyInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else {
        [self afterBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterBodyInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_stackOfOpenElements[0]];
}

- (void)afterBodyInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];   
}

- (void)afterBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else {
        [self afterBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self switchInsertionMode:HTMLAfterAfterBodyInsertionMode];
    } else {
        [self afterBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterBodyInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterBodyInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocess:token];
}

#pragma mark The "in frameset" insertion mode

- (void)inFramesetInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self insertCharacter:token.data];
    } else {
        [self inFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)inFramesetInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)inFramesetInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)inFramesetInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"frameset"]) {
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"frame"]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"noframes"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self inFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)inFramesetInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"frameset"]) {
        if (_stackOfOpenElements.count == 1 &&
            [[_stackOfOpenElements.lastObject tagName] isEqualToString:@"html"])
        {
            [self addParseError];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"frameset"]) {
            [self switchInsertionMode:HTMLAfterFramesetInsertionMode];
        }
    } else {
        [self inFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)inFramesetInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    if (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"html"] &&
        _stackOfOpenElements.count <= 1)
    {
        [self addParseError];
    }
    [self stopParsing];
}

- (void)inFramesetInsertionModeHandleAnythingElse:(__unused id)token
{
    [self addParseError];
}

#pragma mark The "after frameset" insertion mode

- (void)afterFramesetInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self insertCharacter:token.data];
    } else {
        [self afterFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterFramesetInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:nil];
}

- (void)afterFramesetInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError];
}

- (void)afterFramesetInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"noframes"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self afterFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterFramesetInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self switchInsertionMode:HTMLAfterAfterFramesetInsertionMode];
    } else {
        [self afterFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterFramesetInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterFramesetInsertionModeHandleAnythingElse:(__unused id)token
{
    [self addParseError];
}

#pragma mark The "after after body" insertion mode

- (void)afterAfterBodyInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_document];
}

- (void)afterAfterBodyInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)afterAfterBodyInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else {
        [self afterAfterBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterAfterBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else {
        [self afterAfterBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterAfterBodyInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterAfterBodyInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocess:token];
}

#pragma mark The "after after frameset" insertion mode

- (void)afterAfterFramesetInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_document];
}

- (void)afterAfterFramesetInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)afterAfterFramesetInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (IsSpaceCharacterToken(token)) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else {
        [self afterAfterFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterAfterFramesetInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"noframes"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self afterAfterFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterAfterFramesetInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterAfterFramesetInsertionModeHandleAnythingElse:(__unused id)token
{
    [self addParseError];
}

#pragma mark Everything else

- (void)resume:(id)currentToken
{
    if ([currentToken isKindOfClass:[HTMLParseErrorToken class]]) {
        [self addParseError];
        return;
    }
    if (_ignoreNextTokenIfLineFeed) {
        _ignoreNextTokenIfLineFeed = NO;
        if ([currentToken isKindOfClass:[HTMLCharacterToken class]] &&
            [(HTMLCharacterToken *)currentToken data] == '\n')
        {
            return;
        }
    }
    NSString *modeString = NSStringFromHTMLInsertionMode(_insertionMode);
    NSString *tokenType = [NSStringFromClass([currentToken class]) substringFromIndex:4];
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"%@Handle%@:", modeString, tokenType]);
    if (![self respondsToSelector:selector]) {
        selector = NSSelectorFromString([NSString stringWithFormat:@"%@HandleAnythingElse:", modeString]);
    }
    if ([self respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector withObject:currentToken];
        #pragma clang diagnostic pop
        return;
    }
    NSAssert(NO, @"this shouldn't happen: stuck in mode %@", modeString);
    NSLog(@"this shouldn't happen: stuck in mode %@", modeString);
}

- (void)insertComment:(NSString *)data inNode:(HTMLNode *)node
{
    NSUInteger index;
    if (node) {
        index = node.childNodes.count;
    } else {
        node = [self appropriatePlaceForInsertingANodeIndex:&index];
    }
    [node insertChild:[[HTMLCommentNode alloc] initWithData:data] atIndex:index];
}

- (HTMLNode *)appropriatePlaceForInsertingANodeIndex:(out NSUInteger *)index
{
    return [self appropriatePlaceForInsertingANodeWithOverrideTarget:nil index:index];
}

- (HTMLNode *)appropriatePlaceForInsertingANodeWithOverrideTarget:(HTMLNode *)overrideTarget
                                                            index:(out NSUInteger *)index
{
    HTMLElementNode *target = overrideTarget ?: _stackOfOpenElements.lastObject;
    if (_fosterParenting && [@[ @"table", @"tbody", @"tfoot", @"thead", @"tr" ] containsObject:target.tagName]) {
        HTMLElementNode *lastTable;
        for (HTMLElementNode *element in _stackOfOpenElements.reverseObjectEnumerator) {
            if ([element.tagName isEqualToString:@"table"]) {
                lastTable = element;
                break;
            }
        }
        if (!lastTable) {
            HTMLElementNode *html = _stackOfOpenElements[0];
            *index = html.childNodes.count;
            return html;
        }
        if (lastTable.parentNode) {
            *index = [lastTable.parentNode.childNodes indexOfObject:lastTable];
            return lastTable.parentNode;
        }
        HTMLElementNode *previousNode = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:lastTable] - 1];
        *index = previousNode.childNodes.count;
        return previousNode;
    } else {
        *index = target.childNodes.count;
        return target;
    }
}

- (void)switchInsertionMode:(HTMLInsertionMode)insertionMode
{
    if (_originalInsertionMode == insertionMode) {
        _originalInsertionMode = HTMLInvalidInsertionMode;
    }
    _insertionMode = insertionMode;
}

- (HTMLElementNode *)createElementForToken:(id)token
{
    HTMLElementNode *element = [[HTMLElementNode alloc] initWithTagName:[token tagName]];
    for (HTMLAttribute *attribute in [token attributes]) {
        [element addAttribute:attribute];
    }
    return element;
}

- (HTMLElementNode *)insertElementForToken:(id)token
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    HTMLElementNode *element = [self createElementForToken:token];
    [adjustedInsertionLocation insertChild:element atIndex:index];
    [_stackOfOpenElements addObject:element];
    return element;
}

- (void)insertCharacter:(UTF32Char)character
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    if ([adjustedInsertionLocation isKindOfClass:[HTMLDocument class]]) return;
    HTMLTextNode *textNode;
    if (index > 0 && [adjustedInsertionLocation.childNodes[index - 1] isKindOfClass:[HTMLTextNode class]]) {
        textNode = adjustedInsertionLocation.childNodes[index - 1];
    } else {
        textNode = [HTMLTextNode new];
        [adjustedInsertionLocation insertChild:textNode atIndex:index];
    }
    [textNode appendLongCharacter:character];
}

- (void)processToken:(id)token usingRulesForInsertionMode:(HTMLInsertionMode)insertionMode
{
    _originalInsertionMode = _insertionMode;
    _insertionMode = insertionMode;
    [self resume:token];
    if (_insertionMode == insertionMode) {
        _insertionMode = _originalInsertionMode;
        _originalInsertionMode = HTMLInvalidInsertionMode;
    }
}

- (void)reprocess:(id)token
{
    [_tokensToReconsume addObject:token];
}

- (void)pushElementOnToListOfActiveFormattingElements:(HTMLElementNode *)element
{
    NSInteger alreadyPresent = 0;
    for (HTMLElementNode *node in _activeFormattingElements.reverseObjectEnumerator.allObjects) {
        if ([node.tagName isEqualToString:element.tagName]) {
            alreadyPresent += 1;
            if (alreadyPresent == 3) {
                [_activeFormattingElements removeObject:node];
                break;
            }
        }
    }
    [_activeFormattingElements addObject:element];
}

- (void)pushMarkerOnToListOfActiveFormattingElements
{
    [_activeFormattingElements addObject:[HTMLMarker marker]];
}

- (void)removeElementFromListOfActiveFormattingElements:(HTMLElementNode *)element
{
    [_activeFormattingElements removeObject:element];
}

- (void)reconstructTheActiveFormattingElements
{
    if (_activeFormattingElements.count == 0) return;
    if ([_activeFormattingElements.lastObject isEqual:[HTMLMarker marker]]) return;
    if ([_stackOfOpenElements containsObject:_activeFormattingElements.lastObject]) return;
    NSUInteger entryIndex = _activeFormattingElements.count - 1;
rewind:
    if (entryIndex == 0) goto create;
    entryIndex--;
    if (!([_activeFormattingElements[entryIndex] isEqual:[HTMLMarker marker]] ||
          [_stackOfOpenElements containsObject:_activeFormattingElements[entryIndex]]))
    {
        goto rewind;
    }
advance:
    entryIndex++;
create:;
    HTMLElementNode *entry = _activeFormattingElements[entryIndex];
    HTMLStartTagToken *token = [[HTMLStartTagToken alloc] initWithTagName:entry.tagName];
    for (HTMLAttribute *attribute in entry.attributes) {
        [token addAttributeWithName:attribute.name value:attribute.value];
    }
    HTMLElementNode *newElement = [self insertElementForToken:token];
    [_activeFormattingElements replaceObjectAtIndex:entryIndex withObject:newElement];
    if (entryIndex + 1 != _activeFormattingElements.count) {
        goto advance;
    }
}

- (HTMLElementNode *)elementInScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]];
}

- (HTMLElementNode *)elementInScopeWithTagNameInArray:(NSArray *)tagNames
{
    return [self elementInScopeWithTagNameInArray:tagNames additionalElementTypes:nil];
}

- (HTMLElementNode *)elementInButtonScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]
                           additionalElementTypes:@[ @"button" ]];
}

- (HTMLElementNode *)elementInScopeWithTagNameInArray:(NSArray *)tagNames
                               additionalElementTypes:(NSArray *)additionalElementTypes
{
    NSArray *list = @[ @"applet", @"caption", @"html", @"table", @"td", @"th", @"marquee", @"object" ];
    if (additionalElementTypes.count > 0) {
        list = [list arrayByAddingObjectsFromArray:additionalElementTypes];
    }
    return [self elementInSpecificScopeWithTagNameInArray:tagNames elementTypes:list];
}

- (HTMLElementNode *)elementInSpecificScopeWithTagNameInArray:(NSArray *)tagNames
                                                 elementTypes:(NSArray *)elementTypes
{
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([tagNames containsObject:node.tagName]) return node;
        if ([elementTypes containsObject:node.tagName]) return nil;
    }
    return nil;
}

- (HTMLElementNode *)elementInTableScopeWithTagName:(NSString *)tagName
{
    return [self elementInTableScopeWithTagNameInArray:@[ tagName ]];
}

- (HTMLElementNode *)elementInTableScopeWithTagNameInArray:(NSArray *)tagNames
{
    return [self elementInSpecificScopeWithTagNameInArray:tagNames
                                             elementTypes:@[ @"html", @"table" ]];
}

- (HTMLElementNode *)elementInListItemScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]
                           additionalElementTypes:@[ @"ol", @"ul" ]];
}

- (void)closePElement
{
    [self generateImpliedEndTagsExceptForTagsNamed:@"p"];
    if ([[_stackOfOpenElements.lastObject tagName] isEqualToString:@"p"]) {
        [self addParseError];
    }
    while (![[_stackOfOpenElements.lastObject tagName] isEqualToString:@"p"]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
}

- (void)generateImpliedEndTagsExceptForTagsNamed:(NSString *)tagName
{
    NSArray *list = @[ @"dd", @"dt", @"li", @"option", @"optgroup", @"p", @"rp", @"rt" ];
    if (tagName) {
        list = [list filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", tagName]];
    }
    while ([list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [_stackOfOpenElements removeLastObject];
    }
}

- (void)generateImpliedEndTags
{
    [self generateImpliedEndTagsExceptForTagsNamed:nil];
}

// Returns NO if the parser should "act as described in the 'any other end tag' entry below".
- (BOOL)runAdoptionAgencyAlgorithmForTagName:(NSString *)tagName
{
    for (NSInteger outerLoopCounter = 0; outerLoopCounter < 8; outerLoopCounter++) {
        HTMLElementNode *formattingElement;
        for (HTMLElementNode *element in _activeFormattingElements.reverseObjectEnumerator) {
            if ([element isEqual:[HTMLMarker marker]]) break;
            if ([element.tagName isEqualToString:tagName]) {
                formattingElement = element;
                break;
            }
        }
        if (!formattingElement) return NO;
        if (![_stackOfOpenElements containsObject:formattingElement]) {
            [self addParseError];
            [self removeElementFromListOfActiveFormattingElements:formattingElement];
            return YES;
        }
        if (![self isElementInScope:formattingElement]) {
            [self addParseError];
            return YES;
        }
        if (![_stackOfOpenElements.lastObject isEqual:formattingElement]) {
            [self addParseError];
        }
        HTMLElementNode *furthestBlock;
        for (NSUInteger i = [_stackOfOpenElements indexOfObject:formattingElement] + 1;
             i < _stackOfOpenElements.count; i++)
        {
            if ([@[ @"address", @"applet", @"area", @"article", @"aside", @"base", @"basefont", @"bgsound",
                 @"blockquote", @"body", @"br", @"button", @"caption", @"center", @"col", @"colgroup", @"dd",
                 @"details", @"dir", @"div", @"dl", @"dt", @"embed", @"fieldset", @"figcaption", @"figure",
                 @"footer", @"form", @"frame", @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head",
                 @"header", @"hgroup", @"hr", @"html", @"iframe", @"img", @"input", @"isindex", @"li", @"link",
                 @"listing", @"main", @"marquee", @"menu", @"menuitem", @"meta", @"nav", @"noembed",
                 @"noframes", @"noscript", @"object", @"ol", @"p", @"param", @"plaintext", @"pre", @"script",
                 @"section", @"select", @"source", @"style", @"summary", @"table", @"tbody", @"td",
                 @"textarea", @"tfoot", @"th", @"thead", @"title", @"tr", @"track", @"ul", @"wbr", @"xmp" ]
                 containsObject:[_stackOfOpenElements[i] tagName]])
            {
                furthestBlock = _stackOfOpenElements[i];
                break;
            }
        }
        if (!furthestBlock) {
            while (![_stackOfOpenElements.lastObject isEqual:formattingElement]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            [self removeElementFromListOfActiveFormattingElements:formattingElement];
            return YES;
        }
        HTMLElementNode *commonAncestor = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:formattingElement] - 1];
        NSUInteger bookmark = [_activeFormattingElements indexOfObject:formattingElement];
        HTMLElementNode *node = furthestBlock, *lastNode = furthestBlock;
        NSUInteger nodeIndex = [_stackOfOpenElements indexOfObject:node];
        for (NSInteger innerLoopCounter = 0; innerLoopCounter < 3; innerLoopCounter++) {
            node = _stackOfOpenElements[--nodeIndex];
            if (![_activeFormattingElements containsObject:node]) {
                [_stackOfOpenElements removeObject:node];
                continue;
            }
            if ([node isEqual:formattingElement]) break;
            HTMLElementNode *clone = [node copy];
            [_activeFormattingElements replaceObjectAtIndex:[_activeFormattingElements indexOfObject:node]
                                                       withObject:clone];
            [_stackOfOpenElements replaceObjectAtIndex:[_stackOfOpenElements indexOfObject:node]
                                            withObject:clone];
            node = clone;
            if ([lastNode isEqual:furthestBlock]) {
                bookmark = [_activeFormattingElements indexOfObject:node] + 1;
            }
            [node appendChild:lastNode];
            lastNode = node;
        }
        [self insertNode:lastNode atAppropriatePlaceWithOverrideTarget:commonAncestor];
        HTMLElementNode *formattingClone = [formattingElement copy];
        for (id childNode in furthestBlock.childNodes) {
            [formattingClone appendChild:childNode];
        }
        [furthestBlock appendChild:formattingClone];
        if ([_activeFormattingElements indexOfObject:formattingElement] < bookmark) {
            bookmark--;
        }
        [self removeElementFromListOfActiveFormattingElements:formattingElement];
        [_activeFormattingElements insertObject:formattingClone atIndex:bookmark];
        [_stackOfOpenElements removeObject:formattingElement];
        [_stackOfOpenElements insertObject:formattingClone
                                   atIndex:[_stackOfOpenElements indexOfObject:furthestBlock] + 1];
    }
    return YES;
}

- (BOOL)isElementInScope:(HTMLElementNode *)element
{
    NSArray *list = @[ @"applet", @"caption", @"html", @"table", @"td", @"th", @"marquee", @"object" ];
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node isEqual:element]) return YES;
        if ([list containsObject:node.tagName]) return NO;
    }
    return NO;
}

- (void)insertNode:(HTMLNode *)node atAppropriatePlaceWithOverrideTarget:(HTMLNode *)overrideTarget
{
    NSUInteger i;
    HTMLNode *parent = [self appropriatePlaceForInsertingANodeWithOverrideTarget:overrideTarget index:&i];
    [parent insertChild:node atIndex:i];
}

- (void)clearActiveFormattingElementsUpToLastMarker
{
    while (![_activeFormattingElements.lastObject isEqual:[HTMLMarker marker]]) {
        [_activeFormattingElements removeLastObject];
    }
    [_activeFormattingElements removeLastObject];
}

- (void)followGenericRCDATAElementParsingAlgorithmForToken:(id)token
{
    [self followGenericParsingAlgorithmForToken:token withTokenizerState:HTMLRCDATATokenizerState];
}

- (void)followGenericRawTextElementParsingAlgorithmForToken:(id)token
{
    [self followGenericParsingAlgorithmForToken:token withTokenizerState:HTMLRAWTEXTTokenizerState];
}

- (void)followGenericParsingAlgorithmForToken:(id)token withTokenizerState:(HTMLTokenizerState)state
{
    [self insertElementForToken:token];
    _tokenizer.state = state;
    if (_originalInsertionMode == HTMLInvalidInsertionMode) {
        _originalInsertionMode = _insertionMode;
    }
    [self switchInsertionMode:HTMLTextInsertionMode];
}

- (void)clearStackBackToATableContext
{
    NSArray *list = @[ @"table", @"html" ];
    while (![list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [_stackOfOpenElements removeLastObject];
    }
}

- (void)resetInsertionModeAppropriately
{
    BOOL last = NO;
    HTMLElementNode *node = _stackOfOpenElements.lastObject;
    for (;;) {
        if ([_stackOfOpenElements[0] isEqual:node]) {
            last = YES;
            node = _context;
        }
        if ([node.tagName isEqualToString:@"select"]) {
            HTMLElementNode *ancestor = node;
            for (;;) {
                if ([_stackOfOpenElements[0] isEqual:ancestor]) break;
                ancestor = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:ancestor]- 1];
                if ([ancestor.tagName isEqualToString:@"table"]) {
                    [self switchInsertionMode:HTMLInSelectInTableInsertionMode];
                    return;
                }
            }
            [self switchInsertionMode:HTMLInSelectInsertionMode];
            return;
        }
        if (!last && [@[ @"td", @"th" ] containsObject:node.tagName]) {
            [self switchInsertionMode:HTMLInCellInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"tr"]) {
            [self switchInsertionMode:HTMLInRowInsertionMode];
            return;
        }
        if ([@[ @"tbody", @"thead", @"tfoot" ] containsObject:node.tagName]) {
            [self switchInsertionMode:HTMLInTableBodyInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"caption"]) {
            [self switchInsertionMode:HTMLInCaptionInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"colgroup"]) {
            [self switchInsertionMode:HTMLInCaptionInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"table"]) {
            [self switchInsertionMode:HTMLInTableInsertionMode];
            return;
        }
        if (!last && [node.tagName isEqualToString:@"head"]) {
            [self switchInsertionMode:HTMLInHeadInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"body"]) {
            [self switchInsertionMode:HTMLInBodyInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"frameset"]) {
            [self switchInsertionMode:HTMLInFramesetInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"html"]) {
            [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
            return;
        }
        if (last) {
            [self switchInsertionMode:HTMLInBodyInsertionMode];
            return;
        }
        node = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:node] - 1];
    }
}

- (void)clearStackBackToATableBodyContext
{
    NSArray *list = @[ @"tbody", @"tfoot", @"thead", @"html" ];
    while (![list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [_stackOfOpenElements removeLastObject];
    }
}

- (void)clearStackBackToATableRowContext
{
    NSArray *list = @[ @"tr", @"html" ];
    while (![list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [_stackOfOpenElements removeLastObject];
    }
}

- (void)closeTheCell
{
    [self generateImpliedEndTags];
    NSArray *list = @[ @"td", @"th" ];
    if (![list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [self addParseError];
    }
    while (![list containsObject:[_stackOfOpenElements.lastObject tagName]]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
    [self clearActiveFormattingElementsUpToLastMarker];
    [self switchInsertionMode:HTMLInRowInsertionMode];
}

- (HTMLElementNode *)selectElementInSelectScope
{
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node.tagName isEqualToString:@"select"]) return node;
        if (![@[ @"optgroup", @"option" ] containsObject:node.tagName]) return nil;
    }
    return nil;
}

- (void)addParseError
{
    [_errors addObject:[NSNull null]];
}

- (void)stopParsing
{
    [_stackOfOpenElements removeAllObjects];
    _done = YES;
}

@end

@implementation HTMLMarker

static HTMLMarker *instance = nil;

+ (void)initialize
{
    if (self == [HTMLMarker class]) {
        if (!instance) {
            instance = [self new];
        }
    }
}

+ (instancetype)marker
{
    return instance;
}

- (id)init
{
    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(__unused NSZone *)zone
{
    return self;
}

#pragma mark NSObject

- (BOOL)isEqual:(id)other
{
    return other == self;
}

- (NSUInteger)hash
{
    // Random constant.
    return 2358723968;
}

@end
