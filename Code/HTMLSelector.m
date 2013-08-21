//
//  HTMLSelector.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//

#import "HTMLSelector.h"

typedef BOOL (^HTMLSelectorPredicate)(HTMLElementNode *node);
typedef HTMLSelectorPredicate HTMLSelectorPredicateGen;

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString,
                                                       NSString **parsedString,
                                                       NSError **error);

HTMLSelectorPredicateGen negatePredicate(HTMLSelectorPredicate predicate)
{
	return ^BOOL(HTMLElementNode *node) {
		return !predicate(node);
	};
}

#pragma mark - Combinators

HTMLSelectorPredicateGen andCombinatorPredicate(HTMLSelectorPredicate a, HTMLSelectorPredicate b)
{
	return ^BOOL(HTMLElementNode *node)
	{
		return a(node) && b(node);
	};
}

HTMLSelectorPredicateGen orCombinatorPredicate(NSArray *predicates)
{
	return ^(HTMLElementNode *node) {
		for (HTMLSelectorPredicate predicate in predicates) {
			if (predicate(node)) {
				return YES;
			}
		}
		return NO;
	};
}

HTMLSelectorPredicateGen ofTagTypePredicate(NSString *tagType)
{
	if ([tagType isEqualToString:@"*"]) {
		return ^(__unused HTMLElementNode *node) {
            return YES;
        };
	} else {
		return ^BOOL(HTMLElementNode *node) {
			return [node.tagName isEqualToString:tagType];
		};
	}
}

HTMLSelectorPredicateGen childOfOtherPredicatePredicate(HTMLSelectorPredicate parentPredicate)
{
	return ^BOOL(HTMLElementNode *node) {
		return ([node.parentNode isKindOfClass:[HTMLElementNode class]] &&
                parentPredicate((HTMLElementNode *)node.parentNode));
	};
}

HTMLSelectorPredicateGen descendantOfPredicate(HTMLSelectorPredicate parentPredicate)
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

HTMLSelectorPredicateGen isEmptyPredicate()
{
	return ^BOOL(HTMLElementNode *node) {
        for (HTMLNode *child in node.childNodes) {
            if ([child isKindOfClass:[HTMLElementNode class]]) {
                return NO;
            } else if ([child isKindOfClass:[HTMLTextNode class]]) {
                HTMLTextNode *textChild = (HTMLTextNode *)child;
                return textChild.data.length == 0;
            }
        }
		return YES;
	};
}


#pragma mark - Attribute Predicates

HTMLSelectorPredicateGen hasAttributePredicate(NSString *attributeName)
{
	return ^BOOL(HTMLElementNode *node) {
		return !![node attributeNamed:attributeName];
	};
}

HTMLSelectorPredicateGen attributeIsExactlyPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value isEqualToString:attributeValue];
	};
}

HTMLSelectorPredicateGen attributeContainsExactWhitespaceSeparatedValuePredicate(NSString *attributeName, NSString *attributeValue)
{
    // TODO use appropriate whitespace set (from HTML spec? Selectors spec?)
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return ^(HTMLElementNode *node) {
        NSArray *items = [node[attributeName] componentsSeparatedByCharactersInSet:whitespace];
        return [items containsObject:attributeValue];
    };
}

HTMLSelectorPredicateGen attributeStartsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value hasPrefix:attributeValue];
	};
}

HTMLSelectorPredicateGen attributeContainsPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^BOOL(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value rangeOfString:attributeValue].location != NSNotFound;
	};
}

HTMLSelectorPredicateGen attributeEndsWithPredicate(NSString *attributeName, NSString *attributeValue)
{
	return ^(HTMLElementNode *node) {
		return [[node attributeNamed:attributeName].value hasSuffix:attributeValue];
	};
}

HTMLSelectorPredicateGen attributeIsExactlyAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeIsExactlyPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}

HTMLSelectorPredicateGen attributeStartsWithAnyOf(NSString *attributeName, NSArray *attributeValues)
{
	NSMutableArray *arrayOfPredicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	for (NSString *attributeValue in attributeValues) {
		[arrayOfPredicates addObject:attributeStartsWithPredicate(attributeName, attributeValue)];
	}
	return orCombinatorPredicate(arrayOfPredicates);
}


#pragma mark Attribute Helpers

HTMLSelectorPredicateGen isKindOfClassPredicate(NSString *classname)
{
	return attributeContainsExactWhitespaceSeparatedValuePredicate(@"class", classname);
}

HTMLSelectorPredicateGen hasIDPredicate(NSString *idValue)
{
	return attributeIsExactlyPredicate(@"id", idValue);
}

HTMLSelectorPredicateGen isFormControlPredicate(void)
{
    // I couldn't find this list written out anywhere, so I wrote down any elements in the "Forms" section of the HTML spec that have a "disabled" attribute.
    NSArray *tagNames = @[ @"input", @"button", @"select", @"optgroup", @"option", @"textarea", @"keygen" ];
    NSMutableArray *predicates = [NSMutableArray new];
    for (NSString *tagName in tagNames) {
        [predicates addObject:ofTagTypePredicate(tagName)];
    }
    return orCombinatorPredicate(predicates);
}

HTMLSelectorPredicateGen isDisabledPredicate()
{
    // TODO finish implementing this per the HTML spec http://www.whatwg.org/specs/web-apps/current-work/multipage/association-of-controls-and-forms.html#concept-fe-disabled
    // (namely the part about the first <legend> child)
    HTMLSelectorPredicate descendantOfDisabledFieldset = descendantOfPredicate(andCombinatorPredicate(ofTagTypePredicate(@"fieldset"), hasAttributePredicate(@"disabled")));
    return andCombinatorPredicate(isFormControlPredicate(),
                                  orCombinatorPredicate(@[hasAttributePredicate(@"disabled"),
                                                          descendantOfDisabledFieldset]));
}

HTMLSelectorPredicateGen isEnabledPredicate()
{
	return negatePredicate(isDisabledPredicate());
}

HTMLSelectorPredicateGen isCheckedPredicate()
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"checked"), hasAttributePredicate(@"selected")]);
}


#pragma mark Sibling Predicates

HTMLSelectorPredicateGen adjacentSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	return ^BOOL(HTMLElementNode *node) {
		NSArray *parentChildren = node.parentNode.childElementNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

HTMLSelectorPredicateGen generalSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	return ^(HTMLElementNode *node) {
		for (HTMLElementNode *sibling in node.parentNode.childElementNodes) {
			if ([sibling isEqual:node]) {
				break;
			}
			if (siblingTest(node)) {
				return YES;
			}
		}
		return NO;
	};
}

#pragma mark nth Child Predicates

HTMLSelectorPredicateGen isNthChildPredicate(HTMLNthExpression nth, BOOL fromLast)
{
	return ^BOOL(HTMLNode *node) {
		NSArray *parentElements = node.parentNode.childElementNodes;
		//Index relative to start/end
		NSInteger nthPosition;
		if (fromLast) {
			nthPosition = [parentElements indexOfObject:node] + 1;
		} else {
			nthPosition = parentElements.count - [parentElements indexOfObject:node];
		}
		return (nthPosition - nth.c) % nth.n == 0;
	};
}

HTMLSelectorPredicateGen isNthChildOfTypePredicate(HTMLNthExpression nth, BOOL fromLast)
{
	return ^BOOL(HTMLElementNode *node) {
		id <NSFastEnumeration> enumerator = (fromLast
                                             ? node.parentNode.childElementNodes.reverseObjectEnumerator
                                             : node.parentNode.childElementNodes);
		NSInteger count = 0;
		for (HTMLElementNode *currentNode in enumerator) {
			if ([currentNode.tagName compare:node.tagName options:NSCaseInsensitiveSearch] == NSOrderedSame) {
				count++;
			}
			if ([currentNode isEqual:node]) {
				//check if the current node is the nth element of its type
				//based on the current count
				if (nth.n > 0) {
					return (count - nth.c) % nth.n == 0;
				} else {
					return (count - nth.c) == 0;
				}
			}
		}
		return NO;
	};
}

HTMLSelectorPredicateGen isFirstChildPredicate()
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), NO);
}

HTMLSelectorPredicateGen isLastChildPredicate()
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), YES);
}

HTMLSelectorPredicateGen isFirstChildOfTypePredicate()
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), NO);
}

HTMLSelectorPredicateGen isLastChildOfTypePredicate()
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), YES);
}

#pragma mark - Only Child

HTMLSelectorPredicateGen isOnlyChildPredicate()
{
	return ^BOOL(HTMLNode *node) {
		return [node.parentNode childElementNodes].count == 1;
	};
}

HTMLSelectorPredicateGen isOnlyChildOfTypePredicate()
{
	return ^(HTMLElementNode *node) {
		for (HTMLElementNode *sibling in node.parentNode.childElementNodes) {
			if (![sibling isEqual:node] && [sibling.tagName isEqualToString:node.tagName]) {
				return NO;
			}
		}
		return YES;
	};
}

HTMLSelectorPredicateGen isRootPredicate()
{
	return ^BOOL(HTMLElementNode *node)
	{
		return !node.parentNode;
	};
}

NSNumber * parseNumber(NSString *number, NSInteger defaultValue)
{
    // Strip whitespace so -isAtEnd check below answers "was this a valid integer?"
    number = [number stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
	NSScanner *scanner = [NSScanner scannerWithString:number];
    NSInteger result = defaultValue;
	[scanner scanInteger:&result];
    return scanner.isAtEnd ? @(result) : nil;
}

#pragma mark Parse

HTMLNthExpression parseNth(NSString *nthString)
{
	nthString = [nthString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([nthString compare:@"odd" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionOdd;
	} else if ([nthString compare:@"even" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		return HTMLNthExpressionEven;
	} else {
        NSCharacterSet *nthCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789 nN+-"] invertedSet];
        if ([nthString rangeOfCharacterFromSet:nthCharacters].location != NSNotFound) {
            return HTMLNthExpressionInvalid;
        }
	}
	
	NSArray *valueSplit = [nthString componentsSeparatedByString:@"n"];
	
	if (valueSplit.count > 2) {
		//Multiple ns, fail
		return HTMLNthExpressionInvalid;
	} else if (valueSplit.count == 2) {
		NSNumber *numberOne = parseNumber(valueSplit[0], 1);
		NSNumber *numberTwo = parseNumber(valueSplit[1], 0);
		
		if ([valueSplit[0] isEqualToString:@"-"] && numberTwo) {
			//"n" was defined, and only "-" was given as a multiplier
			return HTMLNthExpressionMake(-1, numberTwo.integerValue);
		} else if (numberOne && numberTwo) {
			return HTMLNthExpressionMake(numberOne.integerValue, numberTwo.integerValue);
		} else {
			return HTMLNthExpressionInvalid;
		}
	} else {
		NSNumber *number = parseNumber(valueSplit[0], 1);
		
		//"n" not found, use whole string as b
		return HTMLNthExpressionMake(0, number.integerValue);
	}
}

static NSString * scanFunctionInterior(NSScanner *functionScanner)
{
	BOOL ok;
    
    ok = [functionScanner scanString:@"(" intoString:nil];
	if (!ok) {
		return nil;
	}
	
    NSString *interior;
	ok = [functionScanner scanUpToString:@")" intoString:&interior];
	if (!ok) {
		return nil;
	}
    
    [functionScanner scanString:@")" intoString:nil];
	return interior;
}

static HTMLSelectorPredicateGen predicateFromPseudoClass(NSScanner *pseudoScanner,
                                                         __unused NSString **parsedString,
                                                         __unused NSError **error)
{
	typedef HTMLSelectorPredicate (^CSSThing)(HTMLNthExpression nth);
    BOOL ok;
    
	NSString *pseudo;
	ok = [pseudoScanner scanUpToString:@"(" intoString:&pseudo];
	if (!ok && !pseudoScanner.isAtEnd) {
		pseudo = [pseudoScanner.string substringFromIndex:pseudoScanner.scanLocation];
		pseudoScanner.scanLocation = pseudoScanner.string.length - 1;
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
		
        #define WRAP(funct) (^HTMLSelectorPredicate (HTMLNthExpression nth){ return funct; })
		
		nthPseudos = @{
					   @"nth-child": WRAP((isNthChildPredicate(nth, NO))),
					   @"nth-last-child": WRAP((isNthChildPredicate(nth, YES))),
					   
					   @"nth-of-type": WRAP((isNthChildOfTypePredicate(nth, NO))),
					   @"nth-last-of-type": WRAP((isNthChildOfTypePredicate(nth, YES))),
					   };
		
	});
	
	id simple = simplePseudos[pseudo];
	if (simple) {
		return simple;
	}
	
	CSSThing nth = nthPseudos[pseudo];
	if (nth) {
		HTMLNthExpression output = parseNth(scanFunctionInterior(pseudoScanner));
		if (HTMLNthExpressionEqualToNthExpression(output, HTMLNthExpressionInvalid)) {
			return nil;
		} else {
			return nth(output);
		}
	}
	
	if ([pseudo compare:@"not" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
		NSString *toNegateString = scanFunctionInterior(pseudoScanner);
		NSError *error = nil;
		NSString *string = nil;
		HTMLSelectorPredicate toNegate = SelectorFunctionForString(toNegateString, &string, &error);
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

NSString *scanIdentifier(NSScanner* scanner,  __unused NSString **parsedString, __unused NSError **error)
{
	NSString *ident;
	[scanner scanCharactersFromSet:identifierCharacters() intoString:&ident];
	return [ident stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

NSString *scanOperator(NSScanner* scanner,  __unused NSString **parsedString, __unused NSError **error)
{
	NSString *operator;
	[scanner scanUpToCharactersFromSet:identifierCharacters() intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	return operator;
}

HTMLSelectorPredicate scanAttributePredicate(NSScanner *scanner, NSString **parsedString, NSError **error)
{
    NSCAssert([scanner.string characterAtIndex:scanner.scanLocation - 1] == '[', nil);
    
	NSString *attributeName = scanIdentifier(scanner, parsedString, error);
	NSString *operator;
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"]"]
                            intoString:&operator];
	
	NSString *attributeValue = nil;
	
	if (operator.length == 0) {
		return hasAttributePredicate(attributeName);
	} else if ([operator isEqualToString:@"="]) {
		return attributeIsExactlyPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"~="]) {
        return attributeContainsExactWhitespaceSeparatedValuePredicate(attributeName, attributeValue);
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

HTMLSelectorPredicateGen predicateFromScanner(NSScanner *scanner, NSString **parsedString, NSError **error)
{
	//Spec at:
	//http://www.w3.org/TR/css3-selectors/
	
	//Spec: Only the characters "space" (U+0020), "tab" (U+0009), "line feed" (U+000A), "carriage return" (U+000D), and "form feed" (U+000C) can occur in whitespace
	NSCharacterSet *whitespaceSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\f"];
	
	//Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
	NSMutableCharacterSet *operatorCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~.:#["];
	[operatorCharacters formUnionWithCharacterSet:whitespaceSet];
    
	NSString *firstIdent = scanIdentifier(scanner, parsedString, error);
	NSString *operator = scanOperator(scanner, parsedString, error);
	
	if (firstIdent.length > 0 && operator.length == 0 && scanner.isAtEnd) {
		return ofTagTypePredicate(firstIdent);
	} else {
		if ([operator isEqualToString:@":"]) {
			return andCombinatorPredicate(ofTagTypePredicate(firstIdent),
                                          predicateFromPseudoClass(scanner, parsedString, error));
		} else if ([operator isEqualToString:@"::"]) {
			// We don't support *any* pseudo-elements.
			return nil;
		} else if ([operator isEqualToString:@"["]) {
			scanAttributePredicate(scanner, parsedString, error);
		} else if (operator.length == 0) {
			//Whitespace combinator
			//y descendant of an x
			return andCombinatorPredicate(predicateFromScanner(scanner, parsedString, error),
                                          descendantOfPredicate(ofTagTypePredicate(firstIdent)));
		} else if ([operator isEqualToString:@">"]) {
			return andCombinatorPredicate(predicateFromScanner(scanner, parsedString, error),
                                          childOfOtherPredicatePredicate(ofTagTypePredicate(firstIdent)));
		} else if ([operator isEqualToString:@"+"]) {
			return andCombinatorPredicate(predicateFromScanner(scanner, parsedString, error),
                                          adjacentSiblingPredicate(ofTagTypePredicate(firstIdent)));
		} else if ([operator isEqualToString:@"~"]) {
			return andCombinatorPredicate(predicateFromScanner(scanner, parsedString, error),
                                          generalSiblingPredicate(ofTagTypePredicate(firstIdent)));
		} else if ([operator isEqualToString:@"."]) {
			NSString *className = scanIdentifier(scanner, parsedString, error);
			return isKindOfClassPredicate(className);
		} else if ([operator isEqualToString:@"#"]) {
			NSString *idName = scanIdentifier(scanner, parsedString, error);
			return hasIDPredicate(idName);
		}
	}
	return nil;
}

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSString **parsedString, NSError **error)
{
	//Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
    scanner.caseSensitive = NO; //Section 3 states that in HTML parsing, selectors are case-insensitive
	
	return predicateFromScanner(scanner, parsedString, error);
}

@interface HTMLSelector ()

@property (copy, nonatomic) HTMLSelectorPredicate predicate;
@property (copy, nonatomic) NSString *parsedString;
@property (strong, nonatomic) NSError *parseError;

@end

@implementation HTMLSelector

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
	return [self nodesForSelector:[HTMLSelector selectorForString:selectorString]];
}

- (NSArray *)nodesForSelector:(HTMLSelector *)selector
{
	NSAssert(!selector.parseError, @"Attempted to use selector with error: %@", selector.parseError);
    
	NSMutableArray *ret = [NSMutableArray new];
	for (HTMLElementNode *node in self.treeEnumerator) {
		if ([node isKindOfClass:[HTMLElementNode class]] && selector.predicate(node)) {
			[ret addObject:node];
		}
	}
	return ret;}

@end

HTMLNthExpression HTMLNthExpressionMake(NSInteger n, NSInteger c)
{
    return (HTMLNthExpression){ .n = n, .c = c };
}

BOOL HTMLNthExpressionEqualToNthExpression(HTMLNthExpression a, HTMLNthExpression b)
{
    return a.n == b.n && a.c == b.c;
}

const HTMLNthExpression HTMLNthExpressionOdd = (HTMLNthExpression){ .n = 2, .c = 1 };

const HTMLNthExpression HTMLNthExpressionEven = (HTMLNthExpression){ .n = 2, .c = 0 };

const HTMLNthExpression HTMLNthExpressionInvalid = (HTMLNthExpression){ .n = 0, .c = 0 };
