//  HTMLElement.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLElementNode represents a parsed element.
 */
@interface HTMLElement : HTMLNode

/**
 * Designated initializer.
 *
 * @param tagName    The name of this element.
 * @param attributes A dictionary of attributes to start the element off. May be nil.
 */
- (id)initWithTagName:(NSString *)tagName attributes:(NSDictionary *)attributes;

/**
 * This element's name.
 */
@property (readonly, copy, nonatomic) NSString *tagName;

/**
 * This element's attributes.
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

- (void)removeAttributeWithName:(NSString *)attributeName;

/**
 * This element's namespace.
 */
@property (assign, nonatomic) HTMLNamespace namespace;

@end
