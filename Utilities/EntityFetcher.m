//  EntityFetcher.m
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

@interface Entity : NSObject

@property (copy, nonatomic) NSString *name;
@property (copy, nonatomic) NSArray *codepoints;

@end

@implementation Entity

- (NSString *)description
{
    NSMutableString *description = [NSMutableString new];
    [description appendFormat:@"{ @\"%@\", @\"", [self.name substringFromIndex:1]];
    for (NSNumber *codepoint in self.codepoints) {
        unsigned int c = codepoint.unsignedIntValue;
        switch (c) {
            case '"':
                [description appendString:@"\\\""];
                break;
            case '\\':
                [description appendString:@"\\\\"];
                break;
            case '\n':
                [description appendString:@"\\n"];
                break;
            case '\t':
                [description appendString:@"\\t"];
                break;
            default:
                if (is_universal(c)) {
                    [description appendFormat:@"\\U%08x", c];
                } else {
                    [description appendFormat:@"%C", (unichar)c];
                }
                break;
        }
    }
    [description appendString:@"\" },"];
    return description;
}

static inline BOOL is_universal(unsigned int c)
{
    // ISO C99 http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1256.pdf
    return c == '$' || c == '@' || c == '`' || (c >= 0xA0 && (c < 0xD800 || c > 0xDFFF));
}

@end

int main(void) { @autoreleasepool
{
    static NSString * const EntitiesURLString = @"http://www.whatwg.org/specs/web-apps/current-work/multipage/entities.json";
    NSURL * const EntitiesURL = [NSURL URLWithString:EntitiesURLString];
    NSData *data = (EntitiesURL) ? [NSData dataWithContentsOfURL:(NSURL * __nonnull)EntitiesURL] : nil;
    if (!data) {
        NSLog(@"could not download entities JSON from %@", EntitiesURL);
        return 1;
    }
    NSError *error;
    NSDictionary *entitiesJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!entitiesJSON) {
        NSLog(@"could not decode entities JSON: %@", error);
        return 1;
    }
    NSMutableArray *entities = [NSMutableArray new];
    NSMutableArray *semicolonlessEntities = [NSMutableArray new];
    NSUInteger longestLength = 0;
    for (NSString *name in entitiesJSON) {
        if (name.length > longestLength) {
            longestLength = name.length;
        }
        Entity *entity = [Entity new];
        entity.name = name;
        NSDictionary *replacement = entitiesJSON[name];
        entity.codepoints = replacement[@"codepoints"];
        if ([name hasSuffix:@";"]) {
            [entities addObject:entity];
        } else {
            [semicolonlessEntities addObject:entity];
        }
    }
    static NSComparator comparator = ^(Entity *a, Entity *b) {
        return [a.name compare:b.name];
    };
    [entities sortUsingComparator:comparator];
    [semicolonlessEntities sortUsingComparator:comparator];
    
    printf("static const NamedReferenceMap NamedReferences[] = {\n");
    for (Entity *entity in entities) {
        printf("    %s\n", entity.description.UTF8String);
    }
    printf("};\n\n");
    
    printf("static const NamedReferenceMap NamedSemicolonlessReferences[] = {\n");
    for (Entity *entity in semicolonlessEntities) {
        printf("    %s\n", entity.description.UTF8String);
    }
    printf("};\n\n");
    
    // -1 for the ampersand we ignore.
    printf("static const NSUInteger LongestReferenceNameLength = %tu;\n", longestLength - 1);
    return 0;
} }
