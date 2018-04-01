//  HTMLElement.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLElement.h"
#import "HTMLOrderedDictionary.h"
#import "HTMLSelector.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLElement
{
    HTMLOrderedDictionary *_attributes;
}

- (instancetype)initWithTagName:(NSString *)tagName attributes:(HTMLDictOf(NSString *, NSString *) * __nullable)attributes
{
    NSParameterAssert(tagName);
    
    if ((self = [super init])) {
        _tagName = [tagName copy];
        _attributes = [HTMLOrderedDictionary new];
        if (attributes) {
            [_attributes addEntriesFromDictionary:(NSDictionary * __nonnull)attributes];
        }
    }
    return self;
}

- (instancetype)init
{
    return [self initWithTagName:@"" attributes:nil];
}

- (HTMLDictOf(NSString *, NSString *) *)attributes
{
    return [_attributes copy];
}

- (id __nullable)objectForKeyedSubscript:(id)attributeName
{
    return [_attributes objectForKey:attributeName];
}

- (void)setObject:(NSString *)attributeValue forKeyedSubscript:(NSString *)attributeName
{
    NSParameterAssert(attributeValue);

    [_attributes setObject:attributeValue forKey:attributeName];
}

- (void)removeAttributeWithName:(NSString *)attributeName
{
    [_attributes removeObjectForKey:attributeName];
}

- (BOOL)hasClass:(NSString *)className
{
    NSParameterAssert(className);
    
    NSArray *classes = [self[@"class"] componentsSeparatedByCharactersInSet:HTMLSelectorWhitespaceCharacterSet()];
    return [classes containsObject:className];
}

- (void)toggleClass:(NSString *)className
{
    NSParameterAssert(className);
    
    NSString *classValue = self[@"class"] ?: @"";
    NSMutableArray *classes = [[classValue componentsSeparatedByCharactersInSet:HTMLSelectorWhitespaceCharacterSet()] mutableCopy];
    NSUInteger i = [classes indexOfObject:className];
    if (i == NSNotFound) {
        [classes addObject:className];
    } else {
        [classes removeObjectAtIndex:i];
    }
    self[@"class"] = [classes componentsJoinedByString:@" "];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone * __nullable)zone
{
    HTMLElement *copy = [super copyWithZone:zone];
    copy->_tagName = self.tagName;
    copy->_attributes = [_attributes copy];
    return copy;
}

@end

NS_ASSUME_NONNULL_END
