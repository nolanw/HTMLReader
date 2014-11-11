//  HTMLTextNode.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTextNode.h"

@implementation HTMLTextNode
{
    NSMutableString *_data;
}

- (instancetype)initWithData:(NSString *)data
{
    if ((self = [super init])) {
        _data = [NSMutableString stringWithString:data];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithData:@""];
}

- (void)appendString:(NSString *)string
{
    [_data appendString:string];
}

- (NSString *)data
{
    return [_data copy];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLTextNode *copy = [super copyWithZone:zone];
    [copy->_data setString:_data];
    return copy;
}

@end
