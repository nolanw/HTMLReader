//  HTMLSupport.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

#ifndef NS_ENUM
#   define NS_ENUM(_type, _name) _type _name; enum
#endif

#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 40000 && __IPHONE_OS_VERSION_MIN_REQUIRED < 70000) || \
    (__MAC_OS_X_VERSION_MIN_REQUIRED >= 1060 && __MAC_OS_X_VERSION_MIN_REQUIRED < 1090)
@interface NSArray (HTMLFirstObjectSupport)

- (id)firstObject;

@end
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40300 && __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
@interface NSArray (HTMLSubscriptingSupport)

- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;

@end

@interface NSDictionary (HTMLSubscriptingSupport)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key;

@end
#endif
