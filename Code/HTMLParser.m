//  HTMLParser.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLParser.h"
#import "HTMLMutability.h"
#import "HTMLString.h"
#import "HTMLTokenizer.h"

@interface HTMLMarker : NSObject <NSCopying>

+ (instancetype)marker;

@end

typedef NS_ENUM(NSInteger, HTMLInsertionMode)
{
    HTMLInvalidInsertionMode, // SPEC This faux insertion mode is just for us.
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
    HTMLForeignContentInsertionMode, // SPEC This faux insertion mode is just for us.
};

@interface HTMLParser ()

@property (readonly, strong, nonatomic) HTMLElementNode *currentNode;

@end

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
    BOOL _framesetOkFlag;
    BOOL _ignoreNextTokenIfLineFeed;
    NSMutableArray *_activeFormattingElements;
    NSMutableArray *_pendingTableCharacterTokens;
    BOOL _fosterParenting;
    BOOL _done;
    BOOL _fragmentParsingAlgorithm;
}

+ (HTMLDocument *)documentForString:(NSString *)string
{
	return [[self parserForString:string] document];
}

+ (instancetype)parserForString:(NSString *)string
{
	return [[self alloc] initWithString:string];
}

- (id)initWithString:(NSString *)string
{
    if (!(self = [self init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _tokenizer.parser = self;
    return self;
}

+ (instancetype)parserForString:(NSString *)string context:(HTMLElementNode *)context
{
	return [[self alloc] initWithString:string context:context];
}

- (id)initWithString:(NSString *)string context:(HTMLElementNode *)context
{
    if (!(self = [self init])) return nil;
    _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
    _tokenizer.parser = self;
    if ([@[ @"title", @"textarea" ] containsObject:context.tagName]) {
        _tokenizer.state = HTMLRCDATATokenizerState;
    } else if ([@[ @"style", @"xmp", @"iframe", @"noembed", @"noframes" ]
                containsObject:context.tagName])
    {
        _tokenizer.state = HTMLRAWTEXTTokenizerState;
    } else if ([context.tagName isEqualToString:@"script"]) {
        _tokenizer.state = HTMLScriptDataTokenizerState;
    } else if ([context.tagName isEqualToString:@"noscript"]) {
        _tokenizer.state = HTMLRAWTEXTTokenizerState;
    } else if ([context.tagName isEqualToString:@"plaintext"]) {
        _tokenizer.state = HTMLPLAINTEXTTokenizerState;
    }
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
    _framesetOkFlag = YES;
    _activeFormattingElements = [NSMutableArray new];
    return self;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    if (_fragmentParsingAlgorithm) {
        HTMLElementNode *root = [[HTMLElementNode alloc] initWithTagName:@"html"];
        [_document appendChild:root];
        [_stackOfOpenElements setArray:@[ root ]];
        [self resetInsertionModeAppropriately];
        HTMLNode *nearestForm = _context;
        while (nearestForm) {
            if ([nearestForm isKindOfClass:[HTMLElementNode class]] &&
                [((HTMLElementNode *)nearestForm).tagName isEqualToString:@"form"])
            {
                break;
            }
            nearestForm = nearestForm.parentNode;
        }
        _formElementPointer = (HTMLElementNode *)nearestForm;
    }
    for (id token in _tokenizer) {
        if (_done) break;
        [self processToken:token];
    }
    [self processToken:[HTMLEOFToken new]];
    if (_context) {
        HTMLNode *root = _document.childNodes[0];
        while (_document.childNodes.count > 0) {
            [_document removeChild:_document.childNodes[0]];
        }
        for (HTMLNode *child in root.childNodes) {
            [_document appendChild:child];
        }
    }
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

#pragma mark - The "initial" insertion mode

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
        [self addParseError:@"Invalid DOCTYPE"];
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
    [self addParseError:@"Expected DOCTYPE"];
    _document.quirksMode = HTMLQuirksMode;
    [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "before html" insertion mode

- (void)beforeHtmlInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE"];
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
        [self addParseError:@"Unexpected end tag named %@ before <html>", token.tagName];
    }
}

- (void)beforeHtmlInsertionModeHandleAnythingElse:(id)token
{
    HTMLElementNode *html = [[HTMLElementNode alloc] initWithTagName:@"html"];
    [_document appendChild:html];
    [_stackOfOpenElements addObject:html];
    [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
    [self reprocessToken:token];
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
    [self insertComment:token.data];
}

- (void)beforeHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE before <head>"];
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
        [self addParseError:@"Unexpected end tag named %@ before <head>", token.tagName];
    }
}

- (void)beforeHeadInsertionModeHandleAnythingElse:(id)token
{
    HTMLStartTagToken *fakeToken = [[HTMLStartTagToken alloc] initWithTagName:@"head"];
    _headElementPointer = [self insertElementForToken:fakeToken];
    [self switchInsertionMode:HTMLInHeadInsertionMode];
    [self reprocessToken:token];
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
    [self insertComment:token.data];
}

- (void)inHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <head>"];
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
    } else if ([token.tagName isEqualToString:@"head"]) {
        [self addParseError:@"<head> already started"];
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
        [self addParseError:@"Unexpected end tag named %@ in head", token.tagName];
    }
}

- (void)inHeadInsertionModeHandleAnythingElse:(id)token
{
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLAfterHeadInsertionMode];
    [self reprocessToken:token];
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
    [self insertComment:token.data];
}

- (void)afterHeadInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE after <head>"];
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
        [self addParseError:@"Misnested start tag named %@ after <head>", token.tagName];
        [_stackOfOpenElements addObject:_headElementPointer];
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
        [_stackOfOpenElements removeObject:_headElementPointer];
    } else if ([token.tagName isEqualToString:@"head"]) {
        [self addParseError:@"Start tag named head after <head>"];
    } else {
        [self afterHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)afterHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"body", @"html", @"br" ] containsObject:token.tagName]) {
        [self afterHeadInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError:@"Unexpected end tag named %@ after <head>", token.tagName];
    }
}

- (void)afterHeadInsertionModeHandleAnythingElse:(id)token
{
    [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"body"]];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "in body" insertion mode

- (void)inBodyInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError:@"Ignoring U+0000 NULL in <body>"];
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
    [self insertComment:token.data];
}

- (void)inBodyInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <body>"];
}

- (void)inBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self addParseError:@"Start tag named html in <body>"];
        HTMLElementNode *element = _stackOfOpenElements[0];
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
        [self addParseError:@"Start tag named body in <body>"];
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
        [self addParseError:@"Start tag named frameset in <body>"];
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
        if ([@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:self.currentNode.tagName])
        {
            [self addParseError:@"Nested header start tag %@ in <body>", token.tagName];
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
            [self addParseError:@"Start tag named form within a form in <body>"];
            return;
        }
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        HTMLElementNode *form = [self insertElementForToken:token];
        _formElementPointer = form;
    } else if ([token.tagName isEqualToString:@"li"]) {
        _framesetOkFlag = NO;
        HTMLElementNode *node = self.currentNode;
    loop:
        if ([node.tagName isEqualToString:@"li"]) {
            [self generateImpliedEndTagsExceptForTagsNamed:@"li"];
            if (![self.currentNode.tagName isEqualToString:@"li"]) {
                [self addParseError:@"Misnested li tag in <body>"];
            }
            while (![self.currentNode.tagName isEqualToString:@"li"]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            goto done;
        }
        if (IsSpecialElement(node) &&
            !(node.namespace == HTMLNamespaceHTML &&
              [@[ @"address", @"div", @"p" ] containsObject:node.tagName]))
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
                if (![self.currentNode.tagName isEqualToString:@"dd"]) {
                    [self addParseError:@"Misnested dd tag in <body>"];
                }
                while (![self.currentNode.tagName isEqualToString:@"dd"]) {
                    [_stackOfOpenElements removeLastObject];
                }
                [_stackOfOpenElements removeLastObject];
                break;
            } else if ([node.tagName isEqualToString:@"dt"]) {
                [self generateImpliedEndTagsExceptForTagsNamed:@"dt"];
                if (![self.currentNode.tagName isEqualToString:@"dt"]) {
                    [self addParseError:@"Misnested dt tag in <body>"];
                }
                while (![self.currentNode.tagName isEqualToString:@"dt"]) {
                    [_stackOfOpenElements removeLastObject];
                }
                [_stackOfOpenElements removeLastObject];
                break;
            } else if (IsSpecialElement(node) &&
                       !(node.namespace == HTMLNamespaceHTML &&
                         [@[ @"address", @"div", @"p" ] containsObject:node.tagName]))
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
            [self addParseError:@"Nested button tag in <body>"];
            [self generateImpliedEndTags];
            while (![self.currentNode.tagName isEqualToString:@"button"]) {
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
                [self addParseError:@"Nested start tag 'a' in <body>"];
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
            [self addParseError:@"Misnested nobr tag in <body>"];
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
        [self addParseError:@"It's spelled 'img' in <body>"];
        [self reprocessToken:[token copyWithTagName:@"img"]];
    } else if ([token.tagName isEqualToString:@"isindex"]) {
        [self addParseError:@"Don't use isindex in <body>"];
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
    } else if ([@[ @"noembed", @"noscript" ] containsObject:token.tagName]) {
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"select"]) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
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
        if ([self.currentNode.tagName isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
    } else if ([@[ @"rp", @"rt" ] containsObject:token.tagName]) {
        if ([self elementInScopeWithTagName:@"ruby"]) {
            [self generateImpliedEndTags];
            if (![self.currentNode.tagName isEqualToString:@"ruby"]) {
                [self addParseError:@"Start tag named %@ outside of ruby in <body>", token.tagName];
            }
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"math"]) {
        [self reconstructTheActiveFormattingElements];
        AdjustMathMLAttributesForToken(token);
        AdjustForeignAttributesForToken(token);
        // SPEC The spec says to insert a foreign element for this token, which would avoid foster
        //      parenting. That's not actually what's supposed to happen.
        HTMLElementNode *element = [self createElementForToken:token inNamespace:HTMLNamespaceMathML];
        [self insertElement:element];
        if (token.selfClosingFlag) {
            [_stackOfOpenElements removeLastObject];
        }
    } else if ([token.tagName isEqualToString:@"svg"]) {
        [self reconstructTheActiveFormattingElements];
        AdjustSVGAttributesForToken(token);
        AdjustForeignAttributesForToken(token);
        // SPEC The spec says to insert a foreign element for this token, which would avoid foster
        //      parenting. That's not actually what's supposed to happen.
        HTMLElementNode *element = [self createElementForToken:token inNamespace:HTMLNamespaceSVG];
        [self insertElement:element];
        if (token.selfClosingFlag) {
            [_stackOfOpenElements removeLastObject];
        }
    } else if ([@[ @"caption", @"col", @"colgroup", @"frame", @"head", @"tbody", @"td", @"tfoot",
                @"th", @"thead", @"tr" ] containsObject:token.tagName])
    {
        [self addParseError:@"Start tag named %@ ignored in <body>", token.tagName];
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
            [self addParseError:@"Unclosed %@ element in <body> at end of file", node.tagName];
            break;
        }
    }
    [self stopParsing];
}

- (void)inBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"body", @"html" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagName:@"body"]) {
            [self addParseError:@"End tag named %@ without body in scope in <body>", token.tagName];
            return;
        }
        for (HTMLElementNode *element in _stackOfOpenElements.reverseObjectEnumerator) {
            if (![@[ @"dd", @"dt", @"li", @"optgroup", @"option", @"p", @"rp", @"rt", @"tbody",
                  @"td", @"tfoot", @"th", @"thead", @"tr", @"body", @"html" ]
                  containsObject:element.tagName])
            {
                [self addParseError:@"Misplaced %@ element in <body>", element.tagName];
                break;
            }
        }
        [self switchInsertionMode:HTMLAfterBodyInsertionMode];
        if ([token.tagName isEqualToString:@"html"]) {
            [self reprocessToken:token];
        }
    } else if ([@[ @"address", @"article", @"aside", @"blockquote", @"button", @"center",
                @"details", @"dialog", @"dir", @"div", @"dl", @"fieldset", @"figcaption",
                @"figure", @"footer", @"header", @"hgroup", @"listing", @"main", @"menu", @"nav",
                @"ol", @"pre", @"section", @"summary", @"ul" ] containsObject:token.tagName])
    {
        if (![self elementInScopeWithTagName:token.tagName]) {
            [self addParseError:@"End tag '%@' for unmatched open tag in <body>", token.tagName];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in <body>", token.tagName];
        }
        while (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"form"]) {
        HTMLElementNode *node = _formElementPointer;
        _formElementPointer = nil;
        if (![self isElementInScope:node]) {
            [self addParseError:@"Closing misnested 'form' in <body>"];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode isEqual:node]) {
            [self addParseError:@"Misnested 'form' in <body>"];
        }
        [_stackOfOpenElements removeObject:node];
    } else if ([token.tagName isEqualToString:@"p"]) {
        if (![self elementInButtonScopeWithTagName:@"p"]) {
            [self addParseError:@"Not closing unknown 'p' element in <body>"];
            [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"p"]];
        }
        [self closePElement];
    } else if ([token.tagName isEqualToString:@"li"]) {
        if (![self elementInListItemScopeWithTagName:@"li"]) {
            [self addParseError:@"Not closing unknown 'li' element in <body>"];
            return;
        }
        [self generateImpliedEndTagsExceptForTagsNamed:@"li"];
        if (![self.currentNode.tagName isEqualToString:@"li"]) {
            [self addParseError:@"Misnested end tag 'li' in <body>"];
        }
        while (![self.currentNode.tagName isEqualToString:@"li"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([@[ @"dd", @"dt" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagName:token.tagName]) {
            [self addParseError:@"Not closing unknown '%@' element in <body>", token.tagName];
            return;
        }
        [self generateImpliedEndTagsExceptForTagsNamed:token.tagName];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in <body>", token.tagName];
        }
        while (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if ([@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ] containsObject:token.tagName]) {
        if (![self elementInScopeWithTagNameInArray:@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ]])
        {
            [self addParseError:@"Not closing unknown '%@' element in <body>", token.tagName];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in <body>", token.tagName];
        }
        while (![@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ]
                 containsObject:self.currentNode.tagName])
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
            [self addParseError:@"Not closing unknown '%@' element in <body>", token.tagName];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in <body>", token.tagName];
        }
        while (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self clearActiveFormattingElementsUpToLastMarker];
    } else if ([token.tagName isEqualToString:@"br"]) {
        [self addParseError:@"'br' element cannot have an end tag"];
        [self inBodyInsertionModeHandleStartTagToken:
         [[HTMLStartTagToken alloc] initWithTagName:@"br"]];
    } else {
        [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
    }
}

- (void)inBodyInsertionModeHandleAnyOtherEndTagToken:(id)token
{
    HTMLElementNode *node = self.currentNode;
    do {
        if ([node.tagName isEqualToString:[token tagName]]) {
            [self generateImpliedEndTagsExceptForTagsNamed:[token tagName]];
            if (![self.currentNode.tagName isEqualToString:[token tagName]])
            {
                [self addParseError:@"Misnested '%@' end tag in <body>", [token tagName]];
            }
            while (![self.currentNode isEqual:node]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            break;
        } else if (IsSpecialElement(node)) {
            [self addParseError:@"Ignoring end tag '%@' in <body>", [token tagName]];
            return;
        }
        node = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:node] - 1];
    } while (YES);
}

- (void)closePElement
{
    [self generateImpliedEndTagsExceptForTagsNamed:@"p"];
    if (![self.currentNode.tagName isEqualToString:@"p"]) {
        [self addParseError:@"Closing 'p' element that isn't current"];
    }
    while (![self.currentNode.tagName isEqualToString:@"p"]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
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
            [self addParseError:@"Adoption agency formatting element missing from stack"];
            [self removeElementFromListOfActiveFormattingElements:formattingElement];
            return YES;
        }
        if (![self isElementInScope:formattingElement]) {
            [self addParseError:@"Adoption agency formatting element missing from scope"];
            return YES;
        }
        if (![self.currentNode isEqual:formattingElement]) {
            [self addParseError:@"Adoption agency formatting element not current"];
        }
        HTMLElementNode *furthestBlock;
        for (NSUInteger i = [_stackOfOpenElements indexOfObject:formattingElement] + 1;
             i < _stackOfOpenElements.count; i++)
        {
            if (IsSpecialElement(_stackOfOpenElements[i])) {
                furthestBlock = _stackOfOpenElements[i];
                break;
            }
        }
        if (!furthestBlock) {
            while (![self.currentNode isEqual:formattingElement]) {
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

static BOOL IsSpecialElement(HTMLElementNode *element)
{
    if (element.namespace == HTMLNamespaceHTML) {
        return [@[ @"address", @"applet", @"area", @"article", @"aside", @"base", @"basefont",
                @"bgsound", @"blockquote", @"body", @"br", @"button", @"caption", @"center",
                @"col", @"colgroup", @"dd", @"details", @"dir", @"div", @"dl", @"dt", @"embed",
                @"fieldset", @"figcaption", @"figure", @"footer", @"form", @"frame", @"frameset",
                @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"header", @"hgroup", @"hr",
                @"html", @"iframe", @"img", @"input", @"isindex", @"li", @"link", @"listing",
                @"main", @"marquee", @"menu", @"menuitem", @"meta", @"nav", @"noembed",
                @"noframes", @"noscript", @"object", @"ol", @"p", @"param", @"plaintext", @"pre",
                @"script", @"section", @"select", @"source", @"style", @"summary", @"table",
                @"tbody", @"td", @"template", @"textarea", @"tfoot", @"th", @"thead", @"title",
                @"tr", @"track", @"ul", @"wbr", @"xmp" ] containsObject:element.tagName];
    } else if (element.namespace == HTMLNamespaceMathML) {
        return [@[ @"mi", @"mo", @"mn", @"ms", @"mtext", @"annotation-xml" ]
                containsObject:element.tagName];
    } else if (element.namespace == HTMLNamespaceSVG) {
        return [@[ @"foreignObject", @"desc", @"title" ] containsObject:element.tagName];
    } else {
        return NO;
    }
}

#pragma mark The "text" insertion mode

- (void)textInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    [self insertCharacter:token.data];
}

- (void)textInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self addParseError:@"Unexpected end of file in 'text' mode"];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:_originalInsertionMode];
    [self reprocessToken:token];
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
         containsObject:self.currentNode.tagName])
    {
        _pendingTableCharacterTokens = [NSMutableArray new];
        [self switchInsertionMode:HTMLInTableTextInsertionMode];
        [self reprocessToken:token];
    } else {
        [self inTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inTableInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <table>"];
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
        [self reprocessToken:token];
    } else if ([@[ @"tbody", @"tfoot", @"thead" ] containsObject:token.tagName]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if ([@[ @"td", @"th", @"tr" ] containsObject:token.tagName]) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"tbody"]];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        [self reprocessToken:token];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self addParseError:@"'table' start tag in <table>"];
        if (![self elementInTableScopeWithTagName:@"table"]) {
            return;
        }
        while (![self.currentNode.tagName isEqualToString:@"table"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocessToken:token];
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
        if (!type || [type.value caseInsensitiveCompare:@"hidden"] != NSOrderedSame) {
            [self inTableInsertionModeHandleAnythingElse:token];
            return;
        }
        [self addParseError:@"Non-hidden 'input' start tag in <table>"];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"form"]) {
        [self addParseError:@"'form' start tag in <table>"];
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
            [self addParseError:@"End tag 'table' for unknown table element in <table>"];
            return;
        }
        while (![self.currentNode.tagName isEqualToString:@"table"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html", @"tbody", @"td", @"tfoot",
                @"th", @"thead", @"tr" ] containsObject:token.tagName])
    {
        [self addParseError:@"End tag '%@' in <table>", token.tagName];
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
    [self addParseError:@"Foster parenting token in <table>"];
    _fosterParenting = YES;
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    _fosterParenting = NO;
}

- (void)clearStackBackToATableContext
{
    NSArray *list = @[ @"table", @"html" ];
    while (![list containsObject:self.currentNode.tagName]) {
        [_stackOfOpenElements removeLastObject];
    }
}

#pragma mark The "in table text" insertion mode

- (void)inTableTextInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError:@"Ignoring U+0000 NULL in <table> text"];
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
        for (HTMLCharacterToken *token in _pendingTableCharacterTokens) {
            [self inTableInsertionModeHandleAnythingElse:token];
        }
    } else {
        for (HTMLCharacterToken *token in _pendingTableCharacterTokens) {
            [self insertCharacter:token.data];
        }
    }
    [self switchInsertionMode:_originalInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "in caption" insertion mode

- (void)inCaptionInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"caption"]) {
        if (![self elementInTableScopeWithTagName:@"caption"]) {
            [self addParseError:@"End tag 'caption' for unknown caption element in <caption>"];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:@"caption"]) {
            [self addParseError:@"Misnested end tag 'caption' in <caption>"];
        }
        while (![self.currentNode.tagName isEqualToString:@"caption"]) {
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
        [self addParseError:@"End tag '%@' in <caption>", token.tagName];
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
    [self addParseError:@"%@ tag '%@' in <caption>",
     [token isKindOfClass:[HTMLStartTagToken class]] ? @"Start" : @"End", [token tagName]];
    if (![self elementInTableScopeWithTagName:@"caption"]) {
        return;
    }
    while (![self.currentNode.tagName isEqualToString:@"caption"]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
    [self clearActiveFormattingElementsUpToLastMarker];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocessToken:token];
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
    [self insertComment:token.data];
}

- (void)inColumnGroupInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <colgroup>"];
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
        if (![self.currentNode.tagName isEqualToString:@"colgroup"]) {
            [self addParseError:@"End tag 'colgroup' for unknown colgroup element in <colgroup>"];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([token.tagName isEqualToString:@"col"]) {
        [self addParseError:@"End tag 'col' in <colgroup>"];
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
    if (![self.currentNode.tagName isEqualToString:@"colgroup"]) {
        [self addParseError:@"Unexpected token in <colgroup>"];
        return;
    }
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "in table body" insertion mode

- (void)inTableBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"tr"]) {
        [self clearStackBackToATableBodyContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInRowInsertionMode];
    } else if ([@[ @"th", @"td" ] containsObject:token.tagName]) {
        [self addParseError:@"Start tag '%@' in <table> body", token.tagName];
        [self clearStackBackToATableBodyContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"tr"]];
        [self switchInsertionMode:HTMLInRowInsertionMode];
        [self reprocessToken:token];
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
            [self addParseError:@"End tag '%@' for unknown element in <table> body", token.tagName];
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
        [self addParseError:@"End tag '%@' in <table> body", token.tagName];
    } else {
        [self inTableBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableBodyInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:(id)token
{
    if (![self elementInTableScopeWithTagNameInArray:@[ @"tbody", @"thead", @"tfoot" ]]) {
        [self addParseError:@"%@ tag %@ outside 'tbody', 'thead', or 'tfoot' in <table> body",
         [token isKindOfClass:[HTMLStartTagToken class]] ? @"Start" : @"End", [token tagName]];
        return;
    }
    [self clearStackBackToATableBodyContext];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableInsertionMode];
    [self reprocessToken:token];
}

- (void)inTableBodyInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInTableInsertionMode];
}

- (void)clearStackBackToATableBodyContext
{
    NSArray *list = @[ @"tbody", @"tfoot", @"thead", @"html" ];
    while (![list containsObject:self.currentNode.tagName]) {
        [_stackOfOpenElements removeLastObject];
    }
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
            [self addParseError:@"End tag 'tr' for unknown element in <tr>"];
            return;
        }
        [self clearStackBackToATableRowContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        [self inRowInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:token];
    } else if ([@[ @"tbody", @"tfoot", @"thead" ] containsObject:token.tagName]) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError:@"End tag '%@' for unknown element in <tr>", token.tagName];
            return;
        }
        if (![self elementInTableScopeWithTagName:@"tr"]) {
            return;
        }
        [self clearStackBackToATableRowContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        [self reprocessToken:token];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html", @"td", @"th" ]
                containsObject:token.tagName])
    {
        [self addParseError:@"End tag '%@' in <tr>", token.tagName];
    } else {
        [self inRowInsertionModeHandleAnythingElse:token];
    }
}

- (void)inRowInsertionModeHandleTableCaptionStartTagOrTableEndTagToken:(id)token
{
    if (![self elementInTableScopeWithTagName:@"tr"]) {
        [self addParseError:@"%@ tag '%@' outside 'tr' element in <tr>",
         [token isKindOfClass:[HTMLStartTagToken class]] ? @"Start" : @"End", [token tagName]];
        return;
    }
    [self clearStackBackToATableRowContext];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    [self reprocessToken:token];
}

- (void)inRowInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInTableInsertionMode];
}

- (void)clearStackBackToATableRowContext
{
    NSArray *list = @[ @"tr", @"html" ];
    while (![list containsObject:self.currentNode.tagName]) {
        [_stackOfOpenElements removeLastObject];
    }
}

#pragma mark The "in cell" insertion mode

- (void)inCellInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"caption", @"col", @"colgroup", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr" ]
         containsObject:token.tagName])
    {
        if (![self elementInTableScopeWithTagNameInArray:@[ @"td", @"th" ]]) {
            [self addParseError:@"Start tag '%@' outside cell in cell", token.tagName];
            return;
        }
        [self closeTheCell];
        [self reprocessToken:token];
    } else {
        [self inCellInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCellInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"td", @"th" ] containsObject:token.tagName]) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError:@"End tag '%@' outside cell in cell", token.tagName];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in cell", token.tagName];
        }
        while (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self clearActiveFormattingElementsUpToLastMarker];
        [self switchInsertionMode:HTMLInRowInsertionMode];
    } else if ([@[ @"body", @"caption", @"col", @"colgroup", @"html" ]
                containsObject:token.tagName])
    {
        [self addParseError:@"End tag '%@' in cell", token.tagName];
    } else if ([@[ @"table", @"tbody", @"tfoot", @"thead", @"tr" ]
                containsObject:token.tagName])
    {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError:@"End tag '%@' for unknown element in cell", token.tagName];
            return;
        }
        [self closeTheCell];
        [self reprocessToken:token];
    } else {
        [self inCellInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCellInsertionModeHandleAnythingElse:(id)token
{
    [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
}

- (void)closeTheCell
{
    [self generateImpliedEndTags];
    NSArray *list = @[ @"td", @"th" ];
    if (![list containsObject:self.currentNode.tagName]) {
        [self addParseError:@"Closing misnested cell"];
    }
    while (![list containsObject:self.currentNode.tagName]) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
    [self clearActiveFormattingElementsUpToLastMarker];
    [self switchInsertionMode:HTMLInRowInsertionMode];
}

#pragma mark The "in select" insertion mode

- (void)inSelectInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError:@"Ignoring U+0000 NULL in <select>"];
    } else {
        [self insertCharacter:token.data];
    }
}

- (void)inSelectInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inSelectInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <select>"];
}

- (void)inSelectInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"option"]) {
        if ([self.currentNode.tagName isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"optgroup"]) {
        if ([self.currentNode.tagName isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        if ([self.currentNode.tagName isEqualToString:@"optgroup"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"select"]) {
        [self addParseError:@"Nested start tag 'select' in <select>"];
        while (![self.currentNode.tagName isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
    } else if ([@[ @"input", @"keygen", @"textarea" ] containsObject:token.tagName]) {
        [self addParseError:@"Start tag '%@' in <select>", token.tagName];
        if (![self selectElementInSelectScope]) {
            return;
        }
        while (![self.currentNode.tagName isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocessToken:token];
    } else if ([token.tagName isEqualToString:@"script"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self inSelectInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"optgroup"]) {
        HTMLElementNode *currentNode = self.currentNode;
        HTMLElementNode *beforeIt = _stackOfOpenElements[_stackOfOpenElements.count - 2];
        if ([currentNode.tagName isEqualToString:@"option"] &&
            [beforeIt.tagName isEqualToString:@"optgroup"])
        {
            [_stackOfOpenElements removeLastObject];
        }
        if ([self.currentNode.tagName isEqualToString:@"optgroup"]) {
            [_stackOfOpenElements removeLastObject];
        } else {
            [self addParseError:@"Misnested end tag 'optgroup' in <select>"];
            return;
        }
    } else if ([token.tagName isEqualToString:@"option"]) {
        if ([self.currentNode.tagName isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        } else {
            [self addParseError:@"Misnested end tag 'option' in <select>"];
            return;
        }
    } else if ([token.tagName isEqualToString:@"select"]) {
        if (![self selectElementInSelectScope]) {
            [self addParseError:@"End tag 'select' for unknown element in <select>"];
            return;
        }
        while (![self.currentNode.tagName isEqualToString:@"select"]) {
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
    [self addParseError:@"Unexpected token in <select>"];
}

#pragma mark The "in select in table" insertion mode

- (void)inSelectInTableInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th" ]
         containsObject:token.tagName])
    {
        [self addParseError:@"Start tag '%@' in <select> in <table>", token.tagName];
        while (![self.currentNode.tagName isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocessToken:token];
    } else {
        [self inSelectInTableInsertionModeHandleAnythingElse:token];
    }
}

- (void)inSelectInTableInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([@[ @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th" ]
         containsObject:token.tagName])
    {
        [self addParseError:@"End tag '%@' in <select> in <table>", token.tagName];
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            return;
        }
        while (![self.currentNode.tagName isEqualToString:@"select"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        [self resetInsertionModeAppropriately];
        [self reprocessToken:token];
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
    [self addParseError:@"Unexpected DOCTYPE after body"];
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
        if (_fragmentParsingAlgorithm) {
            [self addParseError:@"End tag 'html' parsing fragment after body"];
            return;
        }
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
    [self addParseError:@"Unexpected token after body"];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocessToken:token];
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
    [self insertComment:token.data];
}

- (void)inFramesetInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <frameset>"];
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
            [self.currentNode.tagName isEqualToString:@"html"])
        {
            [self addParseError:@"Misnested end tag 'frameset' in <frameset>"];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        if (!_fragmentParsingAlgorithm && ![self.currentNode.tagName isEqualToString:@"frameset"]) {
            [self switchInsertionMode:HTMLAfterFramesetInsertionMode];
        }
    } else {
        [self inFramesetInsertionModeHandleAnythingElse:token];
    }
}

- (void)inFramesetInsertionModeHandleEOFToken:(__unused HTMLEOFToken *)token
{
    if (!([self.currentNode.tagName isEqualToString:@"html"] &&
        _stackOfOpenElements.count == 1))
    {
        [self addParseError:@"Unexpected EOF in <frameset>"];
    }
    [self stopParsing];
}

- (void)inFramesetInsertionModeHandleAnythingElse:(__unused id)token
{
    [self addParseError:@"Unexpected token in <frameset>"];
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
    [self insertComment:token.data];
}

- (void)afterFramesetInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE after <frameset>"];
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
    [self addParseError:@"Unexpected token after <frameset>"];
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
    [self addParseError:@"Unexpected token after after <body>"];
    [self switchInsertionMode:HTMLInBodyInsertionMode];
    [self reprocessToken:token];
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
    [self addParseError:@"Unexpected token after after <frameset>"];
}

#pragma mark Rules for parsing tokens in foreign content

- (void)foreignContentInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (token.data == '\0') {
        [self addParseError:@"U+0000 NULL character in foreign content"];
        [self insertCharacter:0xFFFD];
    } else {
        [self insertCharacter:token.data];
        if (!IsSpaceCharacterToken(token)) {
            _framesetOkFlag = NO;
        }
    }
}

- (void)foreignContentInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)foreignContentInsertionModeHandleDOCTYPEToken:(__unused HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in foreign content"];
}

- (void)foreignContentInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([@[ @"b", @"big", @"blockquote", @"body", @"br", @"center", @"code", @"dd", @"div", @"dl",
         @"dt", @"em", @"embed", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"hr", @"i",
         @"img", @"li", @"listing", @"menu", @"meta", @"nobr", @"ol", @"p", @"pre", @"ruby", @"s",
         @"small", @"span", @"strong", @"strike", @"sub", @"sup", @"table", @"tt", @"u", @"ul",
         @"var" ] containsObject:token.tagName] ||
        ([token.tagName isEqualToString:@"font"] &&
         [@[ @"color", @"face", @"size" ]
          firstObjectCommonWithArray:[token.attributes valueForKey:@"name"]]))
    {
        [self addParseError:@"Unexpected HTML start tag token in foreign content"];
        if (_fragmentParsingAlgorithm) {
            [self foreignContentInsertionModeHandleAnyOtherStartTagToken:token];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        while (!(self.currentNode.namespace == HTMLNamespaceHTML ||
                 IsMathMLTextIntegrationPoint(self.currentNode) ||
                 IsHTMLIntegrationPoint(self.currentNode)))
        {
            [_stackOfOpenElements removeLastObject];
        }
        [self reprocessToken:token];
    } else {
        [self foreignContentInsertionModeHandleAnyOtherStartTagToken:token];
    }
}

- (void)foreignContentInsertionModeHandleAnyOtherStartTagToken:(HTMLStartTagToken *)token
{
    if (self.adjustedCurrentNode.namespace == HTMLNamespaceMathML) {
        AdjustMathMLAttributesForToken(token);
    } else if (self.adjustedCurrentNode.namespace == HTMLNamespaceSVG) {
        FixSVGTagNameCaseForToken(token);
        AdjustSVGAttributesForToken(token);
    }
    AdjustForeignAttributesForToken(token);
    [self insertForeignElementForToken:token inNamespace:self.adjustedCurrentNode.namespace];
    if (token.selfClosingFlag) {
        [_stackOfOpenElements removeLastObject];
    }
}

static void AdjustMathMLAttributesForToken(HTMLStartTagToken *token)
{
    NSUInteger i = [[token.attributes valueForKey:@"name"] indexOfObject:@"definitionurl"];
    if (i == NSNotFound) return;
    HTMLAttribute *old = token.attributes[i];
    HTMLAttribute *new = [[HTMLAttribute alloc] initWithName:@"definitionURL" value:old.value];
    [token replaceAttribute:old withAttribute:new];
}

static void FixSVGTagNameCaseForToken(HTMLStartTagToken *token)
{
    NSDictionary *names = @{
        @"altglyph": @"altGlyph",
        @"altglyphdef": @"altGlyphDef",
        @"altglyphitem": @"altGlyphItem",
        @"animatecolor": @"animateColor",
        @"animatemotion": @"animateMotion",
        @"animatetransform": @"animateTransform",
        @"clippath": @"clipPath",
        @"feblend": @"feBlend",
        @"fecolormatrix": @"feColorMatrix",
        @"fecomponenttransfer": @"feComponentTransfer",
        @"fecomposite": @"feComposite",
        @"feconvolvematrix": @"feConvolveMatrix",
        @"fediffuselighting": @"feDiffuseLighting",
        @"fedisplacementmap": @"feDisplacementMap",
        @"fedistantlight": @"feDistantLight",
        @"feflood": @"feFlood",
        @"fefunca": @"feFuncA",
        @"fefuncb": @"feFuncB",
        @"fefuncg": @"feFuncG",
        @"fefuncr": @"feFuncR",
        @"fegaussianblur": @"feGaussianBlur",
        @"feimage": @"feImage",
        @"femerge": @"feMerge",
        @"femergenode": @"feMergeNode",
        @"femorphology": @"feMorphology",
        @"feoffset": @"feOffset",
        @"fepointlight": @"fePointLight",
        @"fespecularlighting": @"feSpecularLighting",
        @"fespotlight": @"feSpotLight",
        @"fetile": @"feTile",
        @"feturbulence": @"feTurbulence",
        @"foreignobject": @"foreignObject",
        @"glyphref": @"glyphRef",
        @"lineargradient": @"linearGradient",
        @"radialgradient": @"radialGradient",
        @"textpath": @"textPath",
    };
    NSString *replacement = names[token.tagName];
    if (replacement) token.tagName = replacement;
}

static void AdjustSVGAttributesForToken(HTMLStartTagToken *token)
{
    NSDictionary *names = @{
        @"attributename": @"attributeName",
        @"attributetype": @"attributeType",
        @"basefrequency": @"baseFrequency",
        @"baseprofile": @"baseProfile",
        @"calcmode": @"calcMode",
        @"clippathunits": @"clipPathUnits",
        @"contentscripttype": @"contentScriptType",
        @"contentstyletype": @"contentStyleType",
        @"diffuseconstant": @"diffuseConstant",
        @"edgemode": @"edgeMode",
        @"externalresourcesrequired": @"externalResourcesRequired",
        @"filterres": @"filterRes",
        @"filterunits": @"filterUnits",
        @"glyphref": @"glyphRef",
        @"gradienttransform": @"gradientTransform",
        @"gradientunits": @"gradientUnits",
        @"kernelmatrix": @"kernelMatrix",
        @"kernelunitlength": @"kernelUnitLength",
        @"keypoints": @"keyPoints",
        @"keysplines": @"keySplines",
        @"keytimes": @"keyTimes",
        @"lengthadjust": @"lengthAdjust",
        @"limitingconeangle": @"limitingConeAngle",
        @"markerheight": @"markerHeight",
        @"markerunits": @"markerUnits",
        @"markerwidth": @"markerWidth",
        @"maskcontentunits": @"maskContentUnits",
        @"maskunits": @"maskUnits",
        @"numoctaves": @"numOctaves",
        @"pathlength": @"pathLength",
        @"patterncontentunits": @"patternContentUnits",
        @"patterntransform": @"patternTransform",
        @"patternunits": @"patternUnits",
        @"pointsatx": @"pointsAtX",
        @"pointsaty": @"pointsAtY",
        @"pointsatz": @"pointsAtZ",
        @"preservealpha": @"preserveAlpha",
        @"preserveaspectratio": @"preserveAspectRatio",
        @"primitiveunits": @"primitiveUnits",
        @"refx": @"refX",
        @"refy": @"refY",
        @"repeatcount": @"repeatCount",
        @"repeatdur": @"repeatDur",
        @"requiredextensions": @"requiredExtensions",
        @"requiredfeatures": @"requiredFeatures",
        @"specularconstant": @"specularConstant",
        @"specularexponent": @"specularExponent",
        @"spreadmethod": @"spreadMethod",
        @"startoffset": @"startOffset",
        @"stddeviation": @"stdDeviation",
        @"stitchtiles": @"stitchTiles",
        @"surfacescale": @"surfaceScale",
        @"systemlanguage": @"systemLanguage",
        @"tablevalues": @"tableValues",
        @"targetx": @"targetX",
        @"targety": @"targetY",
        @"textlength": @"textLength",
        @"viewbox": @"viewBox",
        @"viewtarget": @"viewTarget",
        @"xchannelselector": @"xChannelSelector",
        @"ychannelselector": @"yChannelSelector",
        @"zoomandpan": @"zoomAndPan",
    };
    NSMutableArray *newAttributes = [NSMutableArray new];
    for (HTMLAttribute *attribute in token.attributes) {
        NSString *replacement = names[attribute.name];
        if (replacement) {
            [newAttributes addObject:[[HTMLAttribute alloc] initWithName:replacement
                                                                   value:attribute.value]];
        } else {
            [newAttributes addObject:attribute];
        }
    }
    token.attributes = newAttributes;
}

static void AdjustForeignAttributesForToken(HTMLStartTagToken *token)
{
    NSMutableArray *newAttributes = [NSMutableArray new];
    NSArray *toAdjust = @[ @"xlink:actuate", @"xlink:arcrole", @"xlink:href", @"xlink:role",
                           @"xlink:show", @"xlink:title", @"xlink:type", @"xml:base", @"xml:lang",
                           @"xml:space", @"xmlns:xlink" ];
    for (HTMLAttribute *attribute in token.attributes) {
        if ([toAdjust containsObject:attribute.name]) {
            NSArray *parts = [attribute.name componentsSeparatedByString:@":"];
            HTMLAttribute *new = [[HTMLNamespacedAttribute alloc] initWithPrefix:parts[0]
                                                                            name:parts[1]
                                                                           value:attribute.value];
            [newAttributes addObject:new];
        } else {
            [newAttributes addObject:attribute];
        }
    }
    token.attributes = newAttributes;
}

- (void)foreignContentInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    HTMLElementNode *node = self.currentNode;
    if (![node.tagName.lowercaseString isEqualToString:token.tagName]) {
        [self addParseError:@"Misnested end tag '%@' in foreign content", token.tagName];
    }
    for (;;) {
        NSUInteger nodeIndex = [_stackOfOpenElements indexOfObject:node];
        if (nodeIndex == 0) return;
        if ([node.tagName.lowercaseString isEqualToString:token.tagName]) {
            while (![self.currentNode isEqual:node]) {
                [_stackOfOpenElements removeLastObject];
            }
            [_stackOfOpenElements removeLastObject];
            return;
        }
        node = _stackOfOpenElements[nodeIndex - 1];
        if (node.namespace == HTMLNamespaceHTML) break;
    }
    [self processToken:token usingRulesForInsertionMode:_insertionMode];
}

#pragma mark - Process tokens

- (void)processToken:(id)token
{
    if (^(HTMLElementNode *node){
        if (!node) return YES;
        if (node.namespace == HTMLNamespaceHTML) return YES;
        if (IsMathMLTextIntegrationPoint(node)) {
            if ([token isKindOfClass:[HTMLStartTagToken class]] &&
                ![@[ @"mglyph", @"malignmark" ] containsObject:[token tagName]])
            {
                return YES;
            }
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return YES;
            }
        }
        if (node.namespace == HTMLNamespaceMathML &&
            [node.tagName isEqualToString:@"annotation-xml"] &&
            [token isKindOfClass:[HTMLStartTagToken class]] &&
            [[token tagName] isEqualToString:@"svg"])
        {
            return YES;
        }
        if (IsHTMLIntegrationPoint(node)) {
            if ([token isKindOfClass:[HTMLStartTagToken class]] ||
                [token isKindOfClass:[HTMLCharacterToken class]])
            {
                return YES;
            }
        }
        return [token isKindOfClass:[HTMLEOFToken class]];
    }(self.adjustedCurrentNode)) {
        [self processToken:token usingRulesForInsertionMode:_insertionMode];
    } else {
        [self processToken:token usingRulesForInsertionMode:HTMLForeignContentInsertionMode];
    }
}

static BOOL IsMathMLTextIntegrationPoint(HTMLElementNode *node)
{
    if (node.namespace != HTMLNamespaceMathML) return NO;
    return [@[ @"mi", @"mo", @"mn", @"ms", @"mtext" ] containsObject:node.tagName];
}

static BOOL IsHTMLIntegrationPoint(HTMLElementNode *node)
{
    if (node.namespace == HTMLNamespaceMathML && [node.tagName isEqualToString:@"annotation-xml"]) {
        // SPEC We're told that "an annotation-xml element in the MathML namespace whose *start tag
        //      token* had an attribute with the name 'encoding'..." (emphasis mine) is an HTML
        //      integration point. Here we're examining the element node's attributes instead. This
        //      seems like a distinction without a difference.
        for (HTMLAttribute *attribute in node.attributes) {
            if ([attribute.name isEqualToString:@"encoding"]) {
                if ([attribute.value caseInsensitiveCompare:@"text/html"] == NSOrderedSame) {
                    return YES;
                } else if ([attribute.value caseInsensitiveCompare:@"application/xhtml+xml"] ==
                           NSOrderedSame)
                {
                    return YES;
                }
            }
        }
    } else if (node.namespace == HTMLNamespaceSVG) {
        return [@[ @"foreignObject", @"desc", @"title"] containsObject:node.tagName];
    }
    return NO;
}

- (void)processToken:(id)token usingRulesForInsertionMode:(HTMLInsertionMode)insertionMode
{
    if ([token isKindOfClass:[HTMLParseErrorToken class]]) {
        [self addParseError:@"Tokenizer: %@", [token error]];
        return;
    }
    if (_ignoreNextTokenIfLineFeed) {
        _ignoreNextTokenIfLineFeed = NO;
        if ([token isKindOfClass:[HTMLCharacterToken class]] &&
            [(HTMLCharacterToken *)token data] == '\n')
        {
            return;
        }
    }
    switch (insertionMode) {
        case HTMLInitialInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self initialInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self initialInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self initialInsertionModeHandleDOCTYPEToken:token];
            } else {
                return [self initialInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLBeforeHtmlInsertionMode:
            if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self beforeHtmlInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self beforeHtmlInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self beforeHtmlInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self beforeHtmlInsertionModeHandleStartTagToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self beforeHtmlInsertionModeHandleEndTagToken:token];
            } else {
                return [self beforeHtmlInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLBeforeHeadInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self beforeHeadInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self beforeHeadInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self beforeHeadInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self beforeHeadInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self beforeHeadInsertionModeHandleStartTagToken:token];
            } else {
                return [self beforeHeadInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInHeadInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inHeadInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inHeadInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inHeadInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inHeadInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inHeadInsertionModeHandleStartTagToken:token];
            } else {
                return [self inHeadInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLAfterHeadInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self afterHeadInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self afterHeadInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self afterHeadInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self afterHeadInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self afterHeadInsertionModeHandleStartTagToken:token];
            } else {
                return [self afterHeadInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInBodyInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inBodyInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inBodyInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inBodyInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inBodyInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self inBodyInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inBodyInsertionModeHandleStartTagToken:token];
            }
            // fall through
            
        case HTMLTextInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self textInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self textInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self textInsertionModeHandleEOFToken:token];
            }
            // fall through
            
        case HTMLInTableInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inTableInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inTableInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inTableInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inTableInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self inTableInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inTableInsertionModeHandleStartTagToken:token];
            } else {
                return [self inTableInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInTableTextInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inTableTextInsertionModeHandleCharacterToken:token];
            } else {
                return [self inTableTextInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInCaptionInsertionMode:
            if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inCaptionInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inCaptionInsertionModeHandleStartTagToken:token];
            } else {
                return [self inCaptionInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInColumnGroupInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inColumnGroupInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inColumnGroupInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inColumnGroupInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inColumnGroupInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self inColumnGroupInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inColumnGroupInsertionModeHandleStartTagToken:token];
            } else {
                return [self inColumnGroupInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInTableBodyInsertionMode:
            if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inTableBodyInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inTableBodyInsertionModeHandleStartTagToken:token];
            } else {
                return [self inTableBodyInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInRowInsertionMode:
            if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inRowInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inRowInsertionModeHandleStartTagToken:token];
            } else {
                return [self inRowInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInCellInsertionMode:
            if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inCellInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inCellInsertionModeHandleStartTagToken:token];
            } else {
                return [self inCellInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInSelectInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inSelectInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inSelectInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inSelectInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inSelectInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self inSelectInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inSelectInsertionModeHandleStartTagToken:token];
            } else {
                return [self inSelectInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInSelectInTableInsertionMode:
            if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inSelectInTableInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inSelectInTableInsertionModeHandleStartTagToken:token];
            } else {
                return [self inSelectInTableInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLAfterBodyInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self afterBodyInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self afterBodyInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self afterBodyInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self afterBodyInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self afterBodyInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self afterBodyInsertionModeHandleStartTagToken:token];
            } else {
                return [self afterBodyInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLInFramesetInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self inFramesetInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self inFramesetInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self inFramesetInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self inFramesetInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self inFramesetInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self inFramesetInsertionModeHandleStartTagToken:token];
            } else {
                return [self inFramesetInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLAfterFramesetInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self afterFramesetInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self afterFramesetInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self afterFramesetInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self afterFramesetInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self afterFramesetInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self afterFramesetInsertionModeHandleStartTagToken:token];
            } else {
                return [self afterFramesetInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLAfterAfterBodyInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self afterAfterBodyInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self afterAfterBodyInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self afterAfterBodyInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self afterAfterBodyInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self afterAfterBodyInsertionModeHandleStartTagToken:token];
            } else {
                return [self afterAfterBodyInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLAfterAfterFramesetInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self afterAfterFramesetInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self afterAfterFramesetInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self afterAfterFramesetInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self afterAfterFramesetInsertionModeHandleEOFToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self afterAfterFramesetInsertionModeHandleStartTagToken:token];
            } else {
                return [self afterAfterFramesetInsertionModeHandleAnythingElse:token];
            }
            
        case HTMLForeignContentInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self foreignContentInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLCommentToken class]]) {
                return [self foreignContentInsertionModeHandleCommentToken:token];
            } else if ([token isKindOfClass:[HTMLDOCTYPEToken class]]) {
                return [self foreignContentInsertionModeHandleDOCTYPEToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self foreignContentInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLStartTagToken class]]) {
                return [self foreignContentInsertionModeHandleStartTagToken:token];
            }
            // fall through
            
        default:
            NSAssert(NO, @"cannot handle %@ token in insertion mode %zd", [token class], insertionMode);
            break;
    }
}

- (void)reprocessToken:(id)token
{
    [self processToken:token];
}

- (void)stopParsing
{
    [_stackOfOpenElements removeAllObjects];
    _done = YES;
}

#pragma mark Stack of open elements

- (HTMLElementNode *)currentNode
{
    return _stackOfOpenElements.lastObject;
}

- (HTMLElementNode *)adjustedCurrentNode
{
    if (_fragmentParsingAlgorithm && _stackOfOpenElements.count == 1) {
        return _context;
    } else {
        return self.currentNode;
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
    NSDictionary *elementTypes = ElementTypesForSpecificScope(additionalElementTypes);
    return [self elementInSpecificScopeWithTagNameInArray:tagNames elementTypes:elementTypes];
}

static inline NSDictionary * ElementTypesForSpecificScope(NSArray *additionalHTMLElements)
{
    if (!additionalHTMLElements) additionalHTMLElements = @[];
    NSArray *html = [@[ @"applet", @"caption", @"html", @"table", @"td", @"th",
                     @"marquee", @"object" ] arrayByAddingObjectsFromArray:additionalHTMLElements];
    return @{
        @(HTMLNamespaceHTML): html,
        @(HTMLNamespaceMathML): @[ @"mi", @"mo", @"mn", @"ms", @"mtext", @"annotation-xml" ],
        @(HTMLNamespaceSVG): @[ @"foreignObject", @"desc", @"title" ],
    };
}

- (HTMLElementNode *)elementInSpecificScopeWithTagNameInArray:(NSArray *)tagNames
                                                 elementTypes:(NSDictionary *)elementTypes
{
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([tagNames containsObject:node.tagName]) return node;
        if ([elementTypes[@(node.namespace)] containsObject:node.tagName]) return nil;
    }
    return nil;
}

- (HTMLElementNode *)elementInTableScopeWithTagName:(NSString *)tagName
{
    return [self elementInTableScopeWithTagNameInArray:@[ tagName ]];
}

- (HTMLElementNode *)elementInTableScopeWithTagNameInArray:(NSArray *)tagNames
{
    NSDictionary *elementTypes = @{ @(HTMLNamespaceHTML): @[ @"html", @"table" ] };
    return [self elementInSpecificScopeWithTagNameInArray:tagNames elementTypes:elementTypes];
}

- (HTMLElementNode *)elementInListItemScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]
                           additionalElementTypes:@[ @"ol", @"ul" ]];
}

- (HTMLElementNode *)selectElementInSelectScope
{
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node.tagName isEqualToString:@"select"]) return node;
        if (!(node.namespace == HTMLNamespaceHTML &&
            [@[ @"optgroup", @"option" ] containsObject:node.tagName]))
        {
            return nil;
        }
    }
    return nil;
}

- (BOOL)isElementInScope:(HTMLElementNode *)element
{
    NSDictionary *elementTypes = ElementTypesForSpecificScope(nil);
    for (HTMLElementNode *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node isEqual:element]) return YES;
        if ([elementTypes[@(node.namespace)] containsObject:node.tagName]) return NO;
    }
    return NO;
}

#pragma mark Insert nodes

- (void)insertComment:(NSString *)data
{
    [self insertComment:data inNode:nil];
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

- (HTMLNode *)appropriatePlaceForInsertingANodeWithOverrideTarget:(HTMLElementNode *)overrideTarget
                                                            index:(out NSUInteger *)index
{
    HTMLElementNode *target = overrideTarget ?: self.currentNode;
    if (_fosterParenting &&
        [@[ @"table", @"tbody", @"tfoot", @"thead", @"tr" ] containsObject:target.tagName])
    {
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
        NSUInteger indexOfLastTable = [_stackOfOpenElements indexOfObject:lastTable];
        HTMLElementNode *previousNode = _stackOfOpenElements[indexOfLastTable - 1];
        *index = previousNode.childNodes.count;
        return previousNode;
    } else {
        *index = target.childNodes.count;
        return target;
    }
}

- (void)switchInsertionMode:(HTMLInsertionMode)insertionMode
{
    if (insertionMode == HTMLTextInsertionMode || insertionMode == HTMLInTableTextInsertionMode) {
        _originalInsertionMode = _insertionMode;
    }
    _insertionMode = insertionMode;
}

- (HTMLElementNode *)createElementForToken:(id)token
{
    return [self createElementForToken:token inNamespace:HTMLNamespaceHTML];
}

- (HTMLElementNode *)createElementForToken:(id)token inNamespace:(HTMLNamespace)namespace
{
    HTMLElementNode *element = [[HTMLElementNode alloc] initWithTagName:[token tagName]];
    element.namespace = namespace;
    for (HTMLAttribute *attribute in [token attributes]) {
        [element addAttribute:attribute];
    }
    return element;
}

- (HTMLElementNode *)insertElementForToken:(id)token
{
    HTMLElementNode *element = [self createElementForToken:token];
    [self insertElement:element];
    return element;
}

- (void)insertElement:(HTMLElementNode *)element
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    [adjustedInsertionLocation insertChild:element atIndex:index];
    [_stackOfOpenElements addObject:element];
}

- (void)insertCharacter:(UTF32Char)character
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    if ([adjustedInsertionLocation isKindOfClass:[HTMLDocument class]]) return;
    HTMLTextNode *textNode;
    if (index > 0 &&
        [adjustedInsertionLocation.childNodes[index - 1] isKindOfClass:[HTMLTextNode class]])
    {
        textNode = adjustedInsertionLocation.childNodes[index - 1];
    } else {
        textNode = [HTMLTextNode new];
        [adjustedInsertionLocation insertChild:textNode atIndex:index];
    }
    [textNode appendLongCharacter:character];
}

- (void)insertNode:(HTMLNode *)node atAppropriatePlaceWithOverrideTarget:(HTMLElementNode *)overrideTarget
{
    NSUInteger i;
    HTMLNode *parent = [self appropriatePlaceForInsertingANodeWithOverrideTarget:overrideTarget
                                                                           index:&i];
    [parent insertChild:node atIndex:i];
}

- (void)insertForeignElementForToken:(id)token inNamespace:(HTMLNamespace)namespace
{
    HTMLElementNode *element = [self createElementForToken:token inNamespace:namespace];
    [self.currentNode appendChild:element];
    [_stackOfOpenElements addObject:element];
}

- (void)resetInsertionModeAppropriately
{
    BOOL last = NO;
    HTMLElementNode *node = self.currentNode;
    for (;;) {
        if ([_stackOfOpenElements[0] isEqual:node]) {
            last = YES;
            node = _context;
        }
        if ([node.tagName isEqualToString:@"select"]) {
            HTMLElementNode *ancestor = node;
            for (;;) {
                if (last) break;
                if ([_stackOfOpenElements[0] isEqual:ancestor]) break;
                ancestor = _stackOfOpenElements[[_stackOfOpenElements indexOfObject:ancestor] - 1];
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
            [self switchInsertionMode:HTMLInColumnGroupInsertionMode];
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

#pragma mark List of active formatting elements

- (void)pushElementOnToListOfActiveFormattingElements:(HTMLElementNode *)element
{
    NSInteger alreadyPresent = 0;
    NSArray *descriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    NSArray *sortedElementAttributes = [element.attributes sortedArrayUsingDescriptors:descriptors];
    for (HTMLElementNode *node in _activeFormattingElements.reverseObjectEnumerator.allObjects) {
        if ([node isEqual:[HTMLMarker marker]]) break;
        if (![node.tagName isEqualToString:element.tagName]) continue;
        NSArray *sortedNodeAttributes = [node.attributes sortedArrayUsingDescriptors:descriptors];
        if (![sortedElementAttributes isEqualToArray:sortedNodeAttributes]) continue;
        alreadyPresent += 1;
        if (alreadyPresent == 3) {
            [_activeFormattingElements removeObject:node];
            break;
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

- (void)clearActiveFormattingElementsUpToLastMarker
{
    while (![_activeFormattingElements.lastObject isEqual:[HTMLMarker marker]]) {
        [_activeFormattingElements removeLastObject];
    }
    [_activeFormattingElements removeLastObject];
}

#pragma mark Generate implied end tags

- (void)generateImpliedEndTagsExceptForTagsNamed:(NSString *)tagName
{
    NSArray *list = @[ @"dd", @"dt", @"li", @"option", @"optgroup", @"p", @"rp", @"rt" ];
    if (tagName) {
        list = [list filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self != %@", tagName]];
    }
    while ([list containsObject:self.currentNode.tagName]) {
        [_stackOfOpenElements removeLastObject];
    }
}

- (void)generateImpliedEndTags
{
    [self generateImpliedEndTagsExceptForTagsNamed:nil];
}

#pragma mark Generic element parsing algorithms

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
    [self switchInsertionMode:HTMLTextInsertionMode];
}

#pragma mark Parse errors

- (void)addParseError:(NSString *)errorString, ... NS_FORMAT_FUNCTION(1, 2)
{
    va_list args;
    va_start(args, errorString);
    [_errors addObject:[[NSString alloc] initWithFormat:errorString arguments:args]];
    va_end(args);
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
