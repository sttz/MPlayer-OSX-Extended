//
//  LanguageCodes.m
//  MPlayer OSX
//
//  Created by Adrian on 02.08.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "LanguageCodes.h"

static NSMutableDictionary *codes_2;
static NSMutableDictionary *codes_3;

@implementation LanguageCodes

+ (BOOL)loadCodes {
	
	// Load languages codes
	NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"iso-639-3.tab"];
	NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
	
	if (content == nil) {
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Failed to read language codes at %@", path];
		return FALSE;
	}
	
	// Parse file
	codes_2 = [[NSMutableDictionary dictionary] retain];
	codes_3 = [[NSMutableDictionary dictionary] retain];
	NSArray  *lines = [content componentsSeparatedByString:@"\n"];
	NSEnumerator *theEnum = [lines objectEnumerator];
	NSString *theLine;
	
	while (nil != (theLine = [theEnum nextObject]) )
	{
		if (![theLine isEqualToString:@""])
		{
			NSArray *values = [theLine componentsSeparatedByString:@"\t"];
			
			if ([[values objectAtIndex:0] isEqualToString:@""] || [[values objectAtIndex:6] isEqualToString:@""])
				continue;
			
			// Add 639-3 code
			[codes_3 setObject:[values objectAtIndex:6] forKey:[values objectAtIndex:0]];
			
			if ([[values objectAtIndex:3] isEqualToString:@""])
				continue;
			
			// Add 639-2 code
			[codes_2 setObject:[values objectAtIndex:6] forKey:[values objectAtIndex:3]];
			
		}
	}
	
	return TRUE;
	
}

+ (NSString *)resolveCode:(NSString *)code {
	
	// Check code length
	if ([code length] != 2 && [code length] != 3)
		return [NSString stringWithFormat:@"Unknown (%@)", code];
	
	// Initialize
	if (codes_2 == nil && ![LanguageCodes loadCodes])
		return [NSString stringWithFormat:@"(%@)", code];
	
	NSString *name;
	
	// Try to find code
	if ([code length] == 2)
		name = [codes_2 objectForKey:code];
	else
		name = [codes_3 objectForKey:code];
	
	if (name == nil)
		return [NSString stringWithFormat:@"Unknown (%@)", code];
	else
		return name;
	
}

@end
