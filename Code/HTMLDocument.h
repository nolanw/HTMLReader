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
 */
@interface HTMLDocument : HTMLNode

/**
 * Parses a string of HTML.
 *
 * @param string Some HTML.
 *
 * @return An initialized HTMLDocument.
 */
+ (instancetype)documentWithString:(NSString *)string;

/**
 * The document type node.
 */
@property (strong, nonatomic) HTMLDocumentType *documentType;

/**
 * The document's quirks mode.
 */
@property (assign, nonatomic) HTMLQuirksMode quirksMode;

/**
 * The root node (usually the <html> element node), ignoring the document type node and any root-level comment nodes.
 */
@property (strong, nonatomic) HTMLElement *rootElement;

@end
