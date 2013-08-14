//
//  HTMLDocument.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//

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
