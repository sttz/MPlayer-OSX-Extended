/*  
 *  CocoaAdditions.m
 *  MPlayerOSX Extended
 *  
 *  Created on 26.11.2009
 *  
 *  Description:
 *	Additions to Cocoa classes
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

#import "CocoaAdditions.h"
#import <AppKit/NSView.h>

@implementation NSString (MPEAdditions)

- (NSComparisonResult)numericSearchCompare:(NSString *)aString
{
	return [self compare:aString options:NSNumericSearch];
}

@end


@implementation NSNumber (MPEAdditions)

- (NSString *) humanReadableSizeStringValue
{
	if (self == nil)
		return nil;
	
	unsigned long long size = [self unsignedLongLongValue];
	
	if (size < 1024)
		return [NSString stringWithFormat:@"%llu bytes", size];
	else if (size < 1024 * 1024)
		return [NSString stringWithFormat:@"%.1f KB", (size/1024.0f)];
	else if (size < 1024 * 1024 * 1024)
		return [NSString stringWithFormat:@"%.1f MB", (size/(1024.0f*1024.0f))];
	else
		return [NSString stringWithFormat:@"%.1f GB", (size/(1024.0f*1024.0f*1024.0f))];
}

@end


@implementation NSView (MPEAdditions)

- (void) resizeAndArrangeSubviewsVerticallyWithPadding:(float)padding
{
	// calculate total height
	float totalHeight, maxWidth;
	for (NSView *view in [self subviews]) {
		totalHeight += [view frame].size.height;
		if ([view frame].size.width > maxWidth)
			maxWidth = [view frame].size.width;
	}
	
	totalHeight += 2*padding;
	maxWidth += 2*padding;
	
	[self setFrame:NSMakeRect(0, 0, maxWidth, totalHeight)];
	
	// arrange views from top to bottom
	for (NSView *view in [self subviews]) {
		NSRect viewframe = [view frame];
		viewframe.origin.y = totalHeight - viewframe.size.height - padding;
		viewframe.origin.x = padding;
		totalHeight -= viewframe.size.height;
		[view setFrame:viewframe];
	}
}

@end


@implementation NSDictionary (MPEAdditions)

- (BOOL)boolForKey:(NSString *)defaultName
{
	NSNumber *num = [self numberForKey:defaultName];
	if (!num) return NO;
	return [num boolValue];
}

- (NSInteger)integerForKey:(NSString *)defaultName
{
	NSNumber *num = [self numberForKey:defaultName];
	if (!num) return 0;
	return [num integerValue];
}

- (float)floatForKey:(NSString *)defaultName
{
	NSNumber *num = [self numberForKey:defaultName];
	if (!num) return 0.0f;
	return [num floatValue];
}

- (double)doubleForKey:(NSString *)defaultName
{
	NSNumber *num = [self numberForKey:defaultName];
	if (!num) return 0.0;
	return [num doubleValue];
}


- (NSObject *)objectOfType:(Class)type forKey:(NSString *)defaultName
{
	NSObject *obj = [self objectForKey:defaultName];
	if (!obj || ![obj isKindOfClass:type])
		return nil;
	return obj;
}

- (NSNumber *)numberForKey:(NSString *)defaultName
{
	return (NSNumber *)[self objectOfType:[NSNumber class] forKey:defaultName];
}

- (NSString *)stringForKey:(NSString *)defaultName
{
	return (NSString *)[self objectOfType:[NSString class] forKey:defaultName];
}

- (NSData *)dataForKey:(NSString *)defaultName
{
	return (NSData *)[self objectOfType:[NSData class] forKey:defaultName];
}

- (NSArray *)arrayForKey:(NSString *)defaultName
{
	return (NSArray *)[self objectOfType:[NSArray class] forKey:defaultName];
}

- (NSDictionary *)dictionaryForKey:(NSString *)defaultName
{
	return (NSDictionary *)[self objectOfType:[NSDictionary class] forKey:defaultName];
}

- (NSDate *)dateForKey:(NSString *)defaultName
{
	return (NSDate *)[self objectOfType:[NSDate class] forKey:defaultName];
}

- (NSColor *)colorForKey:(NSString *)defaultName
{
	NSColor *color = (NSColor *)[self objectOfType:[NSColor class] forKey:defaultName];
	if (color) return color;
	NSData *data = [self dataForKey:defaultName];
	if (data)
		color = (NSColor *)[NSUnarchiver unarchiveObjectWithData:data];
	return color;
}

- (NSMutableDictionary *)mutableDictionaryForKey:(NSString *)defaultName
{
	id dict = [self dictionaryForKey:defaultName];
	if (dict)
		dict = [[dict mutableCopy] autorelease];
	return dict;
}

- (NSMutableArray *)mutableArrayForKey:(NSString *)defaultName
{
	id array = [self arrayForKey:defaultName];
	if (array)
		array = [[array mutableCopy] autorelease];
	return array;
}

@end


@implementation NSMutableDictionary (MPEAdditions)

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
	[self setObject:[NSNumber numberWithBool:value] forKey:defaultName];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName
{
	[self setObject:[NSNumber numberWithInteger:value] forKey:defaultName];
}

- (void)setFloat:(float)value forKey:(NSString *)defaultName
{
	[self setObject:[NSNumber numberWithFloat:value] forKey:defaultName];
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName
{
	[self setObject:[NSNumber numberWithDouble:value] forKey:defaultName];
}

- (void)archiveAndSetColor:(NSColor *)color forKey:(NSString *)defaultName
{
	[self setObject:[NSArchiver archivedDataWithRootObject:color] forKey:defaultName];
}

@end


@implementation Protocol (MPEAdditions)

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector isRequired:(BOOL)isRequiredMethod isInstanceMethod:(BOOL)isInstanceMethod
{
	struct objc_method_description desc = protocol_getMethodDescription(self, 
																		aSelector,
																		isRequiredMethod, 
																		isInstanceMethod);
	
	if (!desc.name)
		return nil;
	
	return [NSMethodSignature signatureWithObjCTypes:desc.types];
}

@end


@implementation NSMenu (MPEAdditions)

- (void)setStateOfAllItemsTo:(NSInteger)itemState
{
	for (NSMenuItem *item in [self itemArray]) {
		[item setState:itemState];
	}
}

#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_OS_X_VERSION_10_5
- (void)removeAllItems
{
	while ([self numberOfItems] > 0)
		[self removeItemAtIndex:0];
}
#endif

- (NSMenuItem *)itemWithRepresentedIntegerValue:(NSInteger)value
{
	for (NSMenuItem *item in [self itemArray]) {
		if ([item representedObject] && [[item representedObject] integerValue] == value)
			return item;
	}
	return nil;
}

@end



