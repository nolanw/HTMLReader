//  HTMLString.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLString.h"

void AppendLongCharacter(NSMutableString *self, UTF32Char character)
{
    unichar surrogates[2];
    Boolean two = CFStringGetSurrogatePairForLongCharacter(character, surrogates);
    CFStringAppendCharacters((__bridge CFMutableStringRef)self, surrogates, two ? 2 : 1);
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

NSString * StringWithLongCharacter(UTF32Char character)
{
    unichar surrogates[2];
    if (CFStringGetSurrogatePairForLongCharacter(character, surrogates)) {
        return [NSString stringWithFormat:@"%C%C", surrogates[0], surrogates[1]];
    } else {
        return [NSString stringWithFormat:@"%C", surrogates[0]];
    }
}

BOOL is_whitespace(UTF32Char c)
{
    return c == '\t' || c == '\n' || c == '\f' || c == ' ';
}

BOOL is_undefined_or_disallowed(UTF32Char c)
{
    return ((c >= 0x0001 && c <= 0x0008) ||
            (c >= 0x000E && c <= 0x001F) ||
            (c >= 0x007F && c <= 0x009F) ||
            (c >= 0xFDD0 && c <= 0xFDEF) ||
            c == 0x000B ||
            c == 0xFFFE ||
            c == 0xFFFF ||
            c == 0x1FFFE ||
            c == 0x1FFFF ||
            c == 0x2FFFE ||
            c == 0x2FFFF ||
            c == 0x3FFFE ||
            c == 0x3FFFF ||
            c == 0x4FFFE ||
            c == 0x4FFFF ||
            c == 0x5FFFE ||
            c == 0x5FFFF ||
            c == 0x6FFFE ||
            c == 0x6FFFF ||
            c == 0x7FFFE ||
            c == 0x7FFFF ||
            c == 0x8FFFE ||
            c == 0x8FFFF ||
            c == 0x9FFFE ||
            c == 0x9FFFF ||
            c == 0xAFFFE ||
            c == 0xAFFFF ||
            c == 0xBFFFE ||
            c == 0xBFFFF ||
            c == 0xCFFFE ||
            c == 0xCFFFF ||
            c == 0xDFFFE ||
            c == 0xDFFFF ||
            c == 0xEFFFE ||
            c == 0xEFFFF ||
            c == 0xFFFFE ||
            c == 0xFFFFF ||
            c == 0x10FFFE ||
            c == 0x10FFFF);
}
