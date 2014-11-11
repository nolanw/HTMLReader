//  HTMLParser.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLDocument.h"
#import "HTMLElement.h"

/**
 * An HTMLParser turns a string into an HTMLDocument.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html
 *
 * @see HTMLTokenizer
 */
@interface HTMLParser : NSObject

/**
 * @param string  A string of HTML.
 * @param context A context element used for parsing a fragment of HTML, or nil if the fragment parsing algorithm is not to be used.
 *
 * For more information on the context parameter, see http://www.whatwg.org/specs/web-apps/current-work/multipage/the-end.html#parsing-html-fragments
 */
- (instancetype)initWithString:(NSString *)string context:(HTMLElement *)context NS_DESIGNATED_INITIALIZER;

/**
 * The HTML being parsed.
 */
@property (readonly, copy, nonatomic) NSString *string;

/**
 * Instances of NSString representing the errors encountered while parsing the document.
 */
@property (readonly, copy, nonatomic) NSArray *errors;

/**
 * The parsed document. Lazily created on first access.
 */
@property (readonly, strong, nonatomic) HTMLDocument *document;

@end
