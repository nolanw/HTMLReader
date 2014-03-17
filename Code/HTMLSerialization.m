//  HTMLSerialization.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLSerialization.h"
#import "HTMLComment.h"
#import "HTMLDocumentType.h"
#import "HTMLElement.h"
#import "HTMLTextNode.h"

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
    for (HTMLNode *node in self.childNodes) {
        RecursiveDescriptionHelper(node, string, indentLevel + 1);
    }
}

- (NSString *)innerHTML
{
    NSArray *fragments = [self.childNodes valueForKey:@"serializedFragment"];
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
    NSString *namespace = @"";
    if (self.namespace == HTMLNamespaceMathML) {
        namespace = @"math ";
    } else if (self.namespace == HTMLNamespaceSVG) {
        namespace = @"svg ";
    }
    NSString *attributes = @"";
    if (self.attributes.count > 0) {
        attributes = [[self.attributes valueForKey:@"keyValueDescription"] componentsJoinedByString:@" "];
        attributes = [@" " stringByAppendingString:attributes];
    }
    return [NSString stringWithFormat:@"<%@: %p <%@%@%@> %@ child node%@>", self.class, self,
            namespace, self.tagName, attributes,
            @(self.childNodeCount), self.childNodeCount == 1 ? @"" : @"s"];
}

- (NSString *)serializedFragment
{
    NSMutableString *string = [NSMutableString stringWithFormat:@"<%@", self.tagName];
    for (HTMLAttribute *attribute in self.attributes) {
        NSString *serializedName = attribute.name;
        if ([attribute isKindOfClass:[HTMLNamespacedAttribute class]]) {
            HTMLNamespacedAttribute *namespacedAttribute = (HTMLNamespacedAttribute *)attribute;
            if (!([namespacedAttribute.prefix isEqualToString:@"xmlns"] &&
                  [namespacedAttribute.name isEqualToString:@"xmlns"])) {
                serializedName = [NSString stringWithFormat:@"%@:%@",
                                  namespacedAttribute.prefix, namespacedAttribute.name];
            }
        }
        NSString *escapedValue = [attribute.value stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
        escapedValue = [escapedValue stringByReplacingOccurrencesOfString:@"\u00A0" withString:@"&nbsp;"];
        escapedValue = [escapedValue stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
        [string appendFormat:@" %@=\"%@\"", serializedName, escapedValue];
    }
    [string appendString:@">"];
    if ([@[ @"area", @"base", @"basefont", @"bgsound", @"br", @"col", @"embed", @"frame", @"hr", @"img", @"input",
            @"keygen", @"link", @"menuitem", @"meta", @"param", @"source", @"track", @"wbr"
            ] containsObject:self.tagName]) {
        return string;
    }
    if ([@[ @"pre", @"textarea", @"listing" ] containsObject:self.tagName]) {
        if ([self.childNodes.firstObject isKindOfClass:[HTMLTextNode class]]) {
            HTMLTextNode *textNode = self.childNodes.firstObject;
            if ([textNode.data hasPrefix:@"\n"]) {
                [string appendString:@"\n"];
            }
        }
    }
    [string appendString:self.innerHTML];
    [string appendFormat:@"</%@>", self.tagName];
    return string;
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
    NSString *parentTagName;
    if ([self.parentNode isKindOfClass:[HTMLElement class]]) {
        parentTagName = ((HTMLElement *)self.parentNode).tagName;
    }
    if ([@[ @"style", @"script", @"xmp", @"iframe", @"noembed", @"noframes", @"plaintext", @"noscript"
            ] containsObject:parentTagName]) {
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
