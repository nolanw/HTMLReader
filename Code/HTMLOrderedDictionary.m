//  HTMLOrderedDictionary.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLOrderedDictionary.h"

@implementation HTMLOrderedDictionary
{
    NSMapTable *_map;
    NSMutableArray *_keys;
}

- (id)initWithCapacity:(NSUInteger)numItems
{
    self = [super init];
    if (!self) return nil;
    
    _map = [NSMapTable strongToStrongObjectsMapTable];
    _keys = [NSMutableArray arrayWithCapacity:numItems];
    
    return self;
}

- (id)initWithObjects:(const id [])objects forKeys:(const id <NSCopying> [])keys count:(NSUInteger)count
{
    self = [self initWithCapacity:count];
    if (!self) return nil;
    
    for (NSUInteger i = 0; i < count; i++) {
        id object = objects[i];
        id key = keys[i];
        
        if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];
        if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];
        
        self[keys[i]] = objects[i];
    }
    
    return self;
}

- (id)init
{
    return [self initWithCapacity:0];
}

- (id)initWithCoder:(NSCoder *)coder
{
    NSMapTable *map = [coder decodeObjectForKey:@"map"];
    NSArray *keys = [coder decodeObjectForKey:@"keys"];
    HTMLOrderedDictionary *dictionary = [self initWithCapacity:keys.count];
    for (id key in keys) {
        dictionary[key] = [map objectForKey:key];
    }
    return dictionary;
}

- (Class)classForKeyedArchiver
{
    return [self class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_map forKey:@"map"];
    [coder encodeObject:_keys forKey:@"keys"];
}

- (id)copyWithZone:(NSZone *)zone
{
    HTMLOrderedDictionary *copy = [[[self class] allocWithZone:zone] initWithCapacity:self.count];
    [copy addEntriesFromDictionary:self];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [self copyWithZone:zone];
}

- (NSUInteger)count
{
    return _keys.count;
}

- (id)objectForKey:(id)key
{
    return [_map objectForKey:key];
}

- (NSUInteger)indexOfKey:(id)key
{
    if ([_map objectForKey:key]) {
        return [_keys indexOfObject:key];
    } else {
        return NSNotFound;
    }
}

- (id)firstKey
{
    return _keys.firstObject;
}

- (id)lastKey
{
    return _keys.lastObject;
}

- (void)setObject:(id)object forKey:(id)key
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    [self insertObject:object forKey:key atIndex:self.count];
}

- (void)removeObjectForKey:(id)key
{
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    if ([_map objectForKey:key]) {
        [_map removeObjectForKey:key];
        [_keys removeObject:key];
    }
}

- (void)insertObject:(id)object forKey:(id)key atIndex:(NSUInteger)index
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    if (index > self.count) [NSException raise:NSRangeException format:@"%@ index %@ beyond count %@ of array", NSStringFromSelector(_cmd), @(index), @(self.count)];
    
    if (![_map objectForKey:key]) {
        key = [key copy];
        [_keys insertObject:key atIndex:index];
    }
    [_map setObject:object forKey:key];
}

- (NSEnumerator *)keyEnumerator
{
    return _keys.objectEnumerator;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return _keys[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len
{
    return [_keys countByEnumeratingWithState:state objects:buffer count:len];
}

@end
