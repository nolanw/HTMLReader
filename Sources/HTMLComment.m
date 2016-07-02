//  HTMLComment.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLComment.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLComment

- (instancetype)initWithData:(NSString *)data
{
    NSParameterAssert(data);
    
    if ((self = [super init])) {
        _data = [data copy];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithData:@""];
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

- (id)copyWithZone:(NSZone * __nullable)zone
{
    HTMLComment *copy = [super copyWithZone:zone];
    copy->_data = self.data;
    return copy;
}

@end

NS_ASSUME_NONNULL_END
