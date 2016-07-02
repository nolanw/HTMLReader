//  HTMLTextNode.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLTextNode.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLTextNode
{
    NSMutableString *_data;
}

- (instancetype)initWithData:(NSString *)data
{
    NSParameterAssert(data);
    
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
    NSParameterAssert(string);
    
    [_data appendString:string];
}

- (NSString *)data
{
    return [_data copy];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone * __nullable)zone
{
    HTMLTextNode *copy = [super copyWithZone:zone];
    [copy->_data setString:_data];
    return copy;
}

@end

NS_ASSUME_NONNULL_END
