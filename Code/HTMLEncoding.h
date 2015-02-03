//  HTMLEncoding.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

/**
 * Returns the name of an encoding given by a label, as specified in the WHATWG Encoding standard, or nil if the label has no associated name.
 *
 * For more information, see https://encoding.spec.whatwg.org/#names-and-labels
 */
extern NSString * NamedEncodingForLabel(NSString *label);

/**
 * Returns the string encoding given by a name from the WHATWG Encoding Standard, or the result of CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingInvalidId) if there is no known encoding given by name.
 */
extern NSStringEncoding StringEncodingForName(NSString *name);
