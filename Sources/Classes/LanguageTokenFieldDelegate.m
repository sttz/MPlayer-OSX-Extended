//
//  LanguageTokenFieldDelegate.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 17.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "LanguageTokenFieldDelegate.h"
#import "LanguageCodes.h"

@implementation LanguageTokenFieldDelegate

- (void) awakeFromNib
{
	NSMutableCharacterSet *set = [NSMutableCharacterSet whitespaceCharacterSet];
	[set formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	
	[audioLanguageField setTokenizingCharacterSet:set];
	[subtitleLanguageField setTokenizingCharacterSet:set];
}

- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString
{
	return [[LanguageCodes sharedInstance] threeLetterCodeForToken:editingString];
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject
{
	return [[LanguageCodes sharedInstance] nameForCode:representedObject];
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
	NSMutableArray *validatedTokens = [NSMutableArray new];
	
	for (NSString *code in tokens) {
		if ([code length] == 3 && [[LanguageCodes sharedInstance] nameForCode:code])
			[validatedTokens addObject:code];
	}
	
	return validatedTokens;
}

@end
