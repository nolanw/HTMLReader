//  HTMLAttribute.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLAttribute.h"
#import "HTMLString.h"

@implementation HTMLAttribute
{
    NSMutableString *_name;
    NSMutableString *_value;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    _name = [NSMutableString new];
    _value = [NSMutableString new];
    return self;
}

- (id)initWithName:(NSString *)name value:(NSString *)value
{
    if (!(self = [self init])) return nil;
    [_name setString:name];
    [_value setString:value];
    return self;
}

- (NSString *)name
{
    return [_name copy];;
}

- (NSString *)value
{
    return [_value copy];
}

- (void)setValue:(NSString *)value
{
    [_value setString:value];
}

- (void)appendLongCharacterToName:(UTF32Char)character
{
    AppendLongCharacter(_name, character);
}

- (void)appendLongCharacterToValue:(UTF32Char)character
{
    AppendLongCharacter(_value, character);
}

- (void)appendStringToValue:(NSString *)string
{
    [_value appendString:string];
}

- (NSString *)keyValueDescription
{
    return [NSString stringWithFormat:@"%@='%@'", self.name, self.value];
}

#pragma mark NSObject

- (BOOL)isEqual:(HTMLAttribute *)other
{
    return ([other isKindOfClass:[HTMLAttribute class]] &&
            [other.name isEqualToString:self.name] &&
            [other.value isEqualToString:self.value]);
}

- (NSUInteger)hash
{
    return self.name.hash + self.value.hash;
}

@end

@implementation HTMLNamespacedAttribute

- (id)initWithPrefix:(NSString *)prefix name:(NSString *)name value:(NSString *)value
{
    if (!(self = [super initWithName:name value:value])) return nil;
    _prefix = [prefix copy];
    return self;
}

#pragma mark HTMLAttribute

- (NSString *)keyValueDescription
{
    return [NSString stringWithFormat:@"'%@ %@'='%@'", self.prefix, self.name, self.value];
}

@end
