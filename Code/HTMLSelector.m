//
//  HTMLSelector.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//
// Impliments CSS Selectors Level 3 from:
// http://www.w3.org/TR/css3-selectors/

#import "HTMLSelector.h"

typedef BOOL (^HTMLSelectorPredicate)(HTMLElementNode *node);
typedef HTMLSelectorPredicate HTMLSelectorPredicateGen;

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString,
                                                       NSString **parsedString,
                                                       NSError **error);

static NSError * ParseError(NSString *reason, NSString *string, NSUInteger position)
{
    /*
	 String that looks like
	 
	 Error near character 4: Pseudo elements unsupported
     tag::
        ^
     
     */
    NSString *caretString = [@"^" stringByPaddingToLength:position+1 withString:@" " startingAtIndex:0];
    NSString *failureReason = [NSString stringWithFormat:@"Error near character %d: %@\n\n\t%@\n\t\%@",
                               position,
                               reason,
                               string,
                               caretString];
    
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: reason,
                                NSLocalizedFailureReasonErrorKey: failureReason,
                                HTMLSelectorInputStringErrorKey: string,
                                HTMLSelectorLocationErrorKey: @(position),
                                };
    return [NSError errorWithDomain:HTMLSelectorErrorDomain code:1 userInfo:userInfo];
}

HTMLSelectorPredicateGen negatePredicate(HTMLSelectorPredicate predicate)
{
	if (!predicate) return nil;
	
	return ^BOOL(HTMLElementNode *node) {
		return !predicate(node);
	};
}

#pragma mark - Combinators

HTMLSelectorPredicateGen bothCombinatorPredicate(HTMLSelectorPredicate a, HTMLSelectorPredicate b)
{
	//There was probably an error somewhere else
	//in parsing, so return nil here
	if (!a || !b) return nil;
	
	return ^BOOL(HTMLElementNode *node)
	{
		return a(node) && b(node);
	};
}

HTMLSelectorPredicateGen andCombinatorPredicate(NSArray *predicates)
{
    return ^(HTMLElementNode *node) {
        for (HTMLSelectorPredicate predicate in predicates) {
            if (!predicate(node)) {
                return NO;
            }
        }
        return YES;
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

HTMLSelectorPredicateGen isTagTypePredicate(NSString *tagType)
{
	if ([tagType isEqualToString:@"*"]) {
		return ^(__unused HTMLElementNode *node) {
            return YES;
        };
	} else {
		return ^BOOL(HTMLElementNode *node) {
			return [node.tagName compare:tagType options:NSCaseInsensitiveSearch] == NSOrderedSame;
		};
	}
}

HTMLSelectorPredicateGen childOfOtherPredicatePredicate(HTMLSelectorPredicate parentPredicate)
{
	if (!parentPredicate) return nil;
	
	return ^BOOL(HTMLElementNode *node) {
		return ([node.parentNode isKindOfClass:[HTMLElementNode class]] &&
                parentPredicate((HTMLElementNode *)node.parentNode));
	};
}

HTMLSelectorPredicateGen descendantOfPredicate(HTMLSelectorPredicate parentPredicate)
{
	if (!parentPredicate) return nil;
	
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

HTMLSelectorPredicateGen isEmptyPredicate(void)
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

static NSCharacterSet * SelectorsWhitespaceSet(void)
{
    // http://www.w3.org/TR/css3-selectors/#whitespace
    return [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r\f"];
}

HTMLSelectorPredicateGen attributeContainsExactWhitespaceSeparatedValuePredicate(NSString *attributeName, NSString *attributeValue)
{
    NSCharacterSet *whitespace = SelectorsWhitespaceSet();
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
        HTMLAttribute *attribute = [node attributeNamed:attributeName];
		return attribute && [attribute.value rangeOfString:attributeValue].location != NSNotFound;
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

#pragma mark Sibling Predicates

HTMLSelectorPredicateGen adjacentSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
	return ^BOOL(HTMLElementNode *node) {
		NSArray *parentChildren = node.parentNode.childElementNodes;
		NSUInteger nodeIndex = [parentChildren indexOfObject:node];
		return nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex - 1]);
	};
}

HTMLSelectorPredicateGen generalSiblingPredicate(HTMLSelectorPredicate siblingTest)
{
	if (!siblingTest) return nil;
	
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

#pragma mark nth- Predicates

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

HTMLSelectorPredicateGen isNthChildOfTypePredicate(HTMLNthExpression nth, HTMLSelectorPredicate typePredicate, BOOL fromLast)
{
	if (!typePredicate) return nil;
	
	return ^BOOL(HTMLElementNode *node) {
		id <NSFastEnumeration> enumerator = (fromLast
                                             ? node.parentNode.childElementNodes.reverseObjectEnumerator
                                             : node.parentNode.childElementNodes);
		NSInteger count = 0;
		for (HTMLElementNode *currentNode in enumerator) {
			if (typePredicate(currentNode)) {
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

HTMLSelectorPredicateGen isFirstChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), NO);
}

HTMLSelectorPredicateGen isLastChildPredicate(void)
{
	return isNthChildPredicate(HTMLNthExpressionMake(0, 1), YES);
}

HTMLSelectorPredicateGen isFirstChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, NO);
}

HTMLSelectorPredicateGen isLastChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return isNthChildOfTypePredicate(HTMLNthExpressionMake(0, 1), typePredicate, YES);
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
        [predicates addObject:isTagTypePredicate(tagName)];
    }
    return orCombinatorPredicate(predicates);
}

HTMLSelectorPredicateGen isDisabledPredicate(void)
{
    // http://www.whatwg.org/specs/web-apps/current-work/multipage/association-of-controls-and-forms.html#concept-fe-disabled
    HTMLSelectorPredicate descendantOfDisabledFieldset = descendantOfPredicate(bothCombinatorPredicate(isTagTypePredicate(@"fieldset"),
																									   hasAttributePredicate(@"disabled") ));
    HTMLSelectorPredicate descendantOfFirstLegendOfDisabledFieldset = descendantOfPredicate(bothCombinatorPredicate(isFirstChildOfTypePredicate(isTagTypePredicate(@"legend")), descendantOfDisabledFieldset));
    return andCombinatorPredicate(@[ isFormControlPredicate(),
                                  orCombinatorPredicate(@[ hasAttributePredicate(@"disabled"),
                                                        andCombinatorPredicate(@[ descendantOfDisabledFieldset, negatePredicate(descendantOfFirstLegendOfDisabledFieldset) ]) ]) ]);
}

HTMLSelectorPredicateGen isEnabledPredicate(void)
{
	return negatePredicate(isDisabledPredicate());
}

HTMLSelectorPredicateGen isCheckedPredicate(void)
{
	return orCombinatorPredicate(@[hasAttributePredicate(@"checked"), hasAttributePredicate(@"selected")]);
}

#pragma mark - Only Child

HTMLSelectorPredicateGen isOnlyChildPredicate(void)
{
	return ^BOOL(HTMLNode *node) {
		return [node.parentNode childElementNodes].count == 1;
	};
}

HTMLSelectorPredicateGen isOnlyChildOfTypePredicate(HTMLSelectorPredicate typePredicate)
{
	return bothCombinatorPredicate(isFirstChildOfTypePredicate(typePredicate), isLastChildOfTypePredicate(typePredicate));
}

HTMLSelectorPredicateGen isRootPredicate(void)
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
	
	NSArray *valueSplit = [nthString componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]];
	
	if (valueSplit.count == 0 || valueSplit.count > 2) {
		//No Ns or multiple Ns, fail
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

static NSString * scanFunctionInterior(NSScanner *scanner, NSError **error)
{
	BOOL ok;
    
    ok = [scanner scanString:@"(" intoString:nil];
	if (!ok) {
		*error = ParseError(@"Expected ( to start function", scanner.string, scanner.scanLocation);
		return nil;
	}
	
    NSString *interior;
	ok = [scanner scanUpToString:@")" intoString:&interior];
	if (!ok) {
		*error = ParseError(@"Expected ) to end function", scanner.string, scanner.scanLocation);
		return nil;
	}
    
    [scanner scanString:@")" intoString:nil];
	return interior;
}

static HTMLSelectorPredicateGen scanPredicateFromPseudoClass(NSScanner *scanner,
														 HTMLSelectorPredicate typePredicate,
                                                         __unused NSString **parsedString,
                                                         NSError **error)
{
	typedef HTMLSelectorPredicate (^CSSThing)(HTMLNthExpression nth);
    BOOL ok;
    
	NSString *pseudo;
	
	//Todo Can't assume the end of the pseudo is the end of the string
	ok = [scanner scanUpToString:@"(" intoString:&pseudo];
	if (!ok && !scanner.isAtEnd) {
		pseudo = [scanner.string substringFromIndex:scanner.scanLocation];
		scanner.scanLocation = scanner.string.length - 1;
	}
	
	//Case-insensitively look for pseudo classes
	pseudo = [pseudo lowercaseString];
	
	static NSDictionary *simplePseudos = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		simplePseudos = @{
						  @"first-child": isFirstChildPredicate(),
						  @"last-child": isLastChildPredicate(),
						  @"only-child": isOnlyChildPredicate(),
						  
						  @"empty": isEmptyPredicate(),
						  @"root": isRootPredicate(),
						  
						  @"enabled": isEnabledPredicate(),
						  @"disabled": isDisabledPredicate(),
						  @"checked": isCheckedPredicate()
						  };
	});
	
	id simple = simplePseudos[pseudo];
	if (simple) {
		return simple;
	}
	else if ([pseudo isEqualToString:@"first-of-type"]){
		return isFirstChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"last-of-type"]){
		return isLastChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo isEqualToString:@"only-of-type"]){
		return isOnlyChildOfTypePredicate(typePredicate);
	}
	else if ([pseudo hasPrefix:@"nth"]) {
		NSString *interior = scanFunctionInterior(scanner, error);
		
		if (!interior) return nil;
		
		HTMLNthExpression nth = parseNth(interior);
		
		if (HTMLNthExpressionEqualToNthExpression(nth, HTMLNthExpressionInvalid)) {
			*error = ParseError(@"Failed to parse Nth statement", scanner.string, scanner.scanLocation);
			return nil;
		}

		if ([pseudo isEqualToString:@"nth-child"]){
			return isNthChildPredicate(nth, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-child"]){
			return isNthChildPredicate(nth, YES);
		}
		else if ([pseudo isEqualToString:@"nth-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, NO);
		}
		else if ([pseudo isEqualToString:@"nth-last-of-type"]){
			return isNthChildOfTypePredicate(nth, typePredicate, YES);
		}
	}
	else if ([pseudo isEqualToString:@"not"]) {
		NSString *toNegateString = scanFunctionInterior(scanner, error);
		HTMLSelectorPredicate toNegate = SelectorFunctionForString(toNegateString, parsedString, error);
		return negatePredicate(toNegate);
	}
	
	*error = ParseError(@"Unrecognized pseudo class", scanner.string, scanner.scanLocation);
	return nil;
}


#pragma mark

NSCharacterSet *identifierCharacters()
{
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"*-"];
	[set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
	return set;
}

NSCharacterSet *operatorCharacters()
{
	//Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
	NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~.:#["];
	[set formUnionWithCharacterSet:SelectorsWhitespaceSet()];
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
    NSString *attributeValue;
    BOOL ok;
    [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"=]"]
                            intoString:&operator];
    ok = [scanner scanString:@"=" intoString:nil];
    if (ok) {
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		operator = [operator stringByTrimmingCharactersInSet:whitespace];
        operator = operator.length > 0 ? operator : @"=";
        [scanner scanCharactersFromSet:whitespace intoString:nil];
        attributeValue = scanIdentifier(scanner, parsedString, error);
        if (!attributeValue) {
            [scanner scanCharactersFromSet:whitespace intoString:nil];
            NSString *quote = [scanner.string substringWithRange:NSMakeRange(scanner.scanLocation, 1)];
            if (!([quote isEqualToString:@"\""] || [quote isEqualToString:@"'"])) {
				*error = ParseError(@"Expected quote in attribute value", scanner.string, scanner.scanLocation);
                return nil;
            }
            [scanner scanString:quote intoString:nil];
            [scanner scanUpToString:quote intoString:&attributeValue];
            [scanner scanString:quote intoString:nil];
        }
    } else {
        operator = nil;
    }
	
	[scanner scanUpToString:@"]" intoString:nil];
	ok = [scanner scanString:@"]" intoString:nil];
	if (!ok) {
		*error = ParseError(@"Expected ] to close attribute", scanner.string, scanner.scanLocation);
		return nil;
	}
	
	if ([operator length] == 0) {
		return hasAttributePredicate(attributeName);
	} else if ([operator isEqualToString:@"="]) {
		return attributeIsExactlyPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"~"]) {
        return attributeContainsExactWhitespaceSeparatedValuePredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"^"]) {
		return attributeStartsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"$"]) {
		return attributeEndsWithPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"*"]) {
		return attributeContainsPredicate(attributeName, attributeValue);
	} else if ([operator isEqualToString:@"|"]) {
		return orCombinatorPredicate(@[ attributeIsExactlyPredicate(attributeName, attributeValue),
                                        attributeStartsWithPredicate(attributeName, [attributeValue stringByAppendingString:@"-"]) ]);
	} else {
		*error = ParseError(@"Unexpected operator", scanner.string, scanner.scanLocation - operator.length);
		return nil;
	}
}

HTMLSelectorPredicateGen scanTagPredicate(NSScanner *scanner, NSString **parsedString, NSError **error)
{
	NSString *identifier = scanIdentifier(scanner, parsedString, error);
	
	return identifier ? isTagTypePredicate(identifier) : isTagTypePredicate(@"*");
}


HTMLSelectorPredicateGen scanPredicate(NSScanner *scanner, HTMLSelectorPredicate inputPredicate, NSString **parsedString, NSError **error)
{
	if (!inputPredicate) {
		inputPredicate = scanTagPredicate(scanner, parsedString, error);
		
		if (!inputPredicate) {
			*error = ParseError(@"Expected tag", scanner.string, scanner.scanLocation);
			return nil;
		}
		
		//If we're out of things to scan, all we have is this tag, no operators on it
		if (scanner.isAtEnd) return inputPredicate;
	}
	
	
	NSString *operator = scanOperator(scanner, parsedString, error);

	
	if ([operator isEqualToString:@":"]) {
		return bothCombinatorPredicate(inputPredicate,
										 scanPredicateFromPseudoClass(scanner, inputPredicate, parsedString, error));
	} else if ([operator isEqualToString:@"::"]) {
		// We don't support *any* pseudo-elements.
		*error = ParseError(@"Pseudo elements unsupported", scanner.string, scanner.scanLocation - operator.length);
		return nil;
	} else if ([operator isEqualToString:@"["]) {
		return bothCombinatorPredicate(  inputPredicate,
									     scanAttributePredicate(scanner, parsedString, error)  );
	} else if ([operator isEqualToString:@""]) {
		//Whitespace combinator
		//y descendant of an x
		return bothCombinatorPredicate(  scanPredicate(scanner, nil, parsedString, error),
										 descendantOfPredicate(inputPredicate) );
	} else if ([operator isEqualToString:@">"]) {
		return bothCombinatorPredicate(  scanPredicate(scanner, nil, parsedString, error),
										 childOfOtherPredicatePredicate(inputPredicate) );
	} else if ([operator isEqualToString:@"+"]) {
		return bothCombinatorPredicate(  scanPredicate(scanner, nil, parsedString, error),
										 adjacentSiblingPredicate(inputPredicate));
	} else if ([operator isEqualToString:@"~"]) {
		return bothCombinatorPredicate(  scanPredicate(scanner, nil, parsedString, error),
										 generalSiblingPredicate(inputPredicate));
	} else if ([operator isEqualToString:@"."]) {
		NSString *className = scanIdentifier(scanner, parsedString, error);
		return bothCombinatorPredicate(inputPredicate, isKindOfClassPredicate(className));
	} else if ([operator isEqualToString:@"#"]) {
		NSString *idName = scanIdentifier(scanner, parsedString, error);
		return bothCombinatorPredicate(inputPredicate, hasIDPredicate(idName));
	}
	else {
		*error = ParseError(@"Unexpected operator", scanner.string, scanner.scanLocation - operator.length);
		return nil;
	}
}

static HTMLSelectorPredicate SelectorFunctionForString(NSString *selectorString, NSString **parsedString, NSError **error)
{
	//Trim non-functional whitespace
	selectorString = [selectorString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // An empty selector is an invalid selector.
    if (selectorString.length == 0) {
        *error = ParseError(@"Empty selector", selectorString, 0);
        return nil;
    }
	
	NSScanner *scanner = [NSScanner scannerWithString:selectorString];
    scanner.caseSensitive = NO; //Section 3 states that in HTML parsing, selectors are case-insensitive
    scanner.charactersToBeSkipped = nil;
	
	//Scan out predicate parts and combine them
	HTMLSelectorPredicate lastPredicate = nil;
	
	do{
		lastPredicate = scanPredicate(scanner, lastPredicate, parsedString, error);
	} while (!!lastPredicate && ![scanner isAtEnd] && !*error);
	
	NSCAssert(!!lastPredicate || !!*error, @"Need either a predicate or error at this point");
	
	return lastPredicate;
}

@interface HTMLSelector ()

@property (copy, nonatomic) HTMLSelectorPredicate predicate;
@property (copy, nonatomic) NSString *parsedString;
@property (strong, nonatomic) NSError *error;

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
	self.error = error;
	self.parsedString = parsedString;
    return self;
}

- (NSString *)description
{
    if (self.predicate) {
        return [NSString stringWithFormat:@"<%@: %p '%@'>", self.class, self, self.parsedString];
    } else {
        return [NSString stringWithFormat:@"<%@: %p ERROR: '%@'>", self.class, self, self.error];
	}
}

@end

NSString * const HTMLSelectorErrorDomain = @"HTMLSelectorErrorDomain";

NSString * const HTMLSelectorInputStringErrorKey = @"HTMLSelectorInputString";

NSString * const HTMLSelectorLocationErrorKey = @"HTMLSelectorLocation";

@implementation HTMLNode (HTMLSelector)

- (NSArray *)nodesForSelectorString:(NSString *)selectorString
{
	return [self nodesForSelector:[HTMLSelector selectorForString:selectorString]];
}

- (NSArray *)nodesForSelector:(HTMLSelector *)selector
{
	NSAssert(selector.predicate, @"Attempted to use selector with error: %@", selector.error);
    
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
