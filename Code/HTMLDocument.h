//  HTMLDocument.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLDocumentType.h"
#import "HTMLElement.h"
#import "HTMLNode.h"
#import "HTMLQuirksMode.h"

/**
 * An HTMLDocument is the root of a tree of nodes representing parsed HTML.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/syntax.html#writing
 */
@interface HTMLDocument : HTMLNode

/**
 * Parses an HTML string into a document.
 */
+ (instancetype)documentWithString:(NSString *)string;

/**
 * The document type node. Setting a new documentType immediately removes the current documentType from the document.
 */
@property (strong, nonatomic) HTMLDocumentType *documentType;

/**
 * The document's quirks mode.
 */
@property (assign, nonatomic) HTMLQuirksMode quirksMode;

/**
 * The first element in tree order. Typically the `<html>` element.
 */
@property (strong, nonatomic) HTMLElement *rootElement;

@end
