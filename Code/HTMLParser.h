//  HTMLParser.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLAttribute.h"
#import "HTMLDocument.h"
#import "HTMLNode.h"

/**
 * An HTMLParser parses HTML. It implements the tree construction phase.
 */
@interface HTMLParser : NSObject

/**
 * Returns a parsed HTML document, or nil on error.
 *
 * @param string The unparsed HTML document.
 */
+ (HTMLDocument*)documentForString:(NSString *)string;

/**
 * Returns an HTMLParser initialized for parsing a full HTML document.
 *
 * @param string The unparsed HTML document.
 */
+ (instancetype)parserForString:(NSString *)string;

/**
 * Returns an HTMLParser initialized for parsing a full HTML document. This is a designated initializer.
 *
 * @param string The unparsed HTML document.
 */
- (id)initWithString:(NSString *)string;

/**
 * Returns an HTMLParser initialized for parsing an HTML fragment.
 *
 * @param string The unparsed HTML fragment.
 * @param context A context element, or nil if there is no context.
 */
+ (instancetype)parserForString:(NSString *)string context:(HTMLElement *)context;

/**
 * Returns an HTMLParser initialized for parsing an HTML fragment. This is a designated initializer.
 *
 * @param string The unparsed HTML fragment.
 * @param context A context element, or nil if there is no context.
 */
- (id)initWithString:(NSString *)string context:(HTMLElement *)context;

/**
 * All encountered parse errors.
 */
@property (readonly, copy, nonatomic) NSArray *errors;

/**
 * The parsed document.
 */
@property (readonly, strong, nonatomic) HTMLDocument *document;

@end
