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

- (HTMLElementNode *)rootNode
{
    for (HTMLElementNode *node in self.childNodes) {
        if ([node isKindOfClass:[HTMLElementNode class]] && [node.tagName isEqualToString:@"html"]) {
            return node;
        }
    }
    return nil;
}

@end
