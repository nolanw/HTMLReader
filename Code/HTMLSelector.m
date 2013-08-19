//
//  HTMLSelector.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import "HTMLSelector.h"

typedef CSSSelectorPredicate CSSSelectorPredicateGen;

extern CSSSelectorPredicate SelectorFunctionForString(NSString* selectorString,  NSString **parsedStringPointer, NSError **errorPointer);

CSSSelectorPredicateGen truePredicate()
{
	return ^(__unused HTMLElementNode *node) {
		return YES;
	};
}

CSSSelectorPredicateGen falsePredicate()
{
	return ^(__unused HTMLElementNode *node) {
		return NO;
	};
}

CSSSelectorPredicateGen negatePredicate(CSSSelectorPredicate predicate)
{
	return ^BOOL(HTMLElementNode *node) {
		return !predicate(node);
	};
}

#pragma mark - Combinators

CSSSelectorPredicateGen andCombinatorPredicate(NSArray *predicates)
{
	return ^(HTMLElementNode *node) {
		for (CSSSelectorPredicate predicate in predicates) {
			if (!predicate(node)) {
				return NO;
			}
		}
		return YES;
	};
}

//Same thing as andCombinatorPredicate, but without a loop
CSSSelectorPredicateGen bothCombinatorPredicate(CSSSelectorPredicate a, CSSSelectorPredicate b)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return a(node) && b(node);
	};
}

CSSSelectorPredicateGen orCombinatorPredicate(NSArray *predicates)
{
	return ^(HTMLElementNode *node) {
		for (CSSSelectorPredicate predicate in predicates) {
			if (predicate(node)) {
				return YES;
			}
		}
		return NO;
	};
}

CSSSelectorPredicateGen ofTagTypePredicate(NSString *tagType)
{
	if ([tagType isEqualToString:@"*"]) {
		return truePredicate();
	} else {
		return ^BOOL(HTMLElementNode *node) {
			return [node isKindOfClass:[HTMLElementNode class]] && [[node tagName] isEqualToString:tagType];
		};
	}
}

CSSSelectorPredicateGen childOfOtherPredicatePredicate(CSSSelectorPredicate parentPredicate)
{
	return ^BOOL(HTMLElementNode *node) {
		return ([node.parentNode isKindOfClass:[HTMLElementNode class]] &&
                parentPredicate((HTMLElementNode *)node.parentNode));
	};
}

CSSSelectorPredicateGen descendantOfPredicate(CSSSelectorPredicate parentPredicate)
{
	return ^(HTMLElementNode *node) {
		HTMLNode *parentNode = node.parentNode;
		while (parentNode) {
			if ([parentNode isKindOfClass:[HTMLElementNode class]] &&
                parentPredicate((HTMLElementNode *)parentNode)) {
				return YES;
			}
			parentNode = parentNode.parentNode;
		}
		return NO;
	};
}

CSSSelectorPredicateGen isEmptyPredicate()
{
	//TODO breaks if comments are present
	return ^BOOL(HTMLElementNode *node) {
		return [node childElementNodes].count == 0;
	};
}


#pragma mark - Attribute Predicates

CSSSelectorPredicateGen hasAttributePredicate(NSString *attributeName)
{
	return ^BOOL(HTMLElementNode *node) {
		return !![node attributeNamed:attributeName];
	};
}

CSSSelectorPredicateGen attributeIsExactlyPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value isEqualToString:attributeValue];
	};
}

CSSSelectorPredicateGen attributeStartsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value hasPrefix:attributeValue];
	};
}

CSSSelectorPredicateGen attributeContainsPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^BOOL(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value rangeOfString:attributeValue].location != NSNotFound;
	};
}

CSSSelectorPredicateGen attributeEndsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value hasSuffix:attributeValue];
	};
}

CSSSelectorPredicateGen attributeIsExactlyAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeIsExactlyPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}

CSSSelectorPredicateGen attributeStartsWithAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeStartsWithPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}


#pragma mark Attribute Helpers

CSSSelectorPredicateGen isKindOfClassPredicate(NSString *classname)
{
	//TODO this won't work if there's multiple classes defined
	return attributeIsExactlyPredicate(@"class", classname);
}

CSSSelectorPredicateGen hasIDPredicate(NSString *idValue)
{
	return attributeIsExactlyPredicate(@"id", idValue);
}

CSSSelectorPredicateGen isDisabledPredicate()
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"disabled"), negatePredicate(hasAttributePredicate(@"enabled"))]);
}

CSSSelectorPredicateGen isEnabledPredicate()
{
	return negatePredicate(isDisabledPredicate());
}

CSSSelectorPredicateGen isCheckedPredicate()
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"checked"), hasAttributePredicate(@"selected")]);
}


#pragma mark Sibling Predicates

CSSSelectorPredicateGen adjacentSiblingPredicate(CSSSelectorPredicate siblingTest)
{
	return ^BOOL(HTMLNode *node) {
		NSArray *parentChildren = [node parentNode].childElementNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

CSSSelectorPredicateGen generalSiblingPredicate(CSSSelectorPredicate siblingTest)
{
	return ^(HTMLNode *node) {
		for (HTMLNode *sibling in node.parentNode.childElementNodes) {
			if ([sibling isEqual:node]) {
				break;
			}
			if ([sibling isKindOfClass:[HTMLElementNode class]] && siblingTest(siblingTest)) {
				return YES;
			}
		}
		return NO;
	};
}

#pragma mark nth Child Predicates

CSSSelectorPredicateGen isNthChildPredicate(int m, int b, BOOL fromLast)
{
	return ^BOOL(HTMLNode *node) {
		NSArray *parentElements = node.parentNode.childElementNodes;
		//Index relative to start/end
		NSInteger nthPosition;
		if (fromLast) {
			nthPosition = [parentElements indexOfObject:node] + 1;
		} else {
			nthPosition = [parentElements count] - [parentElements indexOfObject:node];
		}
		return (nthPosition - b) % m == 0;
	};
}

CSSSelectorPredicateGen isNthChildOfTypePredicate(int m, int b, BOOL fromLast)
{
	return ^BOOL(HTMLElementNode *node) {
		NSEnumerator *enumerator = fromLast ? [[node parentNode].childElementNodes reverseObjectEnumerator] : [[node parentNode].childElementNodes objectEnumerator];
		
		NSInteger count = 0;
		;
		
		for (HTMLElementNode *currentNode in enumerator) {
			if ([currentNode.tagName compare:node.tagName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
				count++;
			}
			if ([currentNode isEqual:node]) {
				//check if the current node is the nth element of its type
				//based on the current count
				if (m > 0)
				{
					return (count - b) % m == 0;
				}
				else
				{
					return (count - b) == 0;
				}
			}
		}
		return NO;
	};
}

CSSSelectorPredicateGen isFirstChildPredicate()
{
	return isNthChildPredicate(0, 1, NO);
}

CSSSelectorPredicateGen isLastChildPredicate()
{
	return isNthChildPredicate(0, 1, YES);
}

CSSSelectorPredicateGen isFirstChildOfTypePredicate()
{
	return isNthChildOfTypePredicate(0, 1, NO);	
}

CSSSelectorPredicateGen isLastChildOfTypePredicate()
{
	return isNthChildOfTypePredicate(0, 1, YES);
}

#pragma mark - Only Child

CSSSelectorPredicateGen isOnlyChildPredicate()
{
	return ^BOOL(HTMLNode *node) {
		return [node.parentNode childElementNodes].count == 1;
	};
}

CSSSelectorPredicateGen isOnlyChildOfTypePredicate()
{
	return ^(HTMLElementNode *node) {
		for (HTMLElementNode *sibling in [node.parentNode childElementNodes]) {
			if (![sibling isEqual:node] &&
                [[sibling tagName] isEqualToString:node.tagName]) {
				return NO;
			}
		}
		return YES;
	};
}

CSSSelectorPredicateGen isRootPredicate()
{
	return ^BOOL(HTMLElementNode *node)
	{
		return !node.parentNode;
	};
}

// TODO Instead of defaultValue, let caller do it with ?: operator.
NSNumber* parseNumber(NSString *number, int defaultValue)
{
	//defaults to 1
	NSInteger result = defaultValue;
	
    // Strip whitespace so -isAtEnd check below answers "was this a valid integer?"
    number = [number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
	NSScanner *scanner = [NSScanner scannerWithString:number];
	[scanner scanInteger:&result];
    return [scanner isAtEnd] ? @(result) : nil;
}

#pragma mark Parse
extern struct mb{int m; int b;} parseNth(NSString *nthString)
{
	nthString = [[nthString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([nthString isEqualToString:@"odd"]) {
		return (struct mb){2, 1};
	} else if ([nthString isEqualToString:@"even"]) {
		return (struct mb){2, 0};
	}
    // TODO is 0 allowed?
    else if ([nthString rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"123456789 n+-"] invertedSet]].location != NSNotFound) {
		return (struct mb){0, 0};
	}
	
	NSArray *valueSplit = [nthString componentsSeparatedByString:@"n"];
	
	if (valueSplit.count > 2) {
		//Multiple ns, fail
		return (struct mb){0, 0};
	} else if (valueSplit.count == 2) {
		NSNumber *numberOne = parseNumber(valueSplit[0], 1);
		NSNumber *numberTwo = parseNumber(valueSplit[1], 0);
		
		if ([valueSplit[0] isEqualToString:@"-"] && numberTwo != nil) {
			//"n" was defined, and only "-" was given as a multiplier
			return (struct mb){ -1, [numberTwo integerValue] };
		} else if (numberOne && numberTwo) {
			return (struct mb){ [numberOne integerValue], [numberTwo integerValue] };
		} else {
			return (struct mb){0, 0};
		}
	} else {
		NSNumber *number = parseNumber(valueSplit[0], 1);
		
		//"n" not found, use whole string as b
		return (struct mb){0, [number integerValue]};
	}
}

static NSString* scanFunctionInterior(NSScanner *functionScanner)
{
	NSString *openParen;
	
	[functionScanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"("] intoString:&openParen];
	
    // TODO use return value from -scanCharactersFromSet:intoString:
	if (!openParen) {
		return nil;
	}
	
	NSString *interior;
	
	[functionScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@")"] intoString:&interior];
	
    // TODO use return value from -scanUpToCharactersFromSet:intoString:
	if (!interior) {
		return nil;
	}
	
	[functionScanner setScanLocation:functionScanner.scanLocation + 1];
	return interior;;
}

static CSSSelectorPredicateGen predicateFromPseudoClass(NSScanner *pseudoScanner, __unused NSString **parsedStringPointer, __unused NSError **errorPointer)
{
	typedef CSSSelectorPredicate (^CSSThing)(struct mb inputs);
	
	NSString *pseudo;
	
	[pseudoScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"("] intoString:&pseudo];
	
	if (!pseudo && ![pseudoScanner isAtEnd]) {
		pseudo = [[pseudoScanner string] substringFromIndex:[pseudoScanner scanLocation]];
		[pseudoScanner setScanLocation:[pseudoScanner string].length-1];
	}
	
	static NSDictionary *simplePseudos = nil;
	static NSDictionary *nthPseudos = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		simplePseudos = @{
						  @"first-child": isFirstChildPredicate(),
						  @"last-child": isLastChildPredicate(),
						  @"only-child": isOnlyChildPredicate(),
						  
						  @"first-of-type": isFirstChildOfTypePredicate(),
						  @"last-of-type": isLastChildOfTypePredicate(),
						  @"only-of-type": isOnlyChildOfTypePredicate(),
						  
						  @"empty": isEmptyPredicate(),
						  @"root": isRootPredicate(),
						  
						  @"enabled": isEnabledPredicate(),
						  @"disabled": isDisabledPredicate(),
						  @"checked": isCheckedPredicate()
						  };
		
        #define WRAP(funct) (^CSSSelectorPredicate (struct mb input){ int m=input.m; int b=input.b; return funct; })
		
		nthPseudos = @{
					   @"nth-child": WRAP((isNthChildPredicate(m, b, NO))),
					   @"nth-last-child": WRAP((isNthChildPredicate(m, b, YES))),
					   
					   @"nth-of-type": WRAP((isNthChildOfTypePredicate(m, b, NO))),
					   @"nth-last-of-type": WRAP((isNthChildOfTypePredicate(m, b, YES))),
					   };
		
	});
	
	id simple = simplePseudos[pseudo];
	if (simple) {
		return simple;
	}
	
	CSSThing nth = nthPseudos[pseudo];
	if (nth) {
		struct mb output = parseNth(scanFunctionInterior(pseudoScanner));
		if (output.m == 0 && output.b == 0) {
			return nil;
		} else {
			return nth(output);
		}
	}
	
	if ([pseudo isEqualToString:@"not"]) {
		NSString *toNegateString = scanFunctionInterior(pseudoScanner);
		NSError *error = nil;
		NSString *string = nil;
		CSSSelectorPredicate toNegate = SelectorFunctionForString(toNegateString, &string, &error);
		return negatePredicate(toNegate);
	}
	
	return nil;
}


#pragma mark

NSCharacterSet *identifierCharacters()
{
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"*-"];
	[set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	return set;
}

NSString *scanIdentifier(NSScanner* scanner,  __unused NSString **parsedStringPointer, __unused NSError **errorPointer)
{
	NSString *ident;
	[scanner scanCharactersFromSet:identifierCharacters() intoString:&ident];
	return [ident stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *scanOperator(NSScanner* scanner,  __unused NSString **parsedStringPointer, __unused NSError **errorPointer)
{
	NSString *operator;
	[scanner scanUpToCharactersFromSet:identifierCharacters() intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return operator;
}

//Assumes the scanner is at the position directly after the first [
// TODO assert that!
CSSSelectorPredicate scanAttributePredicate(NSScanner *scanner,  NSString **parsedStringPointer, NSError **errorPointer)
{
	NSString *attributeName = scanIdentifier(scanner, parsedStringPointer, errorPointer);
	NSString *operator;
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"]"] intoString:&operator];
	
	NSString *attributeValue = nil;
	
	if ([operator length] == 0) {
		return hasAttributePredicate(attributeName);
	} else if ([operator isEqualToString:@"="]) {
		return attributeIsExactlyPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"~="]) {
		NSArray *attributeValues = [attributeValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		return attributeIsExactlyAnyOf(attributeName, attributeValues);
	} else if ([operator isEqualToString:@"^="]) {
		return attributeStartsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"$="]) {
		return attributeEndsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"*="]) {
		return attributeContainsPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"|="]) {
		return orCombinatorPredicate(@[ attributeIsExactlyPredicate(attributeName, attributeValue),
                                        attributeContainsPredicate(attributeName, [attributeValue stringByAppendingString:@"-"]) ]);
	} else {
		return nil;
	}
}

CSSSelectorPredicateGen predicateFromScanner(NSScanner* scanner,  NSString **parsedStringPointer, NSError **errorPointer)
{
	//Spec at:
	//http://www.w3.org/TR/css3-selectors/
	
	//Spec: Only the characters "space" (U+0020), "tab" (U+0009), "line feed" (U+000A), "carriage return" (U+000D), and "form feed" (U+000C) can occur in whitespace
    // TODO so use only those characters as whitespace then!
    
	//whitespaceAndNewlineCharacterSet == (U+0020) and tab (U+0009) and the newline and nextline characters (U+000A–U+000D, U+0085).
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	//Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
	//NSCharacterSet *combinatorSet = [NSCharacterSet characterSetWithCharactersInString:@">+~"];
	
	
	NSMutableCharacterSet *operatorCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~.:#["];
	[operatorCharacters formUnionWithCharacterSet:whitespaceSet];
	
	
	NSString *firstIdent = scanIdentifier(scanner, parsedStringPointer, errorPointer);
	
	NSString *operator = scanOperator(scanner, parsedStringPointer, errorPointer);
	
	
	if ([firstIdent length] > 0 && [operator length] == 0 && [scanner isAtEnd]) {
		return ofTagTypePredicate(firstIdent);
	}
	else
	{
		if ([operator isEqualToString:@":"])
		{
			return bothCombinatorPredicate(ofTagTypePredicate(firstIdent), predicateFromPseudoClass(scanner, parsedStringPointer, errorPointer));
		}
		else if ([operator isEqualToString:@"::"])
		{
			//Don't impliment :: stuff yet
			return nil;
		}
		else if ([operator isEqualToString:@"["])
		{
			scanAttributePredicate(scanner, parsedStringPointer, errorPointer);
		}
		else if ([operator length] == 0)
		{
			//Whitespace combinator
			//y descendant of an x
			return bothCombinatorPredicate(predicateFromScanner(scanner, parsedStringPointer, errorPointer), descendantOfPredicate(ofTagTypePredicate(firstIdent)));
		}
		else if ([operator isEqualToString:@">"])
		{
			return bothCombinatorPredicate(predicateFromScanner(scanner, parsedStringPointer, errorPointer), childOfOtherPredicatePredicate(ofTagTypePredicate(firstIdent)));
		}
		else if ([operator isEqualToString:@"+"])
		{
			return bothCombinatorPredicate(predicateFromScanner(scanner, parsedStringPointer, errorPointer), adjacentSiblingPredicate(ofTagTypePredicate(firstIdent)));
		}
		else if ([operator isEqualToString:@"~"])
		{
			return bothCombinatorPredicate(predicateFromScanner(scanner, parsedStringPointer, errorPointer), generalSiblingPredicate(ofTagTypePredicate(firstIdent)));
		}
		else if ([operator isEqualToString:@"."])
		{
			NSString *className = scanIdentifier(scanner, parsedStringPointer, errorPointer);
			return isKindOfClassPredicate(className);
			
		}
		else if ([operator isEqualToString:@"#"])
		{
			NSString *idName = scanIdentifier(scanner, parsedStringPointer, errorPointer);
			return hasIDPredicate(idName);
		}
	}
	return nil;
}


extern CSSSelectorPredicate SelectorFunctionForString(NSString* selectorString,  NSString **parsedStringPointer, NSError **errorPointer)
{
	//Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
	[scanner setCaseSensitive:NO]; //Section 3 states that in HTML parsing, selectors are case-insensitive
	
	return predicateFromScanner(scanner, parsedStringPointer, errorPointer);
}

@interface CSSSelector ()

@property (copy, nonatomic) CSSSelectorPredicate predicate;
@property (copy, nonatomic) NSString *parsedString;
@property (strong, nonatomic) NSError *parseError;

@end

@implementation CSSSelector

+ (instancetype)selectorForString:(NSString *)selectorString
{
	return [[self alloc] initWithString:selectorString];
}

- (id)initWithString:(NSString *)selectorString
{
    if (!(self = [self init])) return nil;
	NSError *error = nil;
	NSString *parsedString = @"";
	self.predicate = SelectorFunctionForString(selectorString, &parsedString, &error);
	self.parseError = error;
	self.parsedString = parsedString;
    return self;
}

- (NSString *)description
{
	if (self.parseError) {
        return [NSString stringWithFormat:@"<%@: %p ERROR: '%@'>", self.class, self, self.parseError];
    } else {
		return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, self.parsedString];
	}
}

@end

@implementation HTMLNode (HTMLSelector)

- (NSArray *)nodesForSelectorString:(NSString *)selectorString
{
	return [self nodesForSelector:[CSSSelector selectorForString:selectorString]];
}

- (NSArray *)nodesForSelector:(CSSSelector *)selector
{
	NSAssert(!selector.parseError, @"Attempted to use selector with error: %@", selector.parseError);
    
	NSMutableArray *ret = [NSMutableArray new];
	for (HTMLElementNode *node in [self treeEnumerator]) {
		
		if ([node isKindOfClass:[HTMLElementNode class]] && selector.predicate(node))
		{
			[ret addObject:node];
		}
	}
	
	return ret;}

@end
