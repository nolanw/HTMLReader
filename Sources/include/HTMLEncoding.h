//  HTMLEncoding.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns the string encoding labeled according to the WHATWG Encoding Standard. Returns HTMLInvalidStringEncoding() if the label is unknown.
extern NSStringEncoding HTMLStringEncodingForLabel(NSString *label);

/// An invalid NSStringEncoding. Equal to CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingInvalidId).
extern NSStringEncoding HTMLInvalidStringEncoding(void);

NS_ASSUME_NONNULL_END
