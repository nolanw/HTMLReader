//
//  HTMLNode.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLAttribute.h"

// Property and method names for these classes follow the DOM specification and do not attempt to follow Objective-C conventions.

@interface HTMLNode : NSObject <NSCopying>

@property (readonly, nonatomic) HTMLNode *parentNode;
@property (readonly, nonatomic) NSArray *childNodes;
- (void)appendChild:(HTMLNode *)child;
- (void)insertChild:(HTMLNode *)child atIndex:(NSUInteger)index;
- (void)removeChild:(HTMLNode *)child;

@end

@interface HTMLElementNode : HTMLNode

// Designated initializer.
- (id)initWithTagName:(NSString *)tagName;

@property (readonly, nonatomic) NSString *tagName;

@property (readonly, nonatomic) NSArray *attributes;
- (void)addAttribute:(HTMLAttribute *)attribute;;

@end

@interface HTMLTextNode : HTMLNode

- (id)initWithData:(NSString *)data;

- (void)appendLongCharacter:(UTF32Char)character;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLCommentNode : HTMLNode

- (id)initWithData:(NSString *)data;

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLDocumentTypeNode : HTMLNode

- (id)initWithName:(NSString *)name publicId:(NSString *)publicId systemId:(NSString *)systemId;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *publicId;
@property (readonly, nonatomic) NSString *systemId;

@end
