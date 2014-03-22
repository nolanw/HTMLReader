//  HTMLElement.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLElement.h"
#import "HTMLOrderedDictionary.h"

@implementation HTMLElement
{
    HTMLOrderedDictionary *_attributes;
}

- (id)initWithTagName:(NSString *)tagName attributes:(NSDictionary *)attributes
{
    self = [super init];
    if (!self) return nil;
    
    _tagName = [tagName copy];
    _attributes = [HTMLOrderedDictionary new];
    [_attributes addEntriesFromDictionary:attributes];
    
    return self;
}

- (id)init
{
    return [self initWithTagName:nil attributes:nil];
}

- (NSDictionary *)attributes
{
    return [_attributes copy];
}

- (id)objectForKeyedSubscript:(id)attributeName
{
    return _attributes[attributeName];
}

- (void)setObject:(NSString *)attributeValue forKeyedSubscript:(NSString *)attributeName
{
    _attributes[attributeName] = attributeValue;
}

- (void)removeAttributeWithName:(NSString *)attributeName
{
    [_attributes removeObjectForKey:attributeName];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLElement *copy = [super copyWithZone:zone];
    copy->_tagName = self.tagName;
    copy->_attributes = [_attributes copy];
    return copy;
}

@end
