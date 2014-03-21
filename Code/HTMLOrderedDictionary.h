//  HTMLOrderedDictionary.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

/**
 * An HTMLOrderedDictionary is a mutable dictionary type that maintains its keys' insertion order.
 */
@interface HTMLOrderedDictionary : NSMutableDictionary

/**
 * Returns the location of a key in the dictionary, or NSNotFound if the key is not present.
 */
- (NSUInteger)indexOfKey:(id)key;

/**
 * Moves or inserts a key in the dictionary, then pairs an object with that key. Throws an exception if either object or key is nil, or if index is out of bounds.
 */
- (void)insertObject:(id)object forKey:(id <NSCopying>)key atIndex:(NSUInteger)index;

/**
 * Returns the key at a particular index in the dictionary. Throws an exception if index is out of bounds.
 */
- (id)objectAtIndexedSubscript:(NSUInteger)index;

/**
 * Returns the key at index 0 in the dictionary, or nil if the dictionary is empty.
 */
- (id)firstKey;

/**
 * Returns the key at index (count - 1) in the dictionary, or nil if the dictionary is empty.
 */
- (id)lastKey;

@end
