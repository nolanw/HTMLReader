//  HTMLParser.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLDocument.h"
#import "HTMLElement.h"

/**
 * An HTMLParser parses HTML. It implements the tree construction phase.
 */
@interface HTMLParser : NSObject

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
