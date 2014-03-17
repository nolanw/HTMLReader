//  HTMLOrderedDictionary.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

@interface HTMLOrderedDictionary : NSMutableDictionary

- (id)initWithObjects:(const id[])objects forKeys:(const id <NSCopying>[])keys count:(NSUInteger)count;

- (id)initWithCapacity:(NSUInteger)numItems;

- (NSUInteger)count;

- (id)objectForKey:(id)key;

- (NSUInteger)indexOfKey:(id)key;

- (id)firstKey;

- (id)lastKey;

- (void)setObject:(id)object forKey:(id <NSCopying>)key;

- (void)removeObjectForKey:(id)key;

- (void)insertObject:(id)object forKey:(id <NSCopying>)key atIndex:(NSUInteger)index;

- (NSEnumerator *)keyEnumerator;

- (id)objectAtIndexedSubscript:(NSUInteger)index;

@end
