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

static LanguageCodes *instance;

@implementation LanguageCodes

+ (LanguageCodes *)sharedInstance {
	
	if (!instance)
		instance = [LanguageCodes new];
	
	return instance;
}

- (id)init {
	
	self = [super init];
	
	if (!self)
		return self;
	
	// Try to load cached archive
	NSString *archive_path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"iso-639.plist"];
	
	NSData *archive_data = [NSData dataWithContentsOfFile:archive_path];
	if (archive_data) {
		NSString *archive_error;
		NSDictionary *archive = (NSDictionary *)[NSPropertyListSerialization
									propertyListFromData:archive_data 
									mutabilityOption:NSPropertyListImmutable 
									format:NULL 
									errorDescription:&archive_error];
		
		if (archive_error) {
			[Debug log:ASL_LEVEL_WARNING withMessage:@"Language code cache couldn't be read, reading tab file (%@).",archive_error];
			[archive_error release];
		
		} else {
			codes_2 = [[archive objectForKey:@"codes_2"] retain];
			codes_3 = [[archive objectForKey:@"codes_3"] retain];
			codes_2_to_3 = [[archive objectForKey:@"codes_2_to_3"] retain];
			return self;
		}
	} else
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Language code cache couldn't be found or opened, reading tab file."];
	
	// Load languages codes
	NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"iso-639-3.tab"];
	NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
	
	if (content == nil) {
		[Debug log:ASL_LEVEL_WARNING withMessage:@"Failed to read language codes at %@", path];
		return self;
	}
	
	// Parse file
	NSMutableDictionary *m_codes_2 = [[NSMutableDictionary dictionary] retain];
	NSMutableDictionary *m_codes_3 = [[NSMutableDictionary dictionary] retain];
	NSMutableDictionary *m_codes_2_to_3 = [[NSMutableDictionary dictionary] retain];
	NSArray  *lines = [content componentsSeparatedByString:@"\n"];
	NSEnumerator *theEnum = [lines objectEnumerator];
	NSString *theLine;
	
	// Skip first line (table index)
	[theEnum nextObject];
	
	while (nil != (theLine = [theEnum nextObject]) )
	{
		if (![theLine isEqualToString:@""])
		{
			NSArray *values = [theLine componentsSeparatedByString:@"\t"];
			
			if ([[values objectAtIndex:0] isEqualToString:@""] || [[values objectAtIndex:6] isEqualToString:@""])
				continue;
			
			// Add 639-3 code
			[m_codes_3 setObject:[values objectAtIndex:6] forKey:[values objectAtIndex:0]];
			
			// Add 639-2/B bibliographic code (differs from 639-3)
			if (![[values objectAtIndex:1] isEqualToString:@""] 
					&& ![[values objectAtIndex:0] isEqualToString:[values objectAtIndex:1]])
				[m_codes_3 setObject:[values objectAtIndex:6] forKey:[values objectAtIndex:1]];
			
			if ([[values objectAtIndex:3] isEqualToString:@""])
				continue;
			
			// Add 639-1 code
			[m_codes_2 setObject:[values objectAtIndex:6] forKey:[values objectAtIndex:3]];
			
			// Add 639-1 to 639-2 mapping
			[m_codes_2_to_3 setObject:[values objectAtIndex:0] forKey:[values objectAtIndex:3]];
		}
	}
	
	// Try to cache as archive
	NSDictionary *codes = [NSDictionary dictionaryWithObjectsAndKeys:
							m_codes_2, @"codes_2", m_codes_3, @"codes_3", m_codes_2_to_3, @"codes_2_to_3", nil];
	NSString *error;
	NSData *data =		  [NSPropertyListSerialization dataFromPropertyList:codes
							format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
	
	if (!error)
		[data writeToFile:archive_path atomically:YES];
	else {
		[Debug log:ASL_LEVEL_ERR withMessage:@"Cannot cache language codes: %@",error];
		[error release];
	}
	
	codes_2 = m_codes_2;
	codes_3 = m_codes_3;
	codes_2_to_3 = m_codes_2_to_3;
	return self;
	
}

- (NSString *)resolveCode:(NSString *)code {
	
	// Check code length
	if ([code length] != 2 && [code length] != 3)
		return [NSString stringWithFormat:@"Unknown (%@)", code];
	
	// Fallback if no codes are loaded
	if (codes_2 == nil)
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

- (NSString *)threeLetterCodeForToken:(NSString *)token {
	
	// Fallback if no codes are loaded
	if (codes_3 == nil)
		return nil;
	
	NSString *code = [token lowercaseString];
	
	// Look for three-letter code
	if ([code length] == 3 && [codes_3	objectForKey:code])
		return code;
	// Look for two-letter code
	if ([code length] == 2 && [codes_2_to_3 objectForKey:code])
		return [codes_2_to_3 objectForKey:code];
	// Look for language name
	NSArray *keys = [codes_3 allKeysForObject:[token capitalizedString]];
	if ([keys count] > 0)
		return [keys objectAtIndex:0];
	else
		return nil;
}

- (NSString *)nameForCode:(NSString *)code {
	
	// Fallback if no codes are loaded
	if (codes_2 == nil)
		return nil;
	
	// Three-letter code
	if ([code length] == 3)
		return [codes_3 objectForKey:code];
	// Two-letter code
	if ([code length] == 2)
		return [codes_2 objectForKey:code];
	
	return nil;
}

- (void)dealloc
{
	[codes_2 release];
	[codes_3 release];
	[codes_2_to_3 release];
	
	[super dealloc];
}

@end
