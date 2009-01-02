/*  
 *  LanguageCodes.m
 *  MPlayerOSX Extended
 *  
 *  Created on 02.08.2008
 *  
 *  Description:
 *	Class used to read iso-639-3 language codes from a tab file and to provide 
 *  a mean to resolve those codes to languages names.
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

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

+ (void)releaseCodes
{
	[codes_2 release];
	[codes_3 release];
}

@end
