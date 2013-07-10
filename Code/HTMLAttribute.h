//
//  HTMLAttribute.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HTMLAttribute : NSObject

// Designated initializer.
- (id)initWithName:(NSString *)name value:(NSString *)value;

@property (readonly, copy, nonatomic) NSString *name;
@property (readonly, copy, nonatomic) NSString *value;

- (void)appendLongCharacterToName:(UTF32Char)character;
- (void)appendLongCharacterToValue:(UTF32Char)character;
- (void)appendStringToValue:(NSString *)string;

@end
