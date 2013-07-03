//
//  HTMLAttribute.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTMLUnicode.h"

@interface HTMLAttribute : NSObject

// Designated initializer.
- (id)initWithName:(NSString *)name value:(NSString *)value;

@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSString *value;

- (void)appendCodePointToName:(unicodepoint)codepoint;
- (void)appendCodePointToValue:(unicodepoint)codepoint;
- (void)appendStringToValue:(NSString *)string;

@end
