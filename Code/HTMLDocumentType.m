//  HTMLDocumentType.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocumentType.h"

@implementation HTMLDocumentType

- (id)initWithName:(NSString *)name publicIdentifier:(NSString *)publicIdentifier systemIdentifier:(NSString *)systemIdentifier
{
    self = [super init];
    if (!self) return nil;
    
    _name = [name copy];
    _publicIdentifier = [publicIdentifier copy] ?: @"";
    _systemIdentifier = [systemIdentifier copy] ?: @"";
    
    return self;
}

- (id)init
{
    return [self initWithName:nil publicIdentifier:nil systemIdentifier:nil];
}

- (NSString *)serializedFragment
{
    return [NSString stringWithFormat:@"<!DOCTYPE %@>", self.name];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLDocumentType *copy = [super copyWithZone:zone];
    copy->_name = self.name;
    copy->_publicIdentifier = self.publicIdentifier;
    copy->_systemIdentifier = self.systemIdentifier;
    return copy;
}

@end
