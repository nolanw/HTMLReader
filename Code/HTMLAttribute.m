//
//  HTMLAttribute.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLAttribute.h"

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

- (void)appendCodePointToName:(unicodepoint)codepoint
{
    AppendCodePoint(_name, codepoint);
}

- (void)appendCodePointToValue:(unicodepoint)codepoint
{
    AppendCodePoint(_value, codepoint);
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
