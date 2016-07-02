//  HTMLDocumentType.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocumentType.h"
#import "HTMLDocument.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLDocumentType

- (instancetype)initWithName:(NSString *)name publicIdentifier:(NSString * __nullable)publicIdentifier systemIdentifier:(NSString * __nullable)systemIdentifier
{
    NSParameterAssert(name);
    
    if ((self = [super init])) {
        _name = [name copy];
        _publicIdentifier = [publicIdentifier copy] ?: @"";
        _systemIdentifier = [systemIdentifier copy] ?: @"";
    }
    return self;
}

- (instancetype)init
{
    return [self initWithName:@"html" publicIdentifier:nil systemIdentifier:nil];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone * __nullable)zone
{
    HTMLDocumentType *copy = [super copyWithZone:zone];
    copy->_name = self.name;
    copy->_publicIdentifier = self.publicIdentifier;
    copy->_systemIdentifier = self.systemIdentifier;
    return copy;
}

@end

NS_ASSUME_NONNULL_END
