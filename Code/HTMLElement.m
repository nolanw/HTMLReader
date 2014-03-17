//  HTMLElement.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLElement.h"

@interface HTMLElement ()

@property (assign, nonatomic) HTMLNamespace namespace;

@end

@implementation HTMLElement
{
    NSMutableArray *_attributes;
}

- (id)initWithTagName:(NSString *)tagName
{
    self = [super init];
    if (!self) return nil;
    
    _tagName = [tagName copy];
    _attributes = [NSMutableArray new];
    
    return self;
}

- (id)init
{
    return [self initWithTagName:nil];
}

#pragma mark Element Attributes

- (NSArray *)attributes
{
    return [_attributes copy];
}

- (void)addAttribute:(HTMLAttribute *)attribute
{
    [_attributes addObject:attribute];
}

- (HTMLAttribute*)attributeNamed:(NSString*)name
{
	for (HTMLAttribute *attribute in _attributes)
	{
		if ([[attribute name] compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame)
		{
			return attribute;
		}
	}
	
	return nil;
}

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self attributeNamed:key].value;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    HTMLElement *copy = [super copyWithZone:zone];
    copy->_tagName = self.tagName;
    copy->_attributes = [NSMutableArray arrayWithArray:_attributes];
    return copy;
}

@end
