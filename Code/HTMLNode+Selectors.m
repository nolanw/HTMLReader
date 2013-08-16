//
//  HTMLNode+Selectors.m
//  HTMLReader
//
//  Created by Chris Williams on 8/13/13.
//  Copyright (c) 2013 Nolan Waite. All rights reserved.
//

#import "HTMLNode+Selectors.h"
#import "selector-tokenizer.h"
#import "selector-enum.h"


#define CSSSelectorPredicateGen CSSSelectorPredicate


//@protocol CSSSelectorPredicate <NSObject>
//
//-(BOOL)nodePassesPredicate:(HTMLElementNode*)node;
//
//@end
//
//
//@interface Thing : NSObject<CSSSelectorPredicate>  @end



/*
 
 group -> selector [ COMMA S* selector ]*
 
 simple_selector_sequence
 : [ type_selector | universal ]
 [ HASH | class | attrib | pseudo | negation ]*
 | [ HASH | class | attrib | pseudo | negation ]+
 ;
 
 
 */





CSSSelectorPredicateGen truePredicate()
{
	#pragma GCC diagnostic ignored "-Wunused-parameter"
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return TRUE;
	};
}

CSSSelectorPredicateGen falsePredicate()
{
	#pragma GCC diagnostic ignored "-Wunused-parameter"
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return FALSE;
	};
}

CSSSelectorPredicateGen negatePredicate(CSSSelectorPredicate predicate)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return !predicate(node);
	};
}

#pragma mark - Combinators

CSSSelectorPredicateGen andCombinatorPredicate(NSArray *predicates)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		for (CSSSelectorPredicate predicate in predicates)
		{
			//Return NO on first predicate failure
			if (predicate(node) == FALSE)
			{
				return NO;
			}
		}
		
		return YES;
	};
}

CSSSelectorPredicateGen orCombinatorPredicate(NSArray *predicates)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		for (CSSSelectorPredicate predicate in predicates)
		{
			//Return YES on first predicate success
			if (predicate(node) == TRUE)
			{
				return YES;
			}
		}
		
		return NO;
	};
}


#pragma mark

CSSSelectorPredicateGen ofTagTypePredicate(NSString* tagType)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [[node tagName] isEqualToString:tagType];
		
	};
}


CSSSelectorPredicateGen childOfTagTypePredicate(NSString* tagType)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [node.parentNode isKindOfClass:[HTMLElementNode class]] && [[(HTMLElementNode*)node.parentNode tagName] isEqualToString:tagType];
		
	};
}

CSSSelectorPredicateGen descendantOfPredicate(CSSSelectorPredicate parentPredicate)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		HTMLNode *parentNode = node.parentNode;
		
		while (parentNode != nil)
		{
			if ([parentNode isKindOfClass:[HTMLElementNode class]] && parentPredicate((HTMLElementNode*)parentNode) == TRUE)
			{
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
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return [node childNodes].count == 0;
	};
}


#pragma mark - Attribute Predicates

CSSSelectorPredicateGen hasAttributePredicate(NSString* attributeName)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [node attributeNamed:attributeName] != nil;
		
	};
}

CSSSelectorPredicateGen attributeIsExactlyPredicate(NSString* attributeName, NSString* attributeValue)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [[node attributeNamed:attributeName].value isEqualToString:attributeValue];
		
	};
}


CSSSelectorPredicateGen attributeStartsWithPredicate(NSString* attributeName, NSString* attributeValue)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [[node attributeNamed:attributeName].value hasPrefix:attributeValue];
		
	};
}

CSSSelectorPredicateGen attributeContainsPredicate(NSString* attributeName, NSString* attributeValue)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [[node attributeNamed:attributeName].value rangeOfString:attributeValue].length != 0;
		
	};
}

CSSSelectorPredicateGen attributeEndsWithPredicate(NSString* attributeName, NSString* attributeValue)
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		return [[node attributeNamed:attributeName].value hasSuffix:attributeValue];
		
	};
}


CSSSelectorPredicateGen attributeIsExactlyAnyOf(NSString* attributeName, NSArray* attributeValues)
{
	NSMutableArray *arrayOfPreicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	
	for (NSString *attributeValue in attributeValues)
	{
		[arrayOfPreicates addObject:attributeIsExactlyPredicate(attributeName, attributeValue)];
	}
	
	return orCombinatorPredicate(arrayOfPreicates);
}

CSSSelectorPredicateGen attributeStartsWithAnyOf(NSString* attributeName, NSArray* attributeValues)
{
	NSMutableArray *arrayOfPreicates = [NSMutableArray arrayWithCapacity:attributeValues.count];
	
	for (NSString *attributeValue in attributeValues)
	{
		[arrayOfPreicates addObject:attributeStartsWithPredicate(attributeName, attributeValue)];
	}
	
	return orCombinatorPredicate(arrayOfPreicates);
}


#pragma mark Attribute Helpers

CSSSelectorPredicateGen isKindOfClassPredicate(NSString *classname)
{
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
	return (CSSSelectorPredicate)^(HTMLNode *node){

		NSArray *parentChildren = [node parentNode].childNodes;
		
		uint nodeIndex = [parentChildren indexOfObject:node];
		
		if (nodeIndex != 0 && siblingTest([parentChildren objectAtIndex:nodeIndex-1]) == TRUE)
		{
			return YES;
		}
		else
		{
			return NO;
		}
		
	};
}

CSSSelectorPredicateGen generalSiblingPredicate(CSSSelectorPredicate siblingTest)
{
	return (CSSSelectorPredicate)^(HTMLNode *node)
	{
		for (HTMLNode *sibling in [node.parentNode childNodes])
		{
			if (sibling == node)
			{
				break;
			}
			else if ([sibling isKindOfClass:[HTMLElementNode class]] && siblingTest(siblingTest) == TRUE)
			{
				return YES;
			}
		}
		
		return NO;
	};
}


#pragma mark nth Child Predicates

/*
 
 */

CSSSelectorPredicateGen isNthChildPredicate(int m, int b, BOOL fromLast)
{
	return (CSSSelectorPredicate)^(HTMLNode *node){
		
		//Index relative to start/end
		int nthPosition;
		
		if (fromLast)
		{
			nthPosition = [[node parentNode].childNodes indexOfObject:node] + 1;
		}
		else
		{
			nthPosition = [[node parentNode].childNodes count] - [[node parentNode].childNodes indexOfObject:node];
		}
		
		return (nthPosition - b) % m == 0;
		
	};
}

CSSSelectorPredicateGen isNthChildOfTypePredicate(int m, int b, BOOL fromLast)
{
	return (CSSSelectorPredicate)^(HTMLNode *node){
		
		NSEnumerator *enumerator = fromLast ? [[node parentNode].childNodes reverseObjectEnumerator] : [[node parentNode].childNodes objectEnumerator];
		
		NSMutableArray *ret = [NSMutableArray new];
		
		int count = 0;
		HTMLElementNode *currentNode;
		
		while (currentNode = [enumerator nextObject])
		{
			BOOL validIndex;
			
			count++;
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
	return (CSSSelectorPredicate)^(HTMLNode *node){
		
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
	return (CSSSelectorPredicate)^(HTMLNode *node){

		return [node.parentNode childNodes].count == 1;
		
	};
}

CSSSelectorPredicateGen isOnlyChildOfTypePredicate()
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node){
		
		for (HTMLNode *sibling in [node.parentNode childNodes])
		{
			if (sibling != node && [sibling isKindOfClass:[HTMLElementNode class]] && [[(HTMLElementNode*)sibling tagName] isEqualToString:node.tagName])
			{
				return NO;
			}
		}
		
		return YES;
	};
}


CSSSelectorPredicateGen isRootPredicate()
{
	return (CSSSelectorPredicate)^(HTMLElementNode *node)
	{
		return node.parentNode == nil;
	};
}



#pragma mark Parse
extern struct mb parseNth(NSString *nthString)
{
	nthString = [[nthString lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([nthString isEqualToString:@"odd"])
	{
		return (struct mb){2, 1};
	}
	else if ([nthString isEqualToString:@"even"])
	{
		return (struct mb){2, 0};
	}
	else if ([nthString rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"123456789 n+-"] invertedSet]].length != 0)
	{
		return (struct mb){0, 0};
	}
	
	NSArray *valueSplit = [nthString componentsSeparatedByString:@"n"];

	if (valueSplit.count > 2) {
		//Multiple ns, fail
		return (struct mb){0, 0};
	}
	else if (valueSplit.count == 2)
	{		
		if ([valueSplit[0] length] == 0)
		{
			//"n" was defined, but no multiplier ie "n + 2)
			return (struct mb){ 1, [valueSplit[1] integerValue] };
		}
		else if ([valueSplit[0] isEqualToString:@"-"])
		{
			//"n" was defined, and only "-" was given as a multiplier
			return (struct mb){ -1, [valueSplit[1] integerValue] };
		}
		else
		{
			return (struct mb){ [valueSplit[0] integerValue], [valueSplit[1] integerValue] };
		}
	}
	else
	{
		//"n" not found, use whole string as b
		return (struct mb){0, [nthString integerValue]};
	}
}

static NSString* scanFunctionInterior(NSScanner *functionScanner)
{
	NSString *openParen;
	
	[functionScanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"("] intoString:&openParen];
	
	if (openParen == nil)
	{
		return nil;
	}
	
	NSString *interior;
	
	[functionScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@")"] intoString:&interior];
	
	if (interior == nil)
	{
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
	
	if (pseudo == nil && [pseudoScanner isAtEnd] == NO)
	{
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
		
		if (output.m == 0 && output.b == 0)
		{
			return nil;
		}
		else
		{
			return nth(output);
		}
		
	}
	
	if ([pseudo isEqualToString:@"not"])
	{
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

NSArray* filterWithPredicate(NSEnumerator *nodes, CSSSelectorPredicate predicate)
{
	NSMutableArray *ret = [NSMutableArray new];
	
	for (HTMLElementNode *node in nodes) {
		
		if ([node isKindOfClass:[HTMLElementNode class]] && predicate(node) == TRUE)
		{
			[ret addObject:node];
		}
	}
	
	return ret;
}




CSSSelectorPredicateGen predicateFromScanner(NSScanner* scanner)
{	
	//Spec at:
	//http://www.w3.org/TR/css3-selectors/
		
	//Spec: Only the characters "space" (U+0020), "tab" (U+0009), "line feed" (U+000A), "carriage return" (U+000D), and "form feed" (U+000C) can occur in whitespace
	//
	//whitespaceAndNewlineCharacterSet == (U+0020) and tab (U+0009) and the newline and nextline characters (U+000A–U+000D, U+0085).
	NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	
	//Combinators are: whitespace, "greater-than sign" (U+003E, >), "plus sign" (U+002B, +) and "tilde" (U+007E, ~)
	//NSCharacterSet *combinatorSet = [NSCharacterSet characterSetWithCharactersInString:@">+~"];
	
	
	NSMutableCharacterSet *operatorCharacters = [NSMutableCharacterSet characterSetWithCharactersInString:@">+~.:#["];
	[operatorCharacters formUnionWithCharacterSet:whitespaceSet];
	

	NSString *firstIdent;
	
	[scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&firstIdent];
	firstIdent = [firstIdent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSString *operator;
	
	[scanner scanUpToCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:&operator];
	operator = [operator stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	
	if ([firstIdent length] > 0 && [operator length] == 0)
	{
		if ([firstIdent isEqualToString:@"*"])
		{
			return truePredicate();
		}
		else
		{
			return ofTagTypePredicate(firstIdent);
		}
	}
	else
	{
		if ([operator length] == 0)
		{
			//Whitespace combinator
			//y descendant of an x
			//return andCombinatorPredicate(@[ofTagTypePredicate(secondIdent), descendantOfPredicate(ofTagTypePredicate(firstIdent))]);
		}
		else if ([operator isEqualToString:@">"])
		{
			
		}
		else if ([operator isEqualToString:@"+"])
		{
			
		}
		else if ([operator isEqualToString:@"~"])
		{
			
		}
		else if ([operator isEqualToString:@":"])
		{
			return predicateFromPseudoClass(scanner);
		}
		else if ([operator isEqualToString:@"::"])
		{
			
		}
			
	}
	
	
	return nil;
	

//	 char selectorChars[1000];
//	 NSUInteger length;
//	 
//	 //Currently only supports ASCII characters
//	 //will need a Unicode Flex build to use anything else: http://csliu.com/2009/04/unicode-support-in-flex/
//	 [selectorString getBytes:selectorChars maxLength:1000 usedLength:&length encoding:NSASCIIStringEncoding options:0 range:NSMakeRange(0, [selectorString length]) remainingRange:nil];
//	 
//	 yyscan_t scanner;
//	 SelectorTokenType token;
//	 
//	 yylex_init(&scanner);
//	 
//	 //YY_BUFFER_STATE buffer = yy_scan_buffer(, length, scanner);
//	 
//	 yy_scan_string(selectorChars, scanner);
//	 
//	 char * tagA = nil;
//	 char * tagB = nil;
//	 char * operator = nil;
//	 
//	 while ((token=yylex(scanner)) > 0)
//	 {
//	 char * text = yyget_text(scanner);
//	 
//	 printf("tok=%d  yytext=%s\n", token, text);
//	 
//	 }
//	 
//	 
//	 yylex_destroy(scanner);
//	 
	 
	 
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

@implementation HTMLNode (Selectors)

-(NSArray*)nodesForSelectorString:(NSString*)selectorString
{
	return [self nodesForSelectorFilter:SelectorFunctionForString(selectorString)];
}

-(NSArray*)nodesForSelectorFilter:(CSSSelectorPredicate)filter
{
	return filterWithPredicate(self.treeEnumerator, filter);
}

@end





/*

 //flex --noyywrap --batch --never-interactive --noline --reentrant --header-file="selector-tokenizer.h" --outfile="selector-tokenizer.c" --prefix=sel

 

 %option case-insensitive batch never-interactive noline noyywrap reentrant  header-file="selector-tokenizer.h" outfile="selector-tokenizer.c"
 
 ident     [-]?{nmstart}{nmchar}*
 name      {nmchar}+
 nmstart   [_a-z]|{nonascii}|{escape}
 nonascii  [^\0-\177]
 unicode   \\[0-9a-f]{1,6}(\r\n|[ \n\r\t\f])?
 escape    {unicode}|\\[^\n\r\f0-9a-f]
 nmchar    [_a-z0-9-]|{nonascii}|{escape}
 num       [0-9]+|[0-9]*\.[0-9]+
 string    {string1}|{string2}
 string1   \"([^\n\r\f\\"]|\\{nl}|{nonascii}|{escape})*\"
 string2   \'([^\n\r\f\\']|\\{nl}|{nonascii}|{escape})*\'
 invalid   {invalid1}|{invalid2}
 invalid1  \"([^\n\r\f\\"]|\\{nl}|{nonascii}|{escape})*
 invalid2  \'([^\n\r\f\\']|\\{nl}|{nonascii}|{escape})*
 nl        \n|\r\n|\r|\f
 w         [ \t\r\n\f]*
 
 D         d|\\0{0,4}(44|64)(\r\n|[ \t\r\n\f])?
 E         e|\\0{0,4}(45|65)(\r\n|[ \t\r\n\f])?
 N         n|\\0{0,4}(4e|6e)(\r\n|[ \t\r\n\f])?|\\n
 O         o|\\0{0,4}(4f|6f)(\r\n|[ \t\r\n\f])?|\\o
 T         t|\\0{0,4}(54|74)(\r\n|[ \t\r\n\f])?|\\t
 V         v|\\0{0,4}(58|78)(\r\n|[ \t\r\n\f])?|\\v
 
 %%
 
 [ \t\r\n\f]+     return SPACE;
 
 "~="             return INCLUDES;
 "|="             return DASHMATCH;
 "^="             return PREFIXMATCH;
 "$="             return SUFFIXMATCH;
 "*="             return SUBSTRINGMATCH;
 {ident}          return IDENT;
 {string}         return STRING;
 {ident}"("       return FUNCTION;
 {num}            return NUMBER;
 "#"{name}        return HASH;
 {w}"+"           return PLUS;
 {w}">"           return GREATER;
 {w}","           return COMMA;
 {w}"~"           return TILDE;
 ":"{N}{O}{T}"("  return NOT;
 @{ident}         return ATKEYWORD;
 {invalid}        return INVALID;
 {num}%           return PERCENTAGE;
 {num}{ident}     return DIMENSION;
 "<!--"           return CDO;
 "-->"            return CDC;
 
 \/\*[^*]*\*+([^/*][^*]*\*+)*\/

.                return *yytext;




*/