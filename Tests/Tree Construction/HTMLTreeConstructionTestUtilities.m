//
//  HTMLTreeConstructionTestUtilities.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-26.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLTreeConstructionTestUtilities.h"
#import "HTMLTokenizer.h"

NSArray * ReifiedTreeForTestDocument(NSString *document)
{
    NSMutableArray *roots = [NSMutableArray new];
    NSMutableArray *stack = [NSMutableArray new];
    NSCharacterSet *spaceSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [document enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
        NSScanner *scanner = [NSScanner scannerWithString:line];
        scanner.charactersToBeSkipped = nil;
        scanner.caseSensitive = YES;
        if (![scanner scanString:@"| " intoString:nil]) {
            *stop = YES;
            return;
        }
        NSString *spaces;
        if (![scanner scanCharactersFromSet:spaceSet intoString:&spaces]) {
            spaces = nil;
        }
        while (stack.count > spaces.length / 2) {
            [stack removeLastObject];
        }
        HTMLNode *node;
        HTMLElementNode *parentNode = stack.lastObject;
        if ([scanner scanString:@"<!DOCTYPE " intoString:nil]) {
            NSString *name;
            [scanner scanUpToString:@" " intoString:&name];
            if (scanner.isAtEnd) {
                name = [name substringToIndex:name.length - 1];
                node = [[HTMLDocumentTypeNode alloc] initWithName:name publicId:nil systemId:nil];
            } else {
                [scanner scanString:@" \"" intoString:nil];
                NSString *publicId;
                [scanner scanUpToString:@"\" " intoString:&publicId];
                [scanner scanString:@"\" \"" intoString:nil];
                NSString *systemId;
                [scanner scanUpToString:@"\">" intoString:&systemId];
                node = [[HTMLDocumentTypeNode alloc] initWithName:name publicId:publicId systemId:systemId];
            }
        } else if ([scanner scanString:@"<!-- " intoString:nil]) {
            NSString *data;
            if (![scanner scanUpToString:@" -->" intoString:&data]) {
                data = nil;
            }
            node = [[HTMLCommentNode alloc] initWithData:data];
        } else if ([scanner scanString:@"<" intoString:nil]) {
            NSString *tagName;
            if ([scanner scanUpToString:@">" intoString:&tagName]) {
                node = [[HTMLElementNode alloc] initWithTagName:tagName];
            }
        } else if ([scanner scanString:@"\"" intoString:nil]) {
            NSString *data;
            if (![scanner scanUpToString:@"\"" intoString:&data]) {
                data = nil;
            }
            node = [[HTMLTextNode alloc] initWithData:data ?: @""];
        } else {
            // Attribute
            NSString *name, *value;
            if (![scanner scanUpToString:@"=" intoString:&name]) {
                name = nil;
            }
            [scanner scanString:@"=\"" intoString:nil];
            if (![scanner scanUpToString:@"\"" intoString:&value]) {
                value = @"";
            }
            HTMLAttribute *attribute = [[HTMLAttribute alloc] initWithName:name value:value];
            [stack.lastObject addAttribute:attribute];
            return;
        }
        if (!node) return;
        if (stack.count == 0) {
            [roots addObject:node];
        }
        if ([node isKindOfClass:[HTMLElementNode class]]) {
            [stack addObject:node];
        }
        [parentNode appendChild:node];
    }];
    return roots;
}
