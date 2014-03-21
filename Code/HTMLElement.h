//  HTMLElement.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLElement represents a subtree of content in an HTML document.
 *
 * For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/elements.html#elements
 */
@interface HTMLElement : HTMLNode

/**
 * This is the designated initializer.
 *
 * @param tagName    What kind of element to make.
 * @param attributes A dictionary of attributes to start the element off. May be nil.
 */
- (id)initWithTagName:(NSString *)tagName attributes:(NSDictionary *)attributes;

/**
 * The element's kind.
 */
@property (readonly, copy, nonatomic) NSString *tagName;

/**
 * The element's attributes.
 *
 * The attributes' sort order is stable when serialized. (This is required by the spec, but is not guaranteed by NSDictionary.)
 *
 * @see -objectForKeyedSubscript:
 * @see -setObject:forKeyedSubscript:
 * @see -removeAttributeWithName:
 */
@property (readonly, copy, nonatomic) NSDictionary *attributes;

/**
 * Returns the value of the named attribute, or nil if no such value exists.
 */
- (id)objectForKeyedSubscript:(id)attributeNameOrString;

/**
 * Sets a named attribute's value, adding it to the element if needed.
 */
- (void)setObject:(NSString *)attributeValue forKeyedSubscript:(NSString *)attributeName;

/**
 * Removes the named attribute from the element.
 */
- (void)removeAttributeWithName:(NSString *)attributeName;

/**
 * This element's namespace.
 */
@property (assign, nonatomic) HTMLNamespace namespace;

@end
