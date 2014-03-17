//  HTMLTextNode.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTextNode.h"

@implementation HTMLTextNode
{
    NSMutableString *_data;
}

- (id)init
{
    self = [super init];
    if (!self) return nil;
    
    _data = [NSMutableString new];
    
    return self;
}

- (id)initWithData:(NSString *)data
{
    self = [self init];
    if (!self) return nil;
    [_data setString:data];
    return self;
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
