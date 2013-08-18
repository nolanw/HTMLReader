//
//  HTMLSelector.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import "HTMLSelector.h"

typedef CSSSelectorPredicate CSSSelectorPredicateGen;

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
		return ^(HTMLElementNode *node) {
			return [[node tagName] isEqualToString:tagType];
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
		return [node childNodes].count == 0;
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
		NSArray *parentChildren = node.parentNode.childNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

CSSSelectorPredicateGen generalSiblingPredicate(CSSSelectorPredicate siblingTest)
{
	return ^(HTMLNode *node) {
		for (HTMLNode *sibling in node.parentNode.childNodes) {
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
		//Index relative to start/end
		NSInteger nthPosition;
		if (fromLast) {
			nthPosition = [[node parentNode].childNodes indexOfObject:node] + 1;
		} else {
			nthPosition = [[node parentNode].childNodes count] - [[node parentNode].childNodes indexOfObject:node];
		}
		return (nthPosition - b) % m == 0;
	};
}

CSSSelectorPredicateGen isNthChildOfTypePredicate(int m, int b, BOOL fromLast)
{
	return ^BOOL(HTMLElementNode *node) {
		NSEnumerator *enumerator = fromLast ? [[node parentNode].childNodes reverseObjectEnumerator] : [[node parentNode].childNodes objectEnumerator];
		
		NSInteger count = 0;
		;
		
		for (HTMLElementNode *currentNode in enumerator) {
			if ([currentNode.tagName compare:node.tagName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
				count++;
			}
			if ([currentNode isEqual:node]) {
				//check if the current node is the nth element of its type
				//based on the current count
				return (count - b) % m == 0;
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
    // TODO this first return looks wrong
	return ^BOOL(HTMLNode *node) {
		return [node.parentNode childNodes].count == 1;
	};
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
		return [node.parentNode childNodes].count == 1;
	};
}

CSSSelectorPredicateGen isOnlyChildOfTypePredicate()
{
	return ^(HTMLElementNode *node) {
		for (HTMLNode *sibling in [node.parentNode childNodes]) {
			if (![sibling isEqual:node] &&
                [sibling isKindOfClass:[HTMLElementNode class]] &&
                [[(HTMLElementNode*)sibling tagName] isEqualToString:node.tagName]) {
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

static CSSSelectorPredicateGen predicateFromPseudoClass(NSScanner *pseudoScanner)
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
		CSSSelectorPredicate toNegate = SelectorFunctionForString(toNegateString);
		return negatePredicate(toNegate);
	}
	
	return nil;
}

/*
 
 //E:root	an E element, root of the document	Structural pseudo-classes	3
 //E:nth-child(n)	an E element, the n-th child of its parent	Structural pseudo-classes	3
 //E:nth-last-child(n)	an E element, the n-th child of its parent, counting from the last one	Structural pseudo-classes	3
 //E:nth-of-type(n)	an E element, the n-th sibling of its type	Structural pseudo-classes	3
 //E:nth-last-of-type(n)	an E element, the n-th sibling of its type, counting from the last one	Structural pseudo-classes	3
 // E:first-child	an E element, first child of its parent	Structural pseudo-classes	2
 //E:last-child	an E element, last child of its parent	Structural pseudo-classes	3
 //E:first-of-type	an E element, first sibling of its type	Structural pseudo-classes	3
 //E:last-of-type	an E element, last sibling of its type	Structural pseudo-classes	3
 //E:only-child	an E element, only child of its parent	Structural pseudo-classes	3
 //E:only-of-type	an E element, only sibling of its type	Structural pseudo-classes	3
 //E:empty	an E element that has no children (including text nodes)	Structural pseudo-classes	3
 E:link
 E:visited	an E element being the source anchor of a hyperlink of which the target is not yet visited (:link) or already visited (:visited)	The link pseudo-classes	1
 E:active
 E:hoverf
 E:focus	an E element during certain user actions	The user action pseudo-classes	1 and 2
 E:target	an E element being the target of the referring URI	The target pseudo-class	3
 E:lang(fr)	an element of type E in language "fr" (the document language specifies how language is determined)	The :lang() pseudo-class	2
 //E:enabled
 //E:disabled	a user interface element E which is enabled or disabled	The UI element states pseudo-classes	3
 //E:checked
 // E:not(s)
 */

#pragma mark

NSCharacterSet *identifierCharacters()
{
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"*"];
	[set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	return set;
}

NSString *scanIdentifier(NSScanner *scanner)
{
	NSString *ident;
	[scanner scanCharactersFromSet:identifierCharacters() intoString:&ident];
	return [ident stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *scanOperator(NSScanner *scanner)
{
	NSString *operator;
	[scanner scanUpToCharactersFromSet:identifierCharacters() intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return operator;
}

//Assumes the scanner is at the position directly after the first [
// TODO assert that!
CSSSelectorPredicate scanAttributePredicate(NSScanner *scanner)
{
	NSString *attributeName = scanIdentifier(scanner);
    
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


CSSSelectorPredicateGen predicateFromScanner(NSScanner* scanner)
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
	
	
	NSString *firstIdent = scanIdentifier(scanner);
	
	NSString *operator = scanOperator(scanner);
	
	
	if ([firstIdent length] > 0 && [operator length] == 0 && [scanner isAtEnd]) {
		return ofTagTypePredicate(firstIdent);
	}
    
    if ([operator isEqualToString:@":"]) {
        return andCombinatorPredicate(@[ofTagTypePredicate(firstIdent), predicateFromPseudoClass(scanner)]);
    } else if ([operator isEqualToString:@"::"]) {
        // TODO implement :: stuff
        return nil;
    } else if ([operator isEqualToString:@"["]) {
        scanAttributePredicate(scanner);
    } else if ([operator length] == 0) {
        //Whitespace combinator
        //y descendant of an x
        return andCombinatorPredicate(@[predicateFromScanner(scanner), descendantOfPredicate(ofTagTypePredicate(firstIdent))]);
    } else if ([operator isEqualToString:@">"]) {
        andCombinatorPredicate(@[predicateFromScanner(scanner), childOfOtherPredicatePredicate(ofTagTypePredicate(firstIdent))]);
    } else if ([operator isEqualToString:@"+"]) {
        andCombinatorPredicate(@[predicateFromScanner(scanner), adjacentSiblingPredicate(ofTagTypePredicate(firstIdent))]);
    } else if ([operator isEqualToString:@"~"]) {
        andCombinatorPredicate(@[predicateFromScanner(scanner), generalSiblingPredicate(ofTagTypePredicate(firstIdent))]);
    } else if ([operator isEqualToString:@"."]) {
        NSString *className = scanIdentifier(scanner);
        return isKindOfClassPredicate(className);
    } else if ([operator isEqualToString:@"#"]) {
        NSString *idName = scanIdentifier(scanner);
        return hasIDPredicate(idName);
    }
    
	return nil;
}


extern CSSSelectorPredicate SelectorFunctionForString(NSString* selectorString)
{
	//Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
	[scanner setCaseSensitive:NO]; //Section 3 states that in HTML parsing, selectors are case-insensitive
	
	return predicateFromScanner(scanner);
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
	self.parsedString = @"";
	self.predicate = SelectorFunctionForString(selectorString);
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

// TODO NSArray has a method for this.
NSArray * filterWithPredicate(NSEnumerator *nodes, CSSSelector *selector)
{
	NSMutableArray *ret = [NSMutableArray new];
	for (HTMLElementNode *node in nodes) {
		if ([node isKindOfClass:[HTMLElementNode class]] && selector.predicate(node)) {
			[ret addObject:node];
		}
	}
	return ret;
}

@implementation HTMLNode (HTMLSelector)

- (NSArray *)nodesForSelectorString:(NSString *)selectorString
{
	return [self nodesForSelector:[CSSSelector selectorForString:selectorString]];
}

- (NSArray *)nodesForSelector:(CSSSelector *)selector
{
	NSAssert(!selector.parseError, @"Attempted to use selector with error: %@", selector.parseError);
	return filterWithPredicate(self.treeEnumerator, selector);
}

@end
