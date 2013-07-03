//
//  HTMLString.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

// These are internal methods, so they should stay out of categories on Foundation classes.

extern inline void AppendLongCharacter(NSMutableString *self, UTF32Char character);

extern void EnumerateLongCharacters(NSString *self, void (^block)(UTF32Char character));
