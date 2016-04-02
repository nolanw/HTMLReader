//  HTMLOrderedDictionary.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>
#import "HTMLSupport.h"

NS_ASSUME_NONNULL_BEGIN

#if !__has_feature(objc_generics)
    #define KeyType id
    #define ObjectType id
#endif

/// An HTMLOrderedDictionary is a mutable dictionary type that maintains its keys' insertion order.
@interface HTMLGenericOf(HTMLOrderedDictionary, KeyType, ObjectType) : HTMLGenericOf(NSMutableDictionary, KeyType, ObjectType)

/// Initializes an empty ordered dictionary. The capacity is a hint to help with initial memory allocation.
- (instancetype)initWithCapacity:(NSUInteger)numItems NS_DESIGNATED_INITIALIZER;

/// Returns the location of a key in the dictionary, or NSNotFound if the key is not present.
- (NSUInteger)indexOfKey:(KeyType)key;

/// Moves or inserts a key in the dictionary, then pairs an object with that key. Throws an exception if either object or key is nil, or if index is out of bounds.
- (void)insertObject:(ObjectType)object forKey:(KeyType <NSCopying>)key atIndex:(NSUInteger)index;

/// Returns the key at a particular index in the dictionary. Throws an exception if index is out of bounds.
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)index;

/// Returns the key at index 0 in the dictionary, or nil if the dictionary is empty.
@property (readonly, nonatomic) KeyType __nullable firstKey;

/// Returns the key at index (count - 1) in the dictionary, or nil if the dictionary is empty.
@property (readonly, nonatomic) KeyType __nullable lastKey;

@end

#if !__has_feature(objc_generics)
    #undef KeyType
    #undef ObjectType
#endif

NS_ASSUME_NONNULL_END
