//  HTMLString.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

// These are internal methods, so they should not add anything to any Foundation classes (e.g. by defining categories).

/**
    Append a single Unicode code point to an NSMutableString. This takes care of code points that require the use of surrogate pairs.
 
    @param self The NSMutableString that will get a character.
    @param character The character to append.
 */
extern void AppendLongCharacter(NSMutableString *self, UTF32Char character);

/**
    Execute a block on every Unicode code point in a string. This takes care of code points that require the use of surrogate pairs.
 
    @param self The string whose code points are enumerated.
    @param block The block to execute, which has no return value and takes a code point as its sole parameter.
 */
extern void EnumerateLongCharacters(NSString *self, void (^block)(UTF32Char character));

/// Returns a string consisting solely of the character.
extern NSString * StringWithLongCharacter(UTF32Char character);

/**
    Whether or not the character is a whitespace character.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/common-microsyntaxes.html#space-character
 */
extern BOOL is_whitespace(UTF32Char c);

/**
    Whether or not the character is allowed to be in an HTML document.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/parsing.html#preprocessing-the-input-stream
 */
extern BOOL is_undefined_or_disallowed(UTF32Char c);

/// @return YES if the first parameter is equal to any subsequent parameter, otherwise NO.
#define StringIsEqualToAnyOf(search, ...) ({ \
    NSString *s = (search); \
    __unsafe_unretained NSString *potentials[] = { __VA_ARGS__ }; \
    BOOL found = NO; \
    size_t count = sizeof(potentials) / sizeof(potentials[0]); \
    for (NSUInteger i = 0; i < count; i++) { \
        if ([s isEqualToString:potentials[i]]) { \
            found = YES; \
            break; \
        } \
    } \
    found; \
})
