//  HTMLSupport.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

// NS_DESIGNATED_INITIALIZER arrived in Xcode 6, but we can use it earlier, and it's handy documentation even when it's unavailable as a compiler attribute.
#ifndef NS_DESIGNATED_INITIALIZER
    #if __has_attribute(objc_designated_initializer)
        #define NS_DESIGNATED_INITIALIZER __attribute((objc_designated_initializer))
    #else
        #define NS_DESIGNATED_INITIALIZER
    #endif
#endif

// instancetype is available circa iOS 6 and OS X 10.8.
#if !__has_feature(objc_instancetype)
    #define instancetype id
#endif

// NS_ENUM was defined circa iOS 6 and OS X 10.8, so we can't count on its presence.
#ifndef NS_ENUM
#   define NS_ENUM(_type, _name) _type _name; enum
#endif

// -[NSArray firstObject] was only publicly exposed in iOS 7 and OS X 10.9, but it was implemented much earlier.
#if (__IPHONE_OS_VERSION_MIN_REQUIRED >= 40000 && __IPHONE_OS_VERSION_MIN_REQUIRED < 70000) || \
    (__MAC_OS_X_VERSION_MIN_REQUIRED >= 1060 && __MAC_OS_X_VERSION_MIN_REQUIRED < 1090)
@interface NSArray (HTMLFirstObjectSupport)

- (id)firstObject;

@end
#endif

// NSArray and NSDictionary have subscripting support via ARCLite, but the compiler wasn't always happily exposing that fact.
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40300 && __IPHONE_OS_VERSION_MAX_ALLOWED < 60000
@interface NSArray (HTMLSubscriptingSupport)

- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;

@end

@interface NSDictionary (HTMLSubscriptingSupport)

- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)object forKeyedSubscript:(id <NSCopying>)key;

@end

@interface NSOrderedSet (HTMLSubscriptingSupport)

- (id)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(id)object atIndexedSubscript:(NSUInteger)index;

@end
#endif
