//  HTMLOrderedDictionary.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLOrderedDictionary
{
    CFMutableDictionaryRef _map;
    NSMutableArray *_keys;
}

- (instancetype)initWithCapacity:(NSUInteger)numItems
{
    if ((self = [super init])) {
        _map = CFDictionaryCreateMutable(nil, numItems, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        _keys = [NSMutableArray arrayWithCapacity:numItems];
    }
    return self;
}

// Diagnostic needs ignoring on iOS 5.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (instancetype)initWithObjects:(const id __nonnull [])objects forKeys:(const id<NSCopying> __nonnull [])keys count:(NSUInteger)count
#pragma clang diagnostic pop
{
    if ((self = [self initWithCapacity:count])) {
        for (NSUInteger i = 0; i < count; i++) {
            id object = objects[i];
            id key = keys[i];
            
            if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];
            if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];

            [self setObject:objects[i] forKey:keys[i]];
        }
    }
    return self;
}

- (id)init
{
    return [self initWithCapacity:0];
}

- (id __nullable)initWithCoder:(NSCoder *)coder
{
    NSDictionary *map = [coder decodeObjectForKey:@"map"];
    NSArray *keys = [coder decodeObjectForKey:@"keys"];
    HTMLOrderedDictionary *dictionary = [self initWithCapacity:keys.count];
    for (id key in keys) {
        [dictionary setObject:(id)[map objectForKey:key] forKey:key];
    }
    return dictionary;
}

- (void)dealloc
{
    CFRelease(_map);
}

- (Class __nullable)classForKeyedArchiver
{
    return [self class];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:(__bridge NSDictionary *)_map forKey:@"map"];
    [coder encodeObject:_keys forKey:@"keys"];
}

- (id)copyWithZone:(NSZone * __nullable)zone
{
    HTMLOrderedDictionary *copy = [[[self class] allocWithZone:zone] initWithCapacity:self.count];
    [copy addEntriesFromDictionary:self];
    return copy;
}

- (id)mutableCopyWithZone:(NSZone * __nullable)zone
{
    return [self copyWithZone:zone];
}

- (NSUInteger)count
{
    return _keys.count;
}

- (id __nullable)objectForKey:(id)key
{
    NSParameterAssert(key);
    
    return (__bridge id)CFDictionaryGetValue(_map, (__bridge const void *)key);
}

- (NSUInteger)indexOfKey:(id)key
{
    if ([self objectForKey:key]) {
        return [_keys indexOfObject:key];
    } else {
        return NSNotFound;
    }
}

- (id __nullable)firstKey
{
    return _keys.firstObject;
}

- (id __nullable)lastKey
{
    return _keys.lastObject;
}

- (void)setObject:(id)object forKey:(id<NSCopying>)key
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    [self insertObject:object forKey:key atIndex:self.count];
}

- (void)removeObjectForKey:(id<NSCopying>)key
{
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    if ([self objectForKey:key]) {
        CFDictionaryRemoveValue(_map, (__bridge const void *)key);
        [_keys removeObject:key];
    }
}

- (void)insertObject:(id)object forKey:(id<NSCopying>)key atIndex:(NSUInteger)index
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    if (index > self.count) [NSException raise:NSRangeException format:@"%@ index %@ beyond count %@ of array", NSStringFromSelector(_cmd), @(index), @(self.count)];
    
    if (![self objectForKey:key]) {
        key = [key copyWithZone:nil];
        [_keys insertObject:key atIndex:index];
    }
    CFDictionarySetValue(_map, (__bridge const void *)key, (__bridge const void *)object);
}

- (NSEnumerator *)keyEnumerator
{
    return _keys.objectEnumerator;
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return [_keys objectAtIndex:index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id __nonnull [])buffer count:(NSUInteger)len
{
    return [_keys countByEnumeratingWithState:state objects:buffer count:len];
}

@end

NS_ASSUME_NONNULL_END
