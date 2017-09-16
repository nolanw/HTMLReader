//  NSString+HTMLEntities.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import "NSString+HTMLEntities.h"
#import "HTMLEntities.h"
#import "HTMLString.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSString (HTMLEntities)

- (NSString *)html_stringByEscapingForHTML
{
    NSMutableString *escaped = [self mutableCopy];
    void (^replace)(NSString *, NSString *) = ^(NSString *find, NSString *replace) {
        [escaped replaceOccurrencesOfString:find withString:replace options:0 range:NSMakeRange(0, escaped.length)];
    };
    replace(@"&", @"&amp;");
    replace(@"\u00A0", @"&nbsp;");
    replace(@"\"", @"&quot;");
    replace(@"<", @"&lt;");
    replace(@">", @"&gt;");
    return escaped;
}

- (NSString *)html_stringByUnescapingHTML
{
    NSRange ampersand = [self rangeOfString:@"&" options:NSBackwardsSearch];
    if (ampersand.location == NSNotFound || NSMaxRange(ampersand) == self.length) return self;
    
    // These are expensive to create, so we'll lazily create them once per unescaping operation.
    NSCharacterSet *decimalDigitCharacterSet;
    NSCharacterSet *hexadecimalDigitCharacterSet;
    
    NSRange searchRange = NSMakeRange(0, self.length);
    NSScanner *scanner = [NSScanner scannerWithString:self];
    NSMutableString *unescaped = [self mutableCopy];
    do {
        searchRange.length = ampersand.location;
        
        NSString *replacement;
        
        // Numeric entity.
        scanner.scanLocation = NSMaxRange(ampersand);
        if ([scanner scanString:@"#" intoString:nil]) {
            
            UInt32 entity;
            
            // Hex number.
            if ([scanner scanString:@"x" intoString:nil]) {
                if (!hexadecimalDigitCharacterSet) {
                    hexadecimalDigitCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
                }
                NSString *entityString;
                if ([scanner scanCharactersFromSet:hexadecimalDigitCharacterSet intoString:&entityString]) {
                    NSScanner *hexScanner = [NSScanner scannerWithString:entityString];
                    unsigned int hex;
                    [hexScanner scanHexInt:&hex];
                    entity = hex;
                } else {
                    continue;
                }
            }
            
            // Decimal number.
            else {
                if (!decimalDigitCharacterSet) {
                    decimalDigitCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
                }
                NSString *entityString;
                if ([scanner scanCharactersFromSet:decimalDigitCharacterSet intoString:&entityString]) {
                    NSInteger decimal = entityString.integerValue;
                    if (decimal > 0x10FFFF) {
                        entity = UINT32_MAX;
                    } else {
                        entity = (UInt32)decimal;
                    }
                } else {
                    continue;
                }
            }
            
            UTF32Char win1252Replacement = ReplacementForNumericEntity(entity);
            if (win1252Replacement) {
                entity = win1252Replacement;
            }
            
            if ((entity >= 0xD800 && entity <= 0xDFFF) || entity > 0x10FFFF) {
                entity = 0xFFFD;
            }
            
            replacement = StringWithLongCharacter(entity);
            
            // Optional semicolon.
            [scanner scanString:@";" intoString:nil];
        }
        
        // Named entity.
        else {
            NSRange nameRange = NSMakeRange(NSMaxRange(ampersand), LongestEntityNameLength);
            if (NSMaxRange(nameRange) > self.length) {
                nameRange.length = self.length - nameRange.location;
            }
            NSString *nameString = [self substringWithRange:nameRange];
            NSString *parsedEntity;
            replacement = StringForNamedEntity(nameString, &parsedEntity);
            if (replacement) {
                [scanner scanString:parsedEntity intoString:nil];
            } else {
                continue;
            }
        }
        
        [unescaped replaceCharactersInRange:NSMakeRange(ampersand.location, scanner.scanLocation - ampersand.location) withString:replacement];
    } while ((ampersand = [self rangeOfString:@"&" options:NSBackwardsSearch range:searchRange]).location != NSNotFound);
    return unescaped;
}

@end

NS_ASSUME_NONNULL_END
