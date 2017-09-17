//  EncodingLabeler.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

int main(void) { @autoreleasepool
{
    static NSString * const EncodingLabelsURL = @"https://encoding.spec.whatwg.org/encodings.json";
    NSData *data = [NSData dataWithContentsOfURL:(NSURL *)[NSURL URLWithString:EncodingLabelsURL]];
    if (!data) {
        NSLog(@"could not download encoding labels JSON");
        return 1;
    }
    
    NSError *error;
    NSArray *encodingsJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!encodingsJSON) {
        NSLog(@"could not decode encoding labels JSON: %@", error);
        return 1;
    }
    
    NSMutableDictionary *labelsToNames = [NSMutableDictionary new];
    for (NSDictionary *section in encodingsJSON) {
        for (NSDictionary *encodingInfo in section[@"encodings"]) {
            NSString *name = encodingInfo[@"name"];
            for (NSString *label in encodingInfo[@"labels"]) {
                labelsToNames[label] = name;
            }
        }
    }
    
    printf("static const EncodingLabelMap EncodingLabels[] = {\n");
    NSArray *sortedLabels = [labelsToNames.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *label in sortedLabels) {
        NSString *name = labelsToNames[label];
        printf("    { @\"%s\", @\"%s\" },\n", label.UTF8String, name.UTF8String);
    }
    printf("};\n\n");
    
    // Check that we're using valid constants, then stringify them.
    #define cfencoding(name) ({ \
        __unused CFStringEncoding encoding = name; \
        @( #name ); \
    })
    
    NSDictionary *namesToStringEncodings = @
    {
        // I just matched these to constants in CoreFoundation/CFStringEncodingExt.h, using the comments as a guide.
        @"Big5": cfencoding(kCFStringEncodingBig5),
        @"EUC-JP": cfencoding(kCFStringEncodingEUC_JP),
        @"EUC-KR": cfencoding(kCFStringEncodingEUC_KR),
        @"gb18030": cfencoding(kCFStringEncodingGB_18030_2000),
        @"GBK": cfencoding(kCFStringEncodingGBK_95),
        @"IBM866": cfencoding(kCFStringEncodingDOSRussian),
        @"ISO-2022-JP": cfencoding(kCFStringEncodingISO_2022_JP),
        @"ISO-8859-2": cfencoding(kCFStringEncodingISOLatin2),
        @"ISO-8859-3": cfencoding(kCFStringEncodingISOLatin3),
        @"ISO-8859-4": cfencoding(kCFStringEncodingISOLatin4),
        @"ISO-8859-5": cfencoding(kCFStringEncodingISOLatinCyrillic),
        @"ISO-8859-6": cfencoding(kCFStringEncodingISOLatinArabic),
        @"ISO-8859-7": cfencoding(kCFStringEncodingISOLatinGreek),
        @"ISO-8859-8": cfencoding(kCFStringEncodingISOLatinHebrew),
        // Not 100% sure on this one. WHATWG Encoding Standard says "iso-8859-8 and iso-8859-8-i are distinct encoding names, because iso-8859-8 has influence on the layout direction". I don't know if this is relevant for HTMLReader.
        @"ISO-8859-8-I": cfencoding(kCFStringEncodingISOLatinHebrew),
        @"ISO-8859-10": cfencoding(kCFStringEncodingISOLatin6),
        @"ISO-8859-13": cfencoding(kCFStringEncodingISOLatin7),
        @"ISO-8859-14": cfencoding(kCFStringEncodingISOLatin8),
        @"ISO-8859-15": cfencoding(kCFStringEncodingISOLatin9),
        @"ISO-8859-16": cfencoding(kCFStringEncodingISOLatin10),
        @"KOI8-R": cfencoding(kCFStringEncodingKOI8_R),
        @"KOI8-U": cfencoding(kCFStringEncodingKOI8_U),
        @"macintosh": cfencoding(kCFStringEncodingMacRoman),
        // As best I can tell, the replacement character encoding effectively discards the input.
        @"replacement": cfencoding(kCFStringEncodingInvalidId),
        @"Shift_JIS": cfencoding(kCFStringEncodingShiftJIS),
        @"UTF-16BE": cfencoding(kCFStringEncodingUTF16BE),
        @"UTF-16LE": cfencoding(kCFStringEncodingUTF16LE),
        @"UTF-8": cfencoding(kCFStringEncodingUTF8),
        @"windows-874": cfencoding(kCFStringEncodingDOSThai),
        @"windows-1250": cfencoding(kCFStringEncodingWindowsLatin2),
        @"windows-1251": cfencoding(kCFStringEncodingWindowsCyrillic),
        @"windows-1252": cfencoding(kCFStringEncodingWindowsLatin1),
        @"windows-1253": cfencoding(kCFStringEncodingWindowsGreek),
        @"windows-1254": cfencoding(kCFStringEncodingWindowsLatin5),
        @"windows-1255": cfencoding(kCFStringEncodingWindowsHebrew),
        @"windows-1256": cfencoding(kCFStringEncodingWindowsArabic),
        @"windows-1257": cfencoding(kCFStringEncodingWindowsBalticRim),
        @"windows-1258": cfencoding(kCFStringEncodingWindowsVietnamese),
        @"x-mac-cyrillic": cfencoding(kCFStringEncodingMacCyrillic),
        // Assume that the HTML parser correctly handles x-user-defined, we should never be asked about it.
        @"x-user-defined": cfencoding(kCFStringEncodingInvalidId),
    };
    
    #undef cfencoding
    
    printf("static const NameCFEncodingMap StringEncodings[] = {\n");
    NSArray *uniqueNames = [NSSet setWithArray:labelsToNames.allValues].allObjects;
    NSArray *sortedNames = [uniqueNames sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *name in sortedNames) {
        NSString *kEncoding = namesToStringEncodings[name];
        
        if (!kEncoding) {
            NSLog(@"missing CFStringEncoding for encoding named %@", name);
            return 1;
        }
        
        printf("    { @\"%s\", %s },\n", name.UTF8String, kEncoding.UTF8String);
    }
    printf("};\n\n");
    
    return 0;
} }
