//  HTMLElement.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLNode.h"

/**
 * An HTMLElementNode represents a parsed element.
 */
@interface HTMLElement : HTMLNode

/**
 * Returns an initialized HTMLElementNode. This is the designated initializer.
 *
 * @param tagName The name of this element.
 */
- (id)initWithTagName:(NSString *)tagName;

/**
 * This element's name.
 */
@property (readonly, copy, nonatomic) NSString *tagName;

/**
 * This element's attributes.
 */
@property (readonly, copy, nonatomic) NSArray *attributes;

/**
 * Returns an attribute on this element, or nil if no matching element is found.
 *
 * @param name The name of the attribute to return.
 */
- (HTMLAttribute *)attributeNamed:(NSString *)name;

/**
 * Returns the value of the attribute named `key`, or nil if no such value exists.
 *
 * Attributes by default have a value of the empty string.
 */
- (id)objectForKeyedSubscript:(id)key;

/**
 * This element's namespace.
 */
@property (readonly, assign, nonatomic) HTMLNamespace namespace;

@end

@interface HTMLElement (Mutability)

/**
 * Add an attribute to this element.
 *
 * @param attribute The attribute to add.
 */
- (void)addAttribute:(HTMLAttribute *)attribute;

/**
 * Get or set this element's namespace.
 */
@property (assign, nonatomic) HTMLNamespace namespace;

@end
