//  HTMLEntities.h
//
//  Public domain. https://github.com/nolanw/HTMLReader

#import <Foundation/Foundation.h>

/**
    Returns the code point for a numeric HTML entity if it is meant to be replaced, or U+0000 NULL if no replacement is required.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/tokenization.html#table-charref-overrides
 */
extern UTF32Char ReplacementForNumericEntity(UInt32 entity);

/**
    Returns the replacement string for a named entity, or nil if there is no match.
 
    @param entityName A string whose prefix is tested for a named entity. The ampersand that starts the entity should not be included.
    @param parsedName If non-nil and a match is found, will contain the matching entity name. This will be a (possibly proper) prefix of entityName.
 
    For more information, see http://www.whatwg.org/specs/web-apps/current-work/multipage/named-character-references.html
 */
extern NSString * StringForNamedEntity(NSString *entityName, NSString * __autoreleasing *parsedName);

/// No named entities are longer than this (does not consider the leading ampersand).
extern const NSUInteger LongestEntityNameLength;
