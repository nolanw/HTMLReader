//
//  HTMLUnicode.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLUnicode.h"

inline BOOL RequiresSurrogatePair(unicodepoint codepoint)
{
    return codepoint >= 0x10000 && codepoint <= 0x10FFFF;
}

inline unichar LeadSurrogate(unicodepoint codepoint)
{
    return ((codepoint - 0x10000) >> 10) + 0xD800;
}

inline unichar TrailSurrogate(unicodepoint codepoint)
{
    return ((codepoint - 0x10000) & 0x3FF) + 0xDC00;
}

// NSString has a format specifier for unichar, but nothing for a Unicode code point.
// (While this would be a useful method to put in a category on NSMutableString, libraries should not pollute Foundation classes (even) with (prefixed) methods.)
void AppendCodePoint(NSMutableString *self, unicodepoint codepoint)
{
    if (RequiresSurrogatePair(codepoint)) {
        [self appendFormat:@"%C%C", LeadSurrogate(codepoint), TrailSurrogate(codepoint)];
    } else if (codepoint <= 0xFFFF) {
        [self appendFormat:@"%C", (unichar)codepoint];
    } else {
        [self appendString:@"\uFFFD"];
    }
}
