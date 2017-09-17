//  HTMLDocument.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocumentType.h"
#import "HTMLElement.h"
#import "HTMLNode.h"
#import "HTMLQuirksMode.h"
#import "HTMLSupport.h"

NS_ASSUME_NONNULL_BEGIN

/**
    An HTMLDocument is the root of a tree of nodes representing parsed HTML.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html#writing
 */
@interface HTMLDocument : HTMLNode

/**
    Parses data of an unknown string encoding into an HTML document.
 
    @param contentType The value of the HTTP Content-Type header, if present.
 */
+ (instancetype)documentWithData:(NSData *)data contentTypeHeader:(NSString * __nullable)contentType;

/**
    Initializes a document with data of an unknown string encoding.
 
    @param contentType The value of the HTTP Content-Type header, if present.
 */
- (instancetype)initWithData:(NSData *)data contentTypeHeader:(NSString * __nullable)contentType;

/// Parses an HTML string into a document.
+ (instancetype)documentWithString:(NSString *)string;

/// Initializes a document with a string of HTML.
- (instancetype)initWithString:(NSString *)string;

/**
    The document type node.
 
    The setter replaces the existing documentType, if there is one; otherwise, the new documentType will be placed immediately before the rootElement, if there is one; otherwise the new documentType is added as the last child.
 */
@property (strong, nonatomic) HTMLDocumentType * __nullable documentType;

/// The string encoding used to parse the document. Defaults to `NSUTF8StringEncoding` (e.g. if the document was created programmatically).
@property (readonly, nonatomic) NSStringEncoding parsedStringEncoding;

/// The document's quirks mode.
@property (assign, nonatomic) HTMLQuirksMode quirksMode;

/**
    The first element in tree order. Typically the `<html>` element.
 
    The setter replaces the existing rootElement, if there is one; otherwise, the new rootElement is added as the last child.
 */
@property (strong, nonatomic) HTMLElement * __nullable rootElement;

/**
    The first child element of the root with the tag name `body`. Typically the `<body>` element.
 */
@property (readonly, nonatomic) HTMLElement * __nullable bodyElement;

@end

NS_ASSUME_NONNULL_END
