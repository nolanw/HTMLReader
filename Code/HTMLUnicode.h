//
//  HTMLUnicode.h
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import <Foundation/Foundation.h>

// unichar is defined as a "type for Unicode characters", but it is actually a type for UTF-16 code units. We need a type for a Unicode code *point*.
typedef uint32_t unicodepoint;

// UTF-16 encodes code points U+10000 to U+10FFFF using surrogate pairs. NSString has few affordances for this, so we do much of it ourselves. These are some utility functions.
extern inline BOOL RequiresSurrogatePair(unicodepoint codepoint);
extern inline unichar LeadSurrogate(unicodepoint codepoint);
extern inline unichar TrailSurrogate(unicodepoint codepoint);

// NSString has a format specifier for unichar, but nothing for a Unicode code point.
// (While this would be a useful method to put in a category on NSMutableString, libraries should not pollute Foundation classes (even) with (prefixed) methods.)
extern void AppendCodePoint(NSMutableString *self, unicodepoint codepoint);
