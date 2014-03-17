//  HTMLComment.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLComment.h"

@implementation HTMLComment

- (id)initWithData:(NSString *)data
{
    self = [super init];
    if (!self) return nil;
    
    _data = [data copy];
    
    return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLComment *copy = [super copyWithZone:zone];
    copy->_data = self.data;
    return copy;
}

@end
