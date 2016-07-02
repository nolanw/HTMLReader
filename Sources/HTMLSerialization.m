//  HTMLSerialization.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLSerialization.h"
#import "HTMLComment.h"
#import "HTMLDocument.h"
#import "HTMLDocumentType.h"
#import "HTMLElement.h"
#import "HTMLString.h"
#import "HTMLTextNode.h"

NS_ASSUME_NONNULL_BEGIN

@implementation HTMLNode (Serialization)

- (NSString *)recursiveDescription
{
    NSMutableString *string = [NSMutableString new];
    RecursiveDescriptionHelper(self, string, 0);
    return string;
}

static void RecursiveDescriptionHelper(HTMLNode *self, NSMutableString *string, NSInteger indentLevel)
{
    if (indentLevel > 0) {
        [string appendString:[@"\n|" stringByPaddingToLength:indentLevel * 4 + 2
                                                  withString:@" "
                                             startingAtIndex:0]];
    }
    [string appendString:self.description];
    for (HTMLNode *node in self.children) {
        RecursiveDescriptionHelper(node, string, indentLevel + 1);
    }
}

- (NSString *)innerHTML
{
    NSArray *fragments = [self.children.array valueForKey:@"serializedFragment"];
    return [fragments componentsJoinedByString:@""];
}

- (NSString *)serializedFragment
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

@end

@implementation HTMLComment (Serialization)

- (NSString *)description
{
    NSString *truncatedData = self.data;
    if (truncatedData.length > 37) {
        truncatedData = [[truncatedData substringToIndex:37] stringByAppendingString:@"…"];
    }
    return [NSString stringWithFormat:@"<%@: %p <!-- %@ --> >", self.class, self, truncatedData];
}

- (NSString *)serializedFragment
{
    return [NSString stringWithFormat:@"<!--%@-->", self.data];
}

@end

@implementation HTMLDocument (Serialization)

- (NSString *)serializedFragment
{
    return self.innerHTML;
}

@end

@implementation HTMLDocumentType (Serialization)

- (NSString *)description
{
    NSMutableString *description = [NSMutableString new];
    [description appendFormat:@"<%@: %p <!DOCTYPE", self.class, self];
    
    NSString *name = self.name;
    if (name.length > 0) {
        [description appendFormat:@" %@", name];
    }
    
    NSString *publicIdentifier = self.publicIdentifier;
    NSString *systemIdentifier = self.systemIdentifier;
    if (publicIdentifier.length > 0 || systemIdentifier.length > 0) {
        [description appendFormat:@" \"%@\" \"%@\"", publicIdentifier, systemIdentifier];
    }
    
    [description appendString:@"> >"];
    return description;
}

- (NSString *)serializedFragment
{
    return [NSString stringWithFormat:@"<!DOCTYPE %@>", self.name];
}

@end

@implementation HTMLElement (Serialization)

- (NSString *)description
{
    NSMutableString *description = [NSMutableString new];
    [description appendFormat:@"<%@: %p <", self.class, self];
    
    if (self.htmlNamespace == HTMLNamespaceMathML) {
        [description appendString:@"math "];
    } else if (self.htmlNamespace == HTMLNamespaceSVG) {
        [description appendString:@"svg "];
    }
    
    [description appendString:self.tagName];
    
    [self.attributes enumerateKeysAndObjectsUsingBlock:^(id name, id value, BOOL *stop) {
        [description appendFormat:@" %@=\"%@\"", name, value];
    }];
    
    [description appendFormat:@"> %@ child", @(self.numberOfChildren)];
    if (self.numberOfChildren != 1) {
        [description appendString:@"ren"];
    }
    
    [description appendString:@">"];
    return description;
}

- (NSString *)serializedFragment
{
    NSMutableString *fragment = [NSMutableString new];
    [fragment appendFormat:@"<%@", self.tagName];
    
    [self.attributes enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
        if ([name isEqualToString:@"xmlns:xmlns"]) {
            name = @"xmlns";
        }
        if (![value isKindOfClass:[NSString class]]) {
            value = value.description;
        }
        NSMutableString *escapedValue = [value mutableCopy];
        void (^replace)(id, id) = ^(NSString *search, NSString *replace) {
            NSRange range = NSMakeRange(0, escapedValue.length);
            [escapedValue replaceOccurrencesOfString:search withString:replace options:0 range:range];
        };
        replace(@"&", @"&amp;");
        replace(@"\u00A0", @"&nbsp;");
        replace(@"\"", @"&quot;");
        [fragment appendFormat:@" %@=\"%@\"", name, escapedValue];
    }];

    [fragment appendString:@">"];
    
    if (StringIsEqualToAnyOf(self.tagName, @"area", @"base", @"basefont", @"bgsound", @"br", @"col", @"embed", @"frame", @"hr", @"img", @"input", @"keygen", @"link", @"menuitem", @"meta", @"param", @"source", @"track", @"wbr")) {
        return fragment;
    }
    
    if (StringIsEqualToAnyOf(self.tagName, @"pre", @"textarea", @"listing")) {
        if ([self.children.firstObject isKindOfClass:[HTMLTextNode class]]) {
            HTMLTextNode *textNode = (HTMLTextNode *)self.children.firstObject;
            if ([textNode.data hasPrefix:@"\n"]) {
                [fragment appendString:@"\n"];
            }
        }
    }
    
    [fragment appendString:self.innerHTML];
    [fragment appendFormat:@"</%@>", self.tagName];
    return fragment;
}

@end

@implementation HTMLTextNode (Serialization)

- (NSString *)description
{
    NSString *truncatedData = self.data;
    if (truncatedData.length > 37) {
        truncatedData = [[truncatedData substringToIndex:37] stringByAppendingString:@"…"];
    }
    return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, truncatedData];
}

- (NSString *)serializedFragment
{
    NSString *parentTagName = self.parentElement.tagName;
    if (StringIsEqualToAnyOf(parentTagName, @"style", @"script", @"xmp", @"iframe", @"noembed", @"noframes", @"plaintext", @"noscript")) {
        return self.data;
    } else {
        NSString *escaped = [self.data stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"\u00A0" withString:@"&nbsp;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
        escaped = [escaped stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
        return escaped;
    }
}

@end

NS_ASSUME_NONNULL_END
