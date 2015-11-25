//  HTMLOrderedDictionary.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLOrderedDictionary.h"

NS_ASSUME_NONNULL_BEGIN

#if !__has_feature(objc_generic)
    #define KeyType id
    #define ObjectType id
#endif

@implementation HTMLOrderedDictionary
{
    CFMutableDictionaryRef _map;
    HTMLGenericOf(NSMutableArray, KeyType) *_keys;
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
- (instancetype)initWithObjects:(const ObjectType [])objects forKeys:(const KeyType <NSCopying> [])keys count:(NSUInteger)count
#pragma clang diagnostic pop
{
    if ((self = [self initWithCapacity:count])) {
        for (NSUInteger i = 0; i < count; i++) {
            id object = objects[i];
            id key = keys[i];
            
            if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];
            if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key at %@ cannot be nil", NSStringFromSelector(_cmd), @(i)];
            
            self[keys[i]] = objects[i];
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
        dictionary[key] = map[key];
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

- (ObjectType __nullable)objectForKey:(KeyType)key
{
    NSParameterAssert(key);
    
    return (__bridge id)CFDictionaryGetValue(_map, (__bridge const void *)key);
}

- (NSUInteger)indexOfKey:(KeyType)key
{
    if ([self objectForKey:key]) {
        return [_keys indexOfObject:key];
    } else {
        return NSNotFound;
    }
}

- (__nullable KeyType)firstKey
{
    return _keys.firstObject;
}

- (__nullable KeyType)lastKey
{
    return _keys.lastObject;
}

- (void)setObject:(ObjectType)object forKey:(KeyType)key
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    [self insertObject:object forKey:key atIndex:self.count];
}

- (void)removeObjectForKey:(KeyType)key
{
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    
    if ([self objectForKey:key]) {
        CFDictionaryRemoveValue(_map, (__bridge const void *)key);
        [_keys removeObject:key];
    }
}

- (void)insertObject:(ObjectType)object forKey:(KeyType)key atIndex:(NSUInteger)index
{
    if (!object) [NSException raise:NSInvalidArgumentException format:@"%@ object cannot be nil", NSStringFromSelector(_cmd)];
    if (!key) [NSException raise:NSInvalidArgumentException format:@"%@ key cannot be nil", NSStringFromSelector(_cmd)];
    if (index > self.count) [NSException raise:NSRangeException format:@"%@ index %@ beyond count %@ of array", NSStringFromSelector(_cmd), @(index), @(self.count)];
    
    if (![self objectForKey:key]) {
        key = [key copy];
        [_keys insertObject:key atIndex:index];
    }
    CFDictionarySetValue(_map, (__bridge const void *)key, (__bridge const void *)object);
}

- (HTMLEnumeratorOf(KeyType) *)keyEnumerator
{
    return _keys.objectEnumerator;
}

- (ObjectType)objectAtIndexedSubscript:(NSUInteger)index
{
    return _keys[index];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id [])buffer count:(NSUInteger)len
{
    return [_keys countByEnumeratingWithState:state objects:buffer count:len];
}

@end

NS_ASSUME_NONNULL_END
