//
//  HTMLTokenizer.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-06-14.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTMLTokenizer : NSEnumerator

// Designated initializer.
- (id)initWithString:(NSString *)string;

@end

@interface HTMLDOCTYPEToken : NSObject

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *publicIdentifier;
@property (readonly, nonatomic) NSString *systemIdentifier;
@property (readonly, nonatomic) BOOL forceQuirks;

@end

@interface HTMLTagToken : NSObject

@property (readonly, nonatomic) NSString *tagName;
@property (readonly, nonatomic) BOOL selfClosing;
@property (readonly, nonatomic) NSArray *attributes;

@end

@interface HTMLStartTagToken : HTMLTagToken

@end

@interface HTMLEndTagToken : HTMLTagToken

@end

@interface HTMLCommentToken : NSObject

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLCharacterToken : NSObject

@property (readonly, nonatomic) NSString *data;

@end

@interface HTMLEndOfFileToken : NSObject

@end

@interface HTMLParseErrorToken : NSObject

@end
