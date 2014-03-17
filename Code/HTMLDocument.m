//  HTMLDocument.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLDocument.h"
#import "HTMLParser.h"

@implementation HTMLDocument

+ (instancetype)documentWithString:(NSString *)string
{
    return [[HTMLParser alloc] initWithString:string].document;
}

- (HTMLElement *)rootElement
{
    for (HTMLElement *node in self.childNodes) {
        if ([node isKindOfClass:[HTMLElement class]] && [node.tagName isEqualToString:@"html"]) {
            return node;
        }
    }
    return nil;
}

@end
