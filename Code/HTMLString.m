//
//  HTMLString.m
//  HTMLReader
//
//  Created by Nolan Waite on 2013-07-02.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLString.h"

inline void AppendLongCharacter(NSMutableString *self, UTF32Char character)
{
    unichar surrogates[2];
    if (CFStringGetSurrogatePairForLongCharacter(character, surrogates)) {
        [self appendFormat:@"%C%C", surrogates[0], surrogates[1]];
    } else {
        [self appendFormat:@"%C", surrogates[0]];
    }
}

void EnumerateLongCharacters(NSString *self, void (^block)(UTF32Char character))
{
    CFStringInlineBuffer buffer;
    CFIndex length = self.length;
    if (length == 0) return;
    CFStringInitInlineBuffer((__bridge CFStringRef)self, &buffer, CFRangeMake(0, length));
    unichar highSurrogate = 0;
    for (CFIndex i = 0; i < length; i++) {
        unichar character = CFStringGetCharacterFromInlineBuffer(&buffer, i);
        if (highSurrogate) {
            if (CFStringIsSurrogateLowCharacter(character)) {
                block(CFStringGetLongCharacterForSurrogatePair(highSurrogate, character));
            } else {
                block(highSurrogate);
                block(character);
            }
            highSurrogate = 0;
        } else if (CFStringIsSurrogateHighCharacter(character) && i < length - 1) {
            highSurrogate = character;
        } else {
            block(character);
        }
    }
}
