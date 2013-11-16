//  HTMLString.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "HTMLString.h"

inline void AppendLongCharacter(NSMutableString *self, UTF32Char character)
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
