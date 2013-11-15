//  HTMLAttribute.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

/**
 * HTMLAttribute instances represent a key-value pair attached to an HTMLElementNode.
 */
@interface HTMLAttribute : NSObject

// Designated initializer.

/**
 * Returns an initialized HTMLAttribute. This is the designated initializer.
 *
 * @param name The attribute's name.
 * @param value The attribute's value.
 */
- (id)initWithName:(NSString *)name value:(NSString *)value;

/**
 * The attribute's name.
 */
@property (readonly, copy, nonatomic) NSString *name;

/**
 * The attribute's value.
 */
@property (readonly, copy, nonatomic) NSString *value;

@end

/**
 * HTMLNamespacedAttribute represents an attribute within an XML namespace.
 */
@interface HTMLNamespacedAttribute : HTMLAttribute

/**
 * Returns an initialized HTMLNamespacedAttribute. This is the designated initializer.
 *
 * @param prefix The namespace prefix. Nothing is done with this prefix against any particular schema.
 * @param name The attribute's name.
 * @param value The attribute's value.
 */
- (id)initWithPrefix:(NSString *)prefix name:(NSString *)name value:(NSString *)value;

/**
 * The attribute namespace's prefix.
 */
@property (readonly, copy, nonatomic) NSString *prefix;

@end
