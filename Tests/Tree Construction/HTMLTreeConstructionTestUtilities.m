//
//  HTMLTreeConstructionTestUtilities.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTreeConstructionTestUtilities.h"
#import "HTMLTokenizer.h"

static id NodeOrAttributeFromTestString(NSString *);

NSArray * ReifiedTreeForTestDocument(NSString *document)
{
    NSMutableArray *roots = [NSMutableArray new];
    NSMutableArray *stack = [NSMutableArray new];
    NSCharacterSet *spaceSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    NSScanner *scanner = [NSScanner scannerWithString:document];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    while ([scanner scanString:@"| " intoString:nil]) {
        NSString *spaces;
        [scanner scanCharactersFromSet:spaceSet intoString:&spaces];
        while (stack.count > spaces.length / 2) {
            [stack removeLastObject];
        }
        NSString *nodeString;
        [scanner scanUpToString:@"\n| " intoString:&nodeString];
        id nodeOrAttribute = NodeOrAttributeFromTestString(nodeString);
        if ([nodeOrAttribute isKindOfClass:[HTMLAttribute class]]) {
            [stack.lastObject addAttribute:nodeOrAttribute];
        } else if (stack.count > 0) {
            [stack.lastObject appendChild:nodeOrAttribute];
        } else {
            [roots addObject:nodeOrAttribute];
        }
        if ([nodeOrAttribute isKindOfClass:[HTMLElementNode class]]) {
            [stack addObject:nodeOrAttribute];
        }
        [scanner scanString:@"\n" intoString:nil];
    }
    return roots;
}

static id NodeOrAttributeFromTestString(NSString *s)
{
    NSScanner *scanner = [NSScanner scannerWithString:s];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    if ([scanner scanString:@"<!DOCTYPE " intoString:nil]) {
        NSString *rest;
        [scanner scanUpToString:@">" intoString:&rest];
        if (!rest) {
            return [HTMLDocumentTypeNode new];
        }
        NSScanner *doctypeScanner = [NSScanner scannerWithString:rest];
        doctypeScanner.charactersToBeSkipped = nil;
        doctypeScanner.caseSensitive = YES;
        NSString *name;
        [doctypeScanner scanUpToString:@" " intoString:&name];
        if (doctypeScanner.isAtEnd) {
            return [[HTMLDocumentTypeNode alloc] initWithName:name publicId:nil systemId:nil];
        }
        [doctypeScanner scanString:@" \"" intoString:nil];
        NSString *publicId;
        [doctypeScanner scanUpToString:@"\"" intoString:&publicId];
        [doctypeScanner scanString:@"\" \"" intoString:nil];
        NSRange rangeOfSystemId = (NSRange){
            .location = doctypeScanner.scanLocation,
            .length = doctypeScanner.string.length - doctypeScanner.scanLocation - 1,
        };
        NSString *systemId = [doctypeScanner.string substringWithRange:rangeOfSystemId];
        return [[HTMLDocumentTypeNode alloc] initWithName:name publicId:publicId systemId:systemId];
    } else if ([scanner scanString:@"<!-- " intoString:nil]) {
        NSUInteger endOfData = [s rangeOfString:@" -->" options:NSBackwardsSearch].location;
        NSRange rangeOfData = NSMakeRange(scanner.scanLocation, endOfData - scanner.scanLocation);
        return [[HTMLCommentNode alloc] initWithData:[s substringWithRange:rangeOfData]];
    } else if ([scanner scanString:@"<" intoString:nil]) {
        NSString *tagName;
        [scanner scanUpToString:@">" intoString:&tagName];
        return [[HTMLElementNode alloc] initWithTagName:tagName];
    } else if ([scanner scanString:@"\"" intoString:nil]) {
        NSUInteger endOfData = [s rangeOfString:@"\"" options:NSBackwardsSearch].location;
        NSRange rangeOfData = NSMakeRange(scanner.scanLocation, endOfData - scanner.scanLocation);
        return [[HTMLTextNode alloc] initWithData:[s substringWithRange:rangeOfData]];
    } else {
        NSString *name;
        [scanner scanUpToString:@"=" intoString:&name];
        [scanner scanString:@"=\"" intoString:nil];
        NSUInteger endOfValue = [s rangeOfString:@"\"" options:NSBackwardsSearch].location;
        NSRange rangeOfValue = NSMakeRange(scanner.scanLocation, endOfValue - scanner.scanLocation);
        NSString *value = [s substringWithRange:rangeOfValue];
        return [[HTMLAttribute alloc] initWithName:name value:value];
    }
}
