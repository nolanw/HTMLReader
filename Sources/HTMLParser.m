//  HTMLParser.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLParser.h"
#import "HTMLComment.h"
#import "HTMLDocument+Private.h"
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

@property (readonly, strong, nonatomic) HTMLElement *currentNode;

@end

@implementation HTMLParser
{
    HTMLTokenizer *_tokenizer;
    HTMLInsertionMode _insertionMode;
    HTMLInsertionMode _originalInsertionMode;
    HTMLElement *_context;
    NSMutableArray *_stackOfOpenElements;
    HTMLElement *_headElementPointer;
    HTMLElement *_formElementPointer;
    HTMLDocument *_document;
    NSMutableArray *_errors;
    BOOL _framesetOkFlag;
    BOOL _ignoreNextTokenIfLineFeed;
    NSMutableArray *_activeFormattingElements;
    NSMutableString *_pendingTableCharacters;
    BOOL _fosterParenting;
    BOOL _done;
    BOOL _fragmentParsingAlgorithm;
}

- (instancetype)initWithString:(NSString *)string encoding:(HTMLStringEncoding)encoding context:(HTMLElement *)context
{
    if ((self = [super init])) {
        _tokenizer = [[HTMLTokenizer alloc] initWithString:string];
        _tokenizer.parser = self;
        _encoding = encoding;
        _context = context;
        _insertionMode = HTMLInitialInsertionMode;
        _stackOfOpenElements = [NSMutableArray new];
        _errors = [NSMutableArray new];
        _framesetOkFlag = YES;
        _activeFormattingElements = [NSMutableArray new];
        _fragmentParsingAlgorithm = !!context;
        
        if (context) {
            if (context.htmlNamespace == HTMLNamespaceHTML) {
                if (StringIsEqualToAnyOf(context.tagName, @"title", @"textarea")) {
                    _tokenizer.state = HTMLRCDATATokenizerState;
                } else if (StringIsEqualToAnyOf(context.tagName, @"style", @"xmp", @"iframe", @"noembed", @"noframes")) {
                    _tokenizer.state = HTMLRAWTEXTTokenizerState;
                } else if ([context.tagName isEqualToString:@"script"]) {
                    _tokenizer.state = HTMLScriptDataTokenizerState;
                } else if ([context.tagName isEqualToString:@"noscript"]) {
                    _tokenizer.state = HTMLRAWTEXTTokenizerState;
                } else if ([context.tagName isEqualToString:@"plaintext"]) {
                    _tokenizer.state = HTMLPLAINTEXTTokenizerState;
                }
            }
            
            _encoding = (HTMLStringEncoding){
                .encoding = NSUTF8StringEncoding,
                .confidence = Irrelevant
            };
        }
    }
    return self;
}

- (instancetype)init
{
    return [self initWithString:@"" encoding:(HTMLStringEncoding){.encoding = NSUTF8StringEncoding, .confidence = Tentative} context:nil];
}

- (NSString *)string
{
    return _tokenizer.string;
}

- (HTMLDocument *)document
{
    if (_document) return _document;
    _document = [HTMLDocument new];
    if (_fragmentParsingAlgorithm) {
        HTMLElement *root = [[HTMLElement alloc] initWithTagName:@"html" attributes:nil];
        _document.rootElement = root;
        [_stackOfOpenElements setArray:@[ root ]];
        [self resetInsertionModeAppropriately];
        HTMLElement *nearestForm = _context;
        while (nearestForm) {
            if ([nearestForm.tagName isEqualToString:@"form"]) {
                break;
            }
            nearestForm = nearestForm.parentElement;
        }
        _formElementPointer = (HTMLElement *)nearestForm;
    }
    for (id token in _tokenizer) {
        if (_done) break;
        [self processToken:token];
    }
    [self processToken:[HTMLEOFToken new]];
    if (_context) {
        HTMLNode *root = [_document.children objectAtIndex:0];
        NSMutableOrderedSet *documentChildren = [_document mutableChildren];
        [documentChildren removeAllObjects];
        [documentChildren addObjectsFromArray:root.children.array];
    }
    _document.parsedStringEncoding = self.encoding.encoding;
    return _document;
}

- (NSArray *)errors
{
    return [_errors copy];
}

#pragma mark - The "initial" insertion mode

- (void)initialInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    HTMLCharacterToken *afterWhitespace = [token afterLeadingWhitespaceToken];
    if (afterWhitespace) {
        [self initialInsertionModeHandleAnythingElse:afterWhitespace];
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
    _document.documentType = [[HTMLDocumentType alloc] initWithName:(token.name ?: @"html")
                                                   publicIdentifier:token.publicIdentifier
                                                   systemIdentifier:token.systemIdentifier];
    _document.quirksMode = ^{
        if (token.forceQuirks) return HTMLQuirksModeQuirks;
        if (![name isEqualToString:@"html"]) return HTMLQuirksModeQuirks;
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
                return HTMLQuirksModeQuirks;
            }
        }
        if ([public isEqualToString:@"-//W3O//DTD W3 HTML Strict 3.0//EN//"] ||
            [public isEqualToString:@"-/W3C/DTD HTML 4.0 Transitional/EN"] ||
            [public isEqualToString:@"HTML"])
        {
            return HTMLQuirksModeQuirks;
        }
        if ([system isEqualToString:@"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd"]) {
            return HTMLQuirksModeQuirks;
        }
        if (!system) {
            if ([public hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
                [public hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
            {
                return HTMLQuirksModeQuirks;
            }
        }
        if ([public hasPrefix:@"-//W3C//DTD XHTML 1.0 Frameset//"] ||
            [public hasPrefix:@"-//W3C//DTD XHTML 1.0 Transitional//"])
        {
            return HTMLQuirksModeLimitedQuirks;
        }
        if (system) {
            if ([public hasPrefix:@"-//W3C//DTD HTML 4.01 Frameset//"] ||
                [public hasPrefix:@"-//W3C//DTD HTML 4.01 Transitional//"])
            {
                return HTMLQuirksModeLimitedQuirks;
            }
        }
        return HTMLQuirksModeNoQuirks;
    }();
    [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
}

- (void)initialInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError:@"Expected DOCTYPE"];
    _document.quirksMode = HTMLQuirksModeQuirks;
    [self switchInsertionMode:HTMLBeforeHtmlInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "before html" insertion mode

- (void)beforeHtmlInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE"];
}

- (void)beforeHtmlInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:_document];
}

- (void)beforeHtmlInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    HTMLCharacterToken *afterWhitespace = [token afterLeadingWhitespaceToken];
    if (afterWhitespace) {
        [self beforeHtmlInsertionModeHandleAnythingElse:afterWhitespace];
    }
}

- (void)beforeHtmlInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        HTMLElement *html = [self createElementForToken:token];
        [[_document mutableChildren] addObject:html];
        [_stackOfOpenElements addObject:html];
        [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
    } else {
        [self beforeHtmlInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHtmlInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"head", @"body", @"html", @"br")) {
        [self beforeHtmlInsertionModeHandleAnythingElse:token];
    } else {
        [self addParseError:@"Unexpected end tag named %@ before <html>", token.tagName];
    }
}

- (void)beforeHtmlInsertionModeHandleAnythingElse:(id)token
{
    HTMLElement *html = [[HTMLElement alloc] initWithTagName:@"html" attributes:nil];
    [[_document mutableChildren] addObject:html];
    [_stackOfOpenElements addObject:html];
    [self switchInsertionMode:HTMLBeforeHeadInsertionMode];
    [self reprocessToken:token];
}

#pragma mark The "before head" insertion mode

- (void)beforeHeadInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    HTMLCharacterToken *afterWhitespace = [token afterLeadingWhitespaceToken];
    if (afterWhitespace) {
        [self beforeHeadInsertionModeHandleAnythingElse:afterWhitespace];
    }
}

- (void)beforeHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)beforeHeadInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE before <head>"];
}

- (void)beforeHeadInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"head"]) {
        HTMLElement *head = [self insertElementForToken:token];
        _headElementPointer = head;
        [self switchInsertionMode:HTMLInHeadInsertionMode];
    } else {
        [self beforeHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)beforeHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"head", @"body", @"html", @"br")) {
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self insertString:leadingWhitespace.string];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self inHeadInsertionModeHandleAnythingElse:afterLeadingWhitespace];
    }
}

- (void)inHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inHeadInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <head>"];
}

- (void)inHeadInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self processToken:token usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"base", @"basefont", @"bgsound", @"link")) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"meta"]) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        if (self.encoding.confidence == Tentative) {
            NSString *charset = [token.attributes objectForKey:@"charset"];
            if (charset) {
                NSStringEncoding encoding = StringEncodingForLabel(charset);
                if (encoding != InvalidStringEncoding() && (IsASCIICompatibleEncoding(encoding) || IsUTF16Encoding(encoding))) {
                    [self changeEncoding:encoding];
                }
            } else if ([token.attributes objectForKey:@"http-equiv"] && [[token.attributes objectForKey:@"http-equiv"] caseInsensitiveCompare:@"Content-Type"] == NSOrderedSame) {
                NSString *content = [token.attributes objectForKey:@"content"];
                if (content) {
                    NSScanner *scanner = [NSScanner scannerWithString:content];
                    NSString *encodingLabel;
                    for (;;) {
                        [scanner scanUpToString:@"charset" intoString:nil];
                        if (![scanner scanString:@"charset" intoString:nil]) {
                            break;
                        }
                        
                        if ([scanner scanString:@"=" intoString:nil]) {
                            NSString *quote;
                            if ([scanner scanString:@"\"" intoString:nil]) {
                                quote = @"\"";
                            } else if ([scanner scanString:@"'" intoString:nil]) {
                                quote = @"'";
                            }
                            if (quote) {
                                NSRange labelRange = NSMakeRange(scanner.scanLocation, 0);
                                [scanner scanUpToString:quote intoString:nil];
                                if ([scanner scanString:quote intoString:nil]) {
                                    labelRange.length = scanner.scanLocation - 1 - labelRange.location;
                                    encodingLabel = [scanner.string substringWithRange:labelRange];
                                }
                            } else {
                                [scanner scanUpToString:@";" intoString:&encodingLabel];
                            }
                            
                            break;
                        }
                    }
                    
                    if (encodingLabel) {
                        NSStringEncoding encoding = StringEncodingForLabel(encodingLabel);
                        if (encoding != InvalidStringEncoding() && (IsASCIICompatibleEncoding(encoding) || IsUTF16Encoding(encoding))) {
                            [self changeEncoding:encoding];
                        }
                    }
                }
            }
        }
    } else if ([token.tagName isEqualToString:@"title"]) {
        [self followGenericRCDATAElementParsingAlgorithmForToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"noscript", @"noframes", @"style")) {
        [self followGenericRawTextElementParsingAlgorithmForToken:token];
    } else if ([token.tagName isEqualToString:@"script"]) {
        NSUInteger index;
        HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
        HTMLElement *script = [self createElementForToken:token];
        [[adjustedInsertionLocation mutableChildren] insertObject:script atIndex:index];
        [_stackOfOpenElements addObject:script];
        _tokenizer.state = HTMLScriptDataTokenizerState;
        [self switchInsertionMode:HTMLTextInsertionMode];
    } else if ([token.tagName isEqualToString:@"head"]) {
        [self addParseError:@"<head> already started"];
    } else {
        [self inHeadInsertionModeHandleAnythingElse:token];
    }
}

- (void)changeEncoding:(NSStringEncoding)newEncoding
{
    HTMLStringEncoding encoding = self.encoding;
    if (IsUTF16Encoding(encoding.encoding)) {
        encoding.confidence = Certain;
        _encoding = encoding;
        return;
    }
    
    if (IsUTF16Encoding(newEncoding)) {
        newEncoding = NSUTF8StringEncoding;
    }
    
    if (encoding.encoding == newEncoding) {
        encoding.confidence = Certain;
        _encoding = encoding;
        return;
    }
    
    if (self.changeEncoding) {
        self.changeEncoding((HTMLStringEncoding){ .encoding = newEncoding, .confidence = Certain });
        [self stopParsing];
    } else {
        [self addParseError:@"Wanted to change string encoding but couldn't; continuing with misinterpreted resource"];
    }
}

- (void)inHeadInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"head"]) {
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLAfterHeadInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"html", @"br")) {
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self insertString:leadingWhitespace.string];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self afterHeadInsertionModeHandleAnythingElse:afterLeadingWhitespace];
    }
}

- (void)afterHeadInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)afterHeadInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"base", @"basefont", @"bgsound", @"link", @"meta", @"noframes", @"script", @"style", @"title")) {
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
    if (StringIsEqualToAnyOf(token.tagName, @"body", @"html", @"br")) {
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
    NSUInteger startingLength = token.string.length;
    NSString *string = [token.string stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    for (NSUInteger i = 0, end = startingLength - string.length; i < end; i++) {
        [self addParseError:@"Ignoring U+0000 NULL in <body>"];
    }
    if (string.length == 0) return;
    [self reconstructTheActiveFormattingElements];
    [self insertString:string];
    NSCharacterSet *nonWhitespaceSet = [[NSCharacterSet characterSetWithCharactersInString:@"\t\n\f\r "] invertedSet];
    if ([string rangeOfCharacterFromSet:nonWhitespaceSet].location != NSNotFound) {
        _framesetOkFlag = NO;
    }
}

- (void)inBodyInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inBodyInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in <body>"];
}

- (void)inBodyInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if ([token.tagName isEqualToString:@"html"]) {
        [self addParseError:@"Start tag named html in <body>"];
        HTMLElement *element = [_stackOfOpenElements objectAtIndex:0];
        NSDictionary *attributes = token.attributes;
        for (NSString *attributeName in attributes) {
            if (!element[attributeName]) {
                element[attributeName] = (NSString * __nonnull)[attributes objectForKey:attributeName];
            }
        }
    } else if (StringIsEqualToAnyOf(token.tagName, @"base", @"basefont", @"bgsound", @"link", @"meta", @"noframes", @"script", @"style", @"title")) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else if ([token.tagName isEqualToString:@"body"]) {
        [self addParseError:@"Start tag named body in <body>"];
        if (_stackOfOpenElements.count < 2 ||
            ![[[_stackOfOpenElements objectAtIndex:1] tagName] isEqualToString:@"body"])
        {
            return;
        }
        _framesetOkFlag = NO;
        HTMLElement *body = [_stackOfOpenElements objectAtIndex:1];
        NSDictionary *attributes = token.attributes;
        for (NSString *attributeName in attributes) {
            if (!body[attributeName]) {
                body[attributeName] = (NSString * __nonnull)[attributes objectForKey:attributeName];
            }
        }
    } else if ([token.tagName isEqualToString:@"frameset"]) {
        [self addParseError:@"Start tag named frameset in <body>"];
        if (_stackOfOpenElements.count < 2 ||
            ![[[_stackOfOpenElements objectAtIndex:1] tagName] isEqualToString:@"body"])
        {
            return;
        }
        if (!_framesetOkFlag) return;
        HTMLNode *topOfStack = [_stackOfOpenElements objectAtIndex:0];
        [[topOfStack mutableChildren] removeObject:[_stackOfOpenElements objectAtIndex:1]];
        while (_stackOfOpenElements.count > 1) {
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInFramesetInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"address", @"article", @"aside", @"blockquote", @"center", @"details", @"dialog", @"dir", @"div", @"dl", @"fieldset", @"figcaption", @"figure", @"footer", @"header", @"hgroup", @"main", @"nav", @"ol", @"p", @"section", @"summary", @"ul")) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"menu"]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        
        if ([self.currentNode.tagName isEqualToString:@"menuitem"]) {
            [_stackOfOpenElements removeObject:self.currentNode];
        }
        
        [self insertElementForToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"h1", @"h2", @"h3", @"h4", @"h5", @"h6")) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        if (StringIsEqualToAnyOf(self.currentNode.tagName, @"h1", @"h2", @"h3", @"h4", @"h5", @"h6")) {
            [self addParseError:@"Nested header start tag %@ in <body>", token.tagName];
            [_stackOfOpenElements removeLastObject];
        }
        [self insertElementForToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"pre", @"listing")) {
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
        HTMLElement *form = [self insertElementForToken:token];
        _formElementPointer = form;
    } else if ([token.tagName isEqualToString:@"li"]) {
        _framesetOkFlag = NO;
        
        HTMLElement *node = self.currentNode;
        
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
        
        if (IsSpecialElement(node) && !(node.htmlNamespace == HTMLNamespaceHTML && StringIsEqualToAnyOf(node.tagName, @"address", @"div", @"p"))) {
            goto done;
        }
        
        node = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:node] - 1];
        goto loop;
        
    done:
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"dd"] || [token.tagName isEqualToString:@"dt"]) {
        _framesetOkFlag = NO;
        for (HTMLElement *node in _stackOfOpenElements.reverseObjectEnumerator) {
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
            } else if (IsSpecialElement(node) && !(node.htmlNamespace == HTMLNamespaceHTML && StringIsEqualToAnyOf(node.tagName, @"address", @"div", @"p"))) {
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
        for (HTMLElement *element in _activeFormattingElements.reverseObjectEnumerator.allObjects) {
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
        HTMLElement *element = [self insertElementForToken:token];
        [self pushElementOnToListOfActiveFormattingElements:element];
    } else if (StringIsEqualToAnyOf(token.tagName, @"b", @"big", @"code", @"em", @"font", @"i", @"s", @"small", @"strike", @"strong", @"tt", @"u")) {
        [self reconstructTheActiveFormattingElements];
        HTMLElement *element = [self insertElementForToken:token];
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
        HTMLElement *element = [self insertElementForToken:token];
        [self pushElementOnToListOfActiveFormattingElements:element];
    } else if (StringIsEqualToAnyOf(token.tagName, @"applet", @"marquee", @"object")) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [self pushMarkerOnToListOfActiveFormattingElements];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"table"]) {
        if (_document.quirksMode != HTMLQuirksModeQuirks && [self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        [self insertElementForToken:token];
        _framesetOkFlag = NO;
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"area", @"br", @"embed", @"img", @"keygen", @"wbr")) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"input"]) {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        NSString *type = [token.attributes objectForKey:@"type"];
        if (!type || [type caseInsensitiveCompare:@"hidden"] != NSOrderedSame) {
            _framesetOkFlag = NO;
        }
    } else if (StringIsEqualToAnyOf(token.tagName, @"param", @"source", @"track")) {
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"hr"]) {
        if ([self elementInButtonScopeWithTagName:@"p"]) {
            [self closePElement];
        }
        
        if ([self.currentNode.tagName isEqualToString:@"menuitem"]) {
            [_stackOfOpenElements removeObject:self.currentNode];
        }
        
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
        
        _framesetOkFlag = NO;
    } else if ([token.tagName isEqualToString:@"image"]) {
        [self addParseError:@"It's spelled 'img' in <body>"];
        [self reprocessToken:[token copyWithTagName:@"img"]];
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
    } else if ([token.tagName isEqualToString:@"noembed"] || [token.tagName isEqualToString:@"noscript"]) {
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"optgroup", @"option")) {
        if ([self.currentNode.tagName isEqualToString:@"option"]) {
            [_stackOfOpenElements removeLastObject];
        }
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
    } else if ([token.tagName isEqualToString:@"menuitem"]) {
        if ([self.currentNode.tagName isEqualToString:@"menuitem"]) {
            [_stackOfOpenElements removeObject:self.currentNode];
        }
        
        // SPEC: Missing as of 2016-Jul-03 but tests and nearby commentary suggest its presence in order to act like <option>.
        [self reconstructTheActiveFormattingElements];
        
        [self insertElementForToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"rp", @"rt")) {
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
        HTMLElement *element = [self createElementForToken:token inNamespace:HTMLNamespaceMathML];
        [self insertElement:element];
        if (token.selfClosingFlag) {
            [_stackOfOpenElements removeLastObject];
        }
    } else if ([token.tagName isEqualToString:@"svg"]) {
        [self reconstructTheActiveFormattingElements];
        AdjustSVGAttributesForToken(token);
        AdjustForeignAttributesForToken(token);
        HTMLElement *element = [self createElementForToken:token inNamespace:HTMLNamespaceSVG];
        [self insertElement:element];
        if (token.selfClosingFlag) {
            [_stackOfOpenElements removeLastObject];
        }
    } else if (StringIsEqualToAnyOf(token.tagName, @"caption", @"col", @"colgroup", @"frame", @"head", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr")) {
        [self addParseError:@"Start tag named %@ ignored in <body>", token.tagName];
    } else {
        [self reconstructTheActiveFormattingElements];
        [self insertElementForToken:token];
    }
}

- (void)inBodyInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    for (HTMLElement *node in _stackOfOpenElements) {
        if (!StringIsEqualToAnyOf(node.tagName, @"dd", @"dt", @"li", @"p", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr", @"body", @"html")) {
            [self addParseError:@"Unclosed %@ element in <body> at end of file", node.tagName];
            break;
        }
    }
    [self stopParsing];
}

- (void)inBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"body", @"html")) {
        if (![self elementInScopeWithTagName:@"body"]) {
            [self addParseError:@"End tag named %@ without body in scope in <body>", token.tagName];
            return;
        }
        for (HTMLElement *element in _stackOfOpenElements.reverseObjectEnumerator) {
            if (!StringIsEqualToAnyOf(element.tagName, @"dd", @"dt", @"li", @"optgroup", @"option", @"p", @"rp", @"rt", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr", @"body", @"html")) {
                [self addParseError:@"Misplaced %@ element in <body>", element.tagName];
                break;
            }
        }
        [self switchInsertionMode:HTMLAfterBodyInsertionMode];
        if ([token.tagName isEqualToString:@"html"]) {
            [self reprocessToken:token];
        }
    } else if (StringIsEqualToAnyOf(token.tagName, @"address", @"article", @"aside", @"blockquote", @"button", @"center", @"details", @"dialog", @"dir", @"div", @"dl", @"fieldset", @"figcaption", @"figure", @"footer", @"header", @"hgroup", @"listing", @"main", @"menu", @"nav", @"ol", @"pre", @"section", @"summary", @"ul")) {
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
        HTMLElement *node = _formElementPointer;
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
    } else if ([token.tagName isEqualToString:@"dd"] || [token.tagName isEqualToString:@"dt"]) {
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"h1", @"h2", @"h3", @"h4", @"h5", @"h6")) {
        if (![self elementInScopeWithTagNameInArray:@[ @"h1", @"h2", @"h3", @"h4", @"h5", @"h6" ]]) {
            [self addParseError:@"Not closing unknown '%@' element in <body>", token.tagName];
            return;
        }
        [self generateImpliedEndTags];
        if (![self.currentNode.tagName isEqualToString:token.tagName]) {
            [self addParseError:@"Misnested end tag '%@' in <body>", token.tagName];
        }
        while (!StringIsEqualToAnyOf(self.currentNode.tagName, @"h1", @"h2", @"h3", @"h4", @"h5", @"h6")) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
    } else if (StringIsEqualToAnyOf(token.tagName, @"a", @"b", @"big", @"code", @"em", @"font", @"i", @"nobr", @"s", @"small", @"strike", @"strong", @"tt", @"u")) {
        if (![self runAdoptionAgencyAlgorithmForTagName:token.tagName]) {
            [self inBodyInsertionModeHandleAnyOtherEndTagToken:token];
            return;
        }
    } else if (StringIsEqualToAnyOf(token.tagName, @"applet", @"marquee", @"object")) {
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
    HTMLElement *node = self.currentNode;
    for (;;) {
        if ([node.tagName isEqualToString:[token tagName]]) {
            [self generateImpliedEndTagsExceptForTagsNamed:[token tagName]];
            if (![self.currentNode.tagName isEqualToString:[token tagName]]) {
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
        node = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:node] - 1];
    }
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
        HTMLElement *formattingElement;
        for (HTMLElement *element in _activeFormattingElements.reverseObjectEnumerator) {
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
        HTMLElement *furthestBlock;
        for (NSUInteger i = [_stackOfOpenElements indexOfObject:formattingElement] + 1;
             i < _stackOfOpenElements.count; i++)
        {
            if (IsSpecialElement([_stackOfOpenElements objectAtIndex:i])) {
                furthestBlock = [_stackOfOpenElements objectAtIndex:i];
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
        HTMLElement *commonAncestor = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:formattingElement] - 1];
        NSUInteger bookmark = [_activeFormattingElements indexOfObject:formattingElement];
        HTMLElement *node = furthestBlock, *lastNode = furthestBlock;
        NSUInteger nodeIndex = [_stackOfOpenElements indexOfObject:node];
        NSInteger innerLoopCounter = 0;
        while (YES) {
            innerLoopCounter += 1;
            
            nodeIndex -= 1;
            node = [_stackOfOpenElements objectAtIndex:nodeIndex];
            
            if (node == formattingElement) break;
            
            if (innerLoopCounter > 3 && [_activeFormattingElements containsObject:node]) {
                [_activeFormattingElements removeObject:node];
            }
            
            if (![_activeFormattingElements containsObject:node]) {
                [_stackOfOpenElements removeObject:node];
                continue;
            }
            
            HTMLElement *clone = [node copy];
            [_activeFormattingElements replaceObjectAtIndex:[_activeFormattingElements indexOfObject:node]
                                                 withObject:clone];
            [_stackOfOpenElements replaceObjectAtIndex:[_stackOfOpenElements indexOfObject:node]
                                            withObject:clone];
            node = clone;
            
            if ([lastNode isEqual:furthestBlock]) {
                bookmark = [_activeFormattingElements indexOfObject:node];
            }
            
            [[node mutableChildren] addObject:lastNode];
            
            lastNode = node;
        }
        
        [self insertNode:lastNode atAppropriatePlaceWithOverrideTarget:commonAncestor];
        
        HTMLElement *formattingClone = [formattingElement copy];
        
        [formattingClone.mutableChildren addObjectsFromArray:furthestBlock.children.array];
        
        [furthestBlock.mutableChildren addObject:formattingClone];
        
        // TODO: Explain why this is necessary.
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

static BOOL IsSpecialElement(HTMLElement *element)
{
    if (element.htmlNamespace == HTMLNamespaceHTML) {
        return StringIsEqualToAnyOf(element.tagName, @"address", @"applet", @"area", @"article", @"aside", @"base", @"basefont", @"bgsound", @"blockquote", @"body", @"br", @"button", @"caption", @"center", @"col", @"colgroup", @"dd", @"details", @"dir", @"div", @"dl", @"dt", @"embed", @"fieldset", @"figcaption", @"figure", @"footer", @"form", @"frame", @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"header", @"hgroup", @"hr", @"html", @"iframe", @"img", @"input", @"li", @"link", @"listing", @"main", @"marquee", @"menu", @"meta", @"nav", @"noembed", @"noframes", @"noscript", @"object", @"ol", @"p", @"param", @"plaintext", @"pre", @"script", @"section", @"select", @"source", @"style", @"summary", @"table", @"tbody", @"td", @"template", @"textarea", @"tfoot", @"th", @"thead", @"title", @"tr", @"track", @"ul", @"wbr", @"xmp");
    } else if (element.htmlNamespace == HTMLNamespaceMathML) {
        return StringIsEqualToAnyOf(element.tagName, @"mi", @"mo", @"mn", @"ms", @"mtext", @"annotation-xml");
    } else if (element.htmlNamespace == HTMLNamespaceSVG) {
        return StringIsEqualToAnyOf(element.tagName, @"foreignObject", @"desc", @"title");
    } else {
        return NO;
    }
}

#pragma mark The "text" insertion mode

- (void)textInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    [self insertString:token.string];
}

- (void)textInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self addParseError:@"Unexpected end of file in 'text' mode"];
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:_originalInsertionMode];
    [self reprocessToken:token];
}

- (void)textInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    [_stackOfOpenElements removeLastObject];
    [self switchInsertionMode:_originalInsertionMode];
}

#pragma mark The "in table" insertion mode

- (void)inTableInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    if (StringIsEqualToAnyOf(self.currentNode.tagName, @"table", @"tbody", @"tfoot", @"thead", @"tr")) {
        _pendingTableCharacters = [NSMutableString new];
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

- (void)inTableInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"tbody", @"tfoot", @"thead")) {
        [self clearStackBackToATableContext];
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"td", @"th", @"tr")) {
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"style", @"script")) {
        [self processToken:token usingRulesForInsertionMode:HTMLInHeadInsertionMode];
    } else if ([token.tagName isEqualToString:@"input"]) {
        NSString *type = [token.attributes objectForKey:@"type"];
        if (!type || [type caseInsensitiveCompare:@"hidden"] != NSOrderedSame) {
            [self inTableInsertionModeHandleAnythingElse:token];
            return;
        }
        [self addParseError:@"Non-hidden 'input' start tag in <table>"];
        [self insertElementForToken:token];
        [_stackOfOpenElements removeLastObject];
    } else if ([token.tagName isEqualToString:@"form"]) {
        [self addParseError:@"'form' start tag in <table>"];
        if (_formElementPointer) return;
        HTMLElement *form = [self insertElementForToken:token];
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"caption", @"col", @"colgroup", @"html", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr")) {
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
    while (!StringIsEqualToAnyOf(self.currentNode.tagName, @"table", @"html")) {
        [_stackOfOpenElements removeLastObject];
    }
}

#pragma mark The "in table text" insertion mode

- (void)inTableTextInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    NSUInteger startingLength = token.string.length;
    NSString *string = [token.string stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    for (NSUInteger i = 0, end = startingLength - string.length; i < end; i++) {
        [self addParseError:@"Ignoring U+0000 NULL in <table> text"];
    }
    [_pendingTableCharacters appendString:string];
}

- (void)inTableTextInsertionModeHandleAnythingElse:(id)token
{
    NSCharacterSet *nonWhitespaceSet = [[NSCharacterSet characterSetWithCharactersInString:@" \t\n\f\r"] invertedSet];
    if ([_pendingTableCharacters rangeOfCharacterFromSet:nonWhitespaceSet].location != NSNotFound) {
        HTMLCharacterToken *characterToken = [[HTMLCharacterToken alloc] initWithString:_pendingTableCharacters];
        [self inTableInsertionModeHandleAnythingElse:characterToken];
    } else {
        [self insertString:_pendingTableCharacters];
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"col", @"colgroup", @"html", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr")) {
        [self addParseError:@"End tag '%@' in <caption>", token.tagName];
    } else {
        [self inCaptionInsertionModeHandleAnythingElse:token];
    }
}

- (void)inCaptionInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"caption", @"col", @"colgorup", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr")) {
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self insertString:leadingWhitespace.string];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self inColumnGroupInsertionModeHandleAnythingElse:afterLeadingWhitespace];
    }
}

- (void)inColumnGroupInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inColumnGroupInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"th", @"td")) {
        [self addParseError:@"Start tag '%@' in <table> body", token.tagName];
        [self clearStackBackToATableBodyContext];
        [self insertElementForToken:[[HTMLStartTagToken alloc] initWithTagName:@"tr"]];
        [self switchInsertionMode:HTMLInRowInsertionMode];
        [self reprocessToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"caption", @"col", @"colgroup", @"tbody", @"tfoot", @"thead")) {
        if (![self elementInTableScopeWithTagNameInArray:@[ @"tbody", @"thead", @"tfoot" ] namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"Start tag '%@' when none of <tbody>, <thead>, <tfoot> in table scope; ignoring", token.tagName];
            return;
        }
        
        [self clearStackBackToATableBodyContext];
        
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
        
        [self reprocessToken:token];
    } else {
        [self inTableBodyInsertionModeHandleAnythingElse:token];
    }
}

- (void)inTableBodyInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"tbody", @"tfoot", @"thead")) {
        if (![self elementInTableScopeWithTagName:token.tagName]) {
            [self addParseError:@"End tag '%@' for unknown element in <table> body", token.tagName];
            return;
        }
        [self clearStackBackToATableBodyContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        if (![self elementInTableScopeWithTagNameInArray:@[ @"tbody", @"thead", @"tfoot" ] namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"End tag 'table' when none of <tbody>, <thead>, <tfoot> in table scope; ignoring"];
            return;
        }
        
        [self clearStackBackToATableBodyContext];
        
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableInsertionMode];
        
        [self reprocessToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"caption", @"col", @"colgroup", @"html", @"td", @"th", @"tr")) {
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
    while (!StringIsEqualToAnyOf(self.currentNode.tagName, @"tbody", @"tfoot", @"thead", @"html")) {
        [_stackOfOpenElements removeLastObject];
    }
}

#pragma mark The "in row" insertion mode

- (void)inRowInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"th", @"td")) {
        [self clearStackBackToATableRowContext];
        
        [self insertElementForToken:token];
        [self switchInsertionMode:HTMLInCellInsertionMode];
        
        [self pushMarkerOnToListOfActiveFormattingElements];
    } else if (StringIsEqualToAnyOf(token.tagName, @"caption", @"col", @"colgroup", @"tbody", @"tfoot", @"thead", @"tr")) {
        if (![self elementInTableScopeWithTagName:@"tr" namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"Start tag '%@' without <tr> in table scope; ignoring", token.tagName];
            return;
        }
        
        [self clearStackBackToATableRowContext];
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        
        [self reprocessToken:token];
    } else {
        [self inRowInsertionModeHandleAnythingElse:token];
    }
}

- (void)inRowInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    if ([token.tagName isEqualToString:@"tr"]) {
        if (![self elementInTableScopeWithTagName:@"tr" namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"End tag 'tr' for unknown element in <tr>"];
            return;
        }
        
        [self clearStackBackToATableRowContext];
        
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
    } else if ([token.tagName isEqualToString:@"table"]) {
        if (![self elementInTableScopeWithTagName:@"tr" namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"End tag 'table' without <tr> in table scope; ignoring"];
            return;
        }
        
        [self clearStackBackToATableRowContext];
        
        [_stackOfOpenElements removeLastObject];
        [self switchInsertionMode:HTMLInTableBodyInsertionMode];
        
        [self reprocessToken:token];
    } else if (StringIsEqualToAnyOf(token.tagName, @"tbody", @"tfoot", @"thead")) {
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"caption", @"col", @"colgroup", @"html", @"td", @"th")) {
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
    while (!StringIsEqualToAnyOf(self.currentNode.tagName, @"tr", @"html")) {
        [_stackOfOpenElements removeLastObject];
    }
}

#pragma mark The "in cell" insertion mode

- (void)inCellInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"caption", @"col", @"colgroup", @"tbody", @"td", @"tfoot", @"th", @"thead", @"tr")) {
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
    if (StringIsEqualToAnyOf(token.tagName, @"td", @"th")) {
        if (![self elementInTableScopeWithTagName:token.tagName namespace:HTMLNamespaceHTML]) {
            [self addParseError:@"End tag '%@' outside cell in cell", token.tagName];
            return;
        }
        
        [self generateImpliedEndTags];
        
        if (!(self.currentNode.htmlNamespace == HTMLNamespaceHTML && [self.currentNode.tagName isEqualToString:token.tagName])) {
            [self addParseError:@"Misnested end tag '%@' in cell", token.tagName];
        }
        
        while (!(self.currentNode.htmlNamespace == HTMLNamespaceHTML && [self.currentNode.tagName isEqualToString:token.tagName])) {
            [_stackOfOpenElements removeLastObject];
        }
        [_stackOfOpenElements removeLastObject];
        
        [self clearActiveFormattingElementsUpToLastMarker];
        
        [self switchInsertionMode:HTMLInRowInsertionMode];
    } else if (StringIsEqualToAnyOf(token.tagName, @"body", @"caption", @"col", @"colgroup", @"html")) {
        [self addParseError:@"End tag '%@' in cell", token.tagName];
    } else if (StringIsEqualToAnyOf(token.tagName, @"table", @"tbody", @"tfoot", @"thead", @"tr")) {
        if (![self elementInTableScopeWithTagName:token.tagName namespace:HTMLNamespaceHTML]) {
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
    if (!StringIsEqualToAnyOf(self.currentNode.tagName, @"td", @"th")) {
        [self addParseError:@"Closing misnested cell"];
    }
    while (!StringIsEqualToAnyOf(self.currentNode.tagName, @"td", @"th")) {
        [_stackOfOpenElements removeLastObject];
    }
    [_stackOfOpenElements removeLastObject];
    [self clearActiveFormattingElementsUpToLastMarker];
    [self switchInsertionMode:HTMLInRowInsertionMode];
}

#pragma mark The "in select" insertion mode

- (void)inSelectInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    NSUInteger startingLength = token.string.length;
    NSString *string = [token.string stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    for (NSUInteger i = 0, end = startingLength - string.length; i < end; i++) {
        [self addParseError:@"Ignoring U+0000 NULL in <select>"];
    }
    if (string.length > 0) {
        [self insertString:string];
    }
}

- (void)inSelectInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inSelectInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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
    } else if (StringIsEqualToAnyOf(token.tagName, @"input", @"keygen", @"textarea")) {
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
        HTMLElement *currentNode = self.currentNode;
        HTMLElement *beforeIt = [_stackOfOpenElements objectAtIndex:_stackOfOpenElements.count - 2];
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

- (void)inSelectInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError:@"Unexpected token in <select>"];
}

#pragma mark The "in select in table" insertion mode

- (void)inSelectInTableInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th")) {
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
    if (StringIsEqualToAnyOf(token.tagName, @"caption", @"table", @"tbody", @"tfoot", @"thead", @"tr", @"td", @"th")) {
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self processToken:leadingWhitespace usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self afterBodyInsertionModeHandleAnythingElse:afterLeadingWhitespace];
    }
}

- (void)afterBodyInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data inNode:[_stackOfOpenElements objectAtIndex:0]];
}

- (void)afterBodyInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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

- (void)afterBodyInsertionModeHandleEOFToken:(HTMLEOFToken *)token
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
    EnumerateLongCharacters(token.string, ^(UTF32Char character) {
        if (is_whitespace(character)) {
            [self insertString:StringWithLongCharacter(character)];
        } else {
            [self addParseError:@"Unexpected token in <frameset>"];
        }
    });
}

- (void)inFramesetInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)inFramesetInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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

- (void)inFramesetInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    if (!([self.currentNode.tagName isEqualToString:@"html"] &&
        _stackOfOpenElements.count == 1))
    {
        [self addParseError:@"Unexpected EOF in <frameset>"];
    }
    [self stopParsing];
}

- (void)inFramesetInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError:@"Unexpected token in <frameset>"];
}

#pragma mark The "after frameset" insertion mode

- (void)afterFramesetInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    EnumerateLongCharacters(token.string, ^(UTF32Char character) {
        if (is_whitespace(character)) {
            [self insertString:StringWithLongCharacter(character)];
        } else {
            [self addParseError:@"Unexpected token after <frameset>"];
        }
    });
}

- (void)afterFramesetInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)afterFramesetInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
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

- (void)afterFramesetInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterFramesetInsertionModeHandleAnythingElse:(id)token
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self processToken:leadingWhitespace usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self afterAfterBodyInsertionModeHandleAnythingElse:afterLeadingWhitespace];
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

- (void)afterAfterBodyInsertionModeHandleEOFToken:(HTMLEOFToken *)token
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
    HTMLCharacterToken *leadingWhitespace = [token leadingWhitespaceToken];
    if (leadingWhitespace) {
        [self processToken:leadingWhitespace usingRulesForInsertionMode:HTMLInBodyInsertionMode];
    }
    HTMLCharacterToken *afterLeadingWhitespace = [token afterLeadingWhitespaceToken];
    if (afterLeadingWhitespace) {
        [self afterAfterFramesetInsertionModeHandleAnythingElse:afterLeadingWhitespace];
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

- (void)afterAfterFramesetInsertionModeHandleEOFToken:(HTMLEOFToken *)token
{
    [self stopParsing];
}

- (void)afterAfterFramesetInsertionModeHandleAnythingElse:(id)token
{
    [self addParseError:@"Unexpected token after after <frameset>"];
}

#pragma mark Rules for parsing tokens in foreign content

- (void)foreignContentInsertionModeHandleCharacterToken:(HTMLCharacterToken *)token
{
    CFStringInlineBuffer buffer;
    CFRange range = CFRangeMake(0, token.string.length);
    CFStringInitInlineBuffer((__bridge CFStringRef)token.string, &buffer, range);
    for (CFIndex i = 0; i < range.length; i++) {
        unichar c = CFStringGetCharacterFromInlineBuffer(&buffer, i);
        if (c == '\0') {
            [self addParseError:@"U+0000 NULL character in foreign content"];
        } else if (!is_whitespace(c)) {
            _framesetOkFlag = NO;
        }
    }
    [self insertString:[token.string stringByReplacingOccurrencesOfString:@"\0" withString:@"\uFFFD"]];
}

- (void)foreignContentInsertionModeHandleCommentToken:(HTMLCommentToken *)token
{
    [self insertComment:token.data];
}

- (void)foreignContentInsertionModeHandleDOCTYPEToken:(HTMLDOCTYPEToken *)token
{
    [self addParseError:@"Unexpected DOCTYPE in foreign content"];
}

- (void)foreignContentInsertionModeHandleStartTagToken:(HTMLStartTagToken *)token
{
    if (StringIsEqualToAnyOf(token.tagName, @"b", @"big", @"blockquote", @"body", @"br", @"center", @"code", @"dd", @"div", @"dl",  @"dt", @"em", @"embed", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"hr", @"i",  @"img", @"li", @"listing", @"menu", @"meta", @"nobr", @"ol", @"p", @"pre", @"ruby", @"s",  @"small", @"span", @"strong", @"strike", @"sub", @"sup", @"table", @"tt", @"u", @"ul",  @"var") ||
        ([token.tagName isEqualToString:@"font"] && ([token.attributes objectForKey:@"color"] || [token.attributes objectForKey:@"face"] || [token.attributes objectForKey:@"size"]))) {
        [self addParseError:@"Unexpected HTML start tag token in foreign content"];
        if (_fragmentParsingAlgorithm) {
            [self foreignContentInsertionModeHandleAnyOtherStartTagToken:token];
            return;
        }
        [_stackOfOpenElements removeLastObject];
        while (!(self.currentNode.htmlNamespace == HTMLNamespaceHTML ||
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
    if (self.adjustedCurrentNode.htmlNamespace == HTMLNamespaceMathML) {
        AdjustMathMLAttributesForToken(token);
    } else if (self.adjustedCurrentNode.htmlNamespace == HTMLNamespaceSVG) {
        FixSVGTagNameCaseForToken(token);
        AdjustSVGAttributesForToken(token);
    }
    AdjustForeignAttributesForToken(token);
    [self insertForeignElementForToken:token inNamespace:self.adjustedCurrentNode.htmlNamespace];
    if (token.selfClosingFlag) {
        [_stackOfOpenElements removeLastObject];
    }
}

static void AdjustMathMLAttributesForToken(HTMLStartTagToken *token)
{
    NSString *lowercaseName = @"definitionurl";
    NSUInteger i = [token.attributes indexOfKey:lowercaseName];
    if (i != NSNotFound) {
        NSString *value = [token.attributes objectForKey:lowercaseName];
        [token.attributes removeObjectForKey:lowercaseName];
        [token.attributes insertObject:value forKey:@"definitionURL" atIndex:i];
    }
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
    NSString *replacement = [names objectForKey:token.tagName];
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
        @"diffuseconstant": @"diffuseConstant",
        @"edgemode": @"edgeMode",
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
    HTMLOrderedDictionary *newAttributes = [HTMLOrderedDictionary new];
    [token.attributes enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        NSString *newName = [names objectForKey:name] ?: name;
        [newAttributes setObject:value forKey:newName];
    }];
    token.attributes = newAttributes;
}

static void AdjustForeignAttributesForToken(HTMLStartTagToken *token)
{
    // no-op; we really don't care about attribute namespace
}

- (void)foreignContentInsertionModeHandleEndTagToken:(HTMLEndTagToken *)token
{
    HTMLElement *node = self.currentNode;
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
        node = [_stackOfOpenElements objectAtIndex:nodeIndex - 1];
        if (node.htmlNamespace == HTMLNamespaceHTML) break;
    }
    [self processToken:token usingRulesForInsertionMode:_insertionMode];
}

#pragma mark - Process tokens

- (void)processToken:(id)token
{
    if (^(HTMLElement *node){
        if (!node) return YES;
        if (node.htmlNamespace == HTMLNamespaceHTML) return YES;
        if (IsMathMLTextIntegrationPoint(node)) {
            if ([token isKindOfClass:[HTMLStartTagToken class]] &&
                !StringIsEqualToAnyOf([token tagName], @"mglyph", @"malignmark"))
            {
                return YES;
            }
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return YES;
            }
        }
        if (node.htmlNamespace == HTMLNamespaceMathML &&
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

static BOOL IsMathMLTextIntegrationPoint(HTMLElement *node)
{
    if (node.htmlNamespace != HTMLNamespaceMathML) return NO;
    return StringIsEqualToAnyOf(node.tagName, @"mi", @"mo", @"mn", @"ms", @"mtext");
}

static BOOL IsHTMLIntegrationPoint(HTMLElement *node)
{
    if (node.htmlNamespace == HTMLNamespaceMathML && [node.tagName isEqualToString:@"annotation-xml"]) {
        
        // SPEC We're told that "an annotation-xml element in the MathML namespace whose *start tag
        //      token* had an attribute with the name 'encoding'..." (emphasis mine) is an HTML
        //      integration point. Here we're examining the element node's attributes instead. This
        //      seems like a distinction without a difference.
        NSString *encoding = [node.attributes objectForKey:@"encoding"];
        if (encoding) {
            if ([encoding caseInsensitiveCompare:@"text/html"] == NSOrderedSame) {
                return YES;
            } else if ([encoding caseInsensitiveCompare:@"application/xhtml+xml"] == NSOrderedSame) {
                return YES;
            }
        }
    } else if (node.htmlNamespace == HTMLNamespaceSVG) {
        return StringIsEqualToAnyOf(node.tagName, @"foreignObject", @"desc", @"title");
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
        HTMLCharacterToken *characterToken = token;
        if ([characterToken isKindOfClass:[HTMLCharacterToken class]] && [characterToken.string characterAtIndex:0] == '\n') {
            NSString *string = [characterToken.string substringFromIndex:1];
            if (string.length > 0) {
                token = [[HTMLCharacterToken alloc] initWithString:string];
            } else {
                return;
            }
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
        inBodyInsertionMode:
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
            } else {
                NSAssert(NO, @"invalid %@ in in body insertion mode", [token class]);
            }
            
        case HTMLTextInsertionMode:
            if ([token isKindOfClass:[HTMLCharacterToken class]]) {
                return [self textInsertionModeHandleCharacterToken:token];
            } else if ([token isKindOfClass:[HTMLEndTagToken class]]) {
                return [self textInsertionModeHandleEndTagToken:token];
            } else if ([token isKindOfClass:[HTMLEOFToken class]]) {
                return [self textInsertionModeHandleEOFToken:token];
            } else {
                NSAssert(NO, @"invalid %@ in text insertion mode", [token class]);
            }
            
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
                goto inBodyInsertionMode;
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
            } else {
                NSAssert(NO, @"invalid %@ in foreign content insertion mode", [token class]);
            }
            
        default:
            NSAssert(NO, @"cannot handle %@ token in insertion mode %ld", [token class], (long)insertionMode);
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

- (HTMLElement *)currentNode
{
    return _stackOfOpenElements.lastObject;
}

- (HTMLElement *)adjustedCurrentNode
{
    if (_fragmentParsingAlgorithm && _stackOfOpenElements.count == 1) {
        return _context;
    } else {
        return self.currentNode;
    }
}

- (HTMLElement *)elementInScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]];
}

- (HTMLElement *)elementInScopeWithTagNameInArray:(NSArray *)tagNames
{
    return [self elementInScopeWithTagNameInArray:tagNames additionalElementTypes:nil];
}

- (HTMLElement *)elementInButtonScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]
                           additionalElementTypes:@[ @"button" ]];
}

- (HTMLElement *)elementInScopeWithTagNameInArray:(NSArray *)tagNames
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

- (HTMLElement *)elementInSpecificScopeWithTagNameInArray:(NSArray *)tagNames
                                             elementTypes:(NSDictionary *)elementTypes
{
    for (HTMLElement *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([tagNames containsObject:node.tagName]) return node;
        if ([[elementTypes objectForKey:@(node.htmlNamespace)] containsObject:node.tagName]) return nil;
    }
    return nil;
}

- (HTMLElement *)elementInSpecificScopeWithTagNameInArray:(NSArray *)tagNames
                                             elementTypes:(NSDictionary *)elementTypes
                                                namespace:(HTMLNamespace)namespace
{
    for (HTMLElement *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if (node.htmlNamespace == namespace && [tagNames containsObject:node.tagName]) return node;
        if ([[elementTypes objectForKey:@(node.htmlNamespace)] containsObject:node.tagName]) return nil;
    }
    return nil;
}

- (HTMLElement *)elementInTableScopeWithTagName:(NSString *)tagName
{
    return [self elementInTableScopeWithTagNameInArray:@[ tagName ]];
}

- (HTMLElement *)elementInTableScopeWithTagName:(NSString *)tagName namespace:(HTMLNamespace)namespace
{
    return [self elementInTableScopeWithTagNameInArray:@[ tagName ] namespace:namespace];
}

- (HTMLElement *)elementInTableScopeWithTagNameInArray:(NSArray *)tagNames
{
    NSDictionary *elementTypes = @{ @(HTMLNamespaceHTML): @[ @"html", @"table" ] };
    return [self elementInSpecificScopeWithTagNameInArray:tagNames elementTypes:elementTypes];
}

- (HTMLElement *)elementInTableScopeWithTagNameInArray:(NSArray *)tagNames namespace:(HTMLNamespace)namespace
{
    NSDictionary *elementTypes = @{ @(HTMLNamespaceHTML): @[ @"html", @"table" ] };
    return [self elementInSpecificScopeWithTagNameInArray:tagNames elementTypes:elementTypes namespace:namespace];
}

- (HTMLElement *)elementInListItemScopeWithTagName:(NSString *)tagName
{
    return [self elementInScopeWithTagNameInArray:@[ tagName ]
                           additionalElementTypes:@[ @"ol", @"ul" ]];
}

- (HTMLElement *)selectElementInSelectScope
{
    for (HTMLElement *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node.tagName isEqualToString:@"select"]) return node;
        if (!(node.htmlNamespace == HTMLNamespaceHTML && StringIsEqualToAnyOf(node.tagName, @"optgroup", @"option"))) {
            return nil;
        }
    }
    return nil;
}

- (BOOL)isElementInScope:(HTMLElement *)element
{
    NSDictionary *elementTypes = ElementTypesForSpecificScope(nil);
    for (HTMLElement *node in _stackOfOpenElements.reverseObjectEnumerator) {
        if ([node isEqual:element]) return YES;
        if ([[elementTypes objectForKey:@(node.htmlNamespace)] containsObject:node.tagName]) return NO;
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
        index = node.numberOfChildren;
    } else {
        node = [self appropriatePlaceForInsertingANodeIndex:&index];
    }
    HTMLComment *comment = [[HTMLComment alloc] initWithData:data];
    [[node mutableChildren] insertObject:comment atIndex:index];
}

- (HTMLNode *)appropriatePlaceForInsertingANodeIndex:(out NSUInteger *)index
{
    return [self appropriatePlaceForInsertingANodeWithOverrideTarget:nil index:index];
}

- (HTMLNode *)appropriatePlaceForInsertingANodeWithOverrideTarget:(HTMLElement *)overrideTarget
                                                            index:(out NSUInteger *)index
{
    HTMLElement *target = overrideTarget ?: self.currentNode;
    if (_fosterParenting && StringIsEqualToAnyOf(target.tagName, @"table", @"tbody", @"tfoot", @"thead", @"tr")) {
        HTMLElement *lastTable;
        for (HTMLElement *element in _stackOfOpenElements.reverseObjectEnumerator) {
            if ([element.tagName isEqualToString:@"table"]) {
                lastTable = element;
                break;
            }
        }
        if (!lastTable) {
            HTMLElement *html = [_stackOfOpenElements objectAtIndex:0];
            *index = html.numberOfChildren;
            return html;
        }
        if (lastTable.parentElement) {
            *index = [lastTable.parentElement.children indexOfObject:lastTable];
            return lastTable.parentElement;
        }
        NSUInteger indexOfLastTable = [_stackOfOpenElements indexOfObject:lastTable];
        HTMLElement *previousNode = [_stackOfOpenElements objectAtIndex:indexOfLastTable - 1];
        *index = previousNode.numberOfChildren;
        return previousNode;
    } else {
        *index = target.numberOfChildren;
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

- (HTMLElement *)createElementForToken:(id)token
{
    return [self createElementForToken:token inNamespace:HTMLNamespaceHTML];
}

- (HTMLElement *)createElementForToken:(HTMLTagToken *)token inNamespace:(HTMLNamespace)namespace
{
    HTMLElement *element = [[HTMLElement alloc] initWithTagName:token.tagName attributes:token.attributes];
    element.htmlNamespace = namespace;
    return element;
}

- (HTMLElement *)insertElementForToken:(id)token
{
    HTMLElement *element = [self createElementForToken:token];
    [self insertElement:element];
    return element;
}

- (void)insertElement:(HTMLElement *)element
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    [[adjustedInsertionLocation mutableChildren] insertObject:element atIndex:index];
    [_stackOfOpenElements addObject:element];
}

- (void)insertString:(NSString *)string
{
    NSUInteger index;
    HTMLNode *adjustedInsertionLocation = [self appropriatePlaceForInsertingANodeIndex:&index];
    if (![adjustedInsertionLocation isKindOfClass:[HTMLDocument class]]) {
        [adjustedInsertionLocation insertString:string atChildNodeIndex:index];
    }
}

- (void)insertNode:(HTMLNode *)node atAppropriatePlaceWithOverrideTarget:(HTMLElement *)overrideTarget
{
    NSUInteger i;
    HTMLNode *parent = [self appropriatePlaceForInsertingANodeWithOverrideTarget:overrideTarget index:&i];
    [[parent mutableChildren] insertObject:node atIndex:i];
}

- (void)insertForeignElementForToken:(id)token inNamespace:(HTMLNamespace)namespace
{
    HTMLElement *element = [self createElementForToken:token inNamespace:namespace];
    [[self.currentNode mutableChildren] addObject:element];
    [_stackOfOpenElements addObject:element];
}

- (void)resetInsertionModeAppropriately
{
    BOOL last = NO;
    HTMLElement *node = self.currentNode;
    for (;;) {
        if ([[_stackOfOpenElements objectAtIndex:0] isEqual:node]) {
            last = YES;
            node = _context;
        }
        if ([node.tagName isEqualToString:@"select"]) {
            HTMLElement *ancestor = node;
            for (;;) {
                if (last) break;
                if ([[_stackOfOpenElements objectAtIndex:0] isEqual:ancestor]) break;
                ancestor = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:ancestor] - 1];
                if ([ancestor.tagName isEqualToString:@"table"]) {
                    [self switchInsertionMode:HTMLInSelectInTableInsertionMode];
                    return;
                }
            }
            [self switchInsertionMode:HTMLInSelectInsertionMode];
            return;
        }
        if (!last && StringIsEqualToAnyOf(node.tagName, @"td", @"th")) {
            [self switchInsertionMode:HTMLInCellInsertionMode];
            return;
        }
        if ([node.tagName isEqualToString:@"tr"]) {
            [self switchInsertionMode:HTMLInRowInsertionMode];
            return;
        }
        if (StringIsEqualToAnyOf(node.tagName, @"tbody", @"thead", @"tfoot")) {
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
        node = [_stackOfOpenElements objectAtIndex:[_stackOfOpenElements indexOfObject:node] - 1];
    }
}

#pragma mark List of active formatting elements

- (void)pushElementOnToListOfActiveFormattingElements:(HTMLElement *)element
{
    NSInteger alreadyPresent = 0;
    for (HTMLElement *node in _activeFormattingElements.reverseObjectEnumerator.allObjects) {
        if ([node isEqual:[HTMLMarker marker]]) break;
        if (![node.tagName isEqualToString:element.tagName]) continue;
        if (![node.attributes isEqual:element.attributes]) continue;
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

- (void)removeElementFromListOfActiveFormattingElements:(HTMLElement *)element
{
    [_activeFormattingElements removeObject:element];
}

- (void)reconstructTheActiveFormattingElements
{
    if (_activeFormattingElements.count == 0) return;
    if ([_activeFormattingElements.lastObject isEqual:[HTMLMarker marker]]) return;
    if ([_stackOfOpenElements containsObject:(id __nonnull)_activeFormattingElements.lastObject]) return;
    NSUInteger entryIndex = _activeFormattingElements.count - 1;
rewind:
    if (entryIndex == 0) goto create;
    entryIndex--;
    if (!([[_activeFormattingElements objectAtIndex:entryIndex] isEqual:[HTMLMarker marker]] ||
          [_stackOfOpenElements containsObject:[_activeFormattingElements objectAtIndex:entryIndex]]))
    {
        goto rewind;
    }
advance:
    entryIndex++;
create:;
    HTMLElement *entry = [_activeFormattingElements objectAtIndex:entryIndex];
    HTMLStartTagToken *token = [[HTMLStartTagToken alloc] initWithTagName:entry.tagName];
    [token.attributes addEntriesFromDictionary:entry.attributes];
    HTMLElement *newElement = [self insertElementForToken:token];
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
    NSArray *list = @[ @"dd", @"dt", @"li", @"menuitem", @"optgroup", @"option", @"p", @"rp", @"rt" ];
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

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
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

HTMLParser * ParserWithDataAndContentType(NSData *data, NSString *contentType)
{
    NSString *initialString;
    HTMLStringEncoding initialEncoding = DeterminedStringEncodingForData(data, contentType, &initialString);
    HTMLParser *initialParser = [[HTMLParser alloc] initWithString:initialString encoding:initialEncoding context:nil];
    __block HTMLParser *finalParser;
    initialParser.changeEncoding = ^(HTMLStringEncoding newEncoding) {
        NSString *correctedString = [[NSString alloc] initWithData:data encoding:newEncoding.encoding];
        if (correctedString) {
            finalParser = [[HTMLParser alloc] initWithString:correctedString encoding:newEncoding context:nil];
        } else {
            finalParser = [[HTMLParser alloc] initWithString:initialString encoding:initialEncoding context:nil];
        }
    };
    [initialParser document];
    return finalParser ?: initialParser;
}
