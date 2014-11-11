//  HTMLComment.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLComment.h"

@implementation HTMLComment

- (instancetype)initWithData:(NSString *)data
{
    if ((self = [super init])) {
        _data = [data copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithData:nil];
}

- (NSString *)textContent
{
    return self.data;
}

- (void)setTextContent:(NSString *)textContent
{
    self.data = textContent;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLComment *copy = [super copyWithZone:zone];
    copy->_data = self.data;
    return copy;
}

@end
