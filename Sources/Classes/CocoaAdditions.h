/*  
 *  CocoaAdditions.h
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

#import <Cocoa/Cocoa.h>
#import <objc/Protocol.h>

@interface NSNumber (MPEAdditions)
- (NSString *) humanReadableSizeStringValue;
@end

@interface NSView (MPEAdditions)
- (void) resizeAndArrangeSubviewsVerticallyWithPadding:(float)padding;
@end

@interface NSDictionary (MPEAdditions)
- (BOOL)boolForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;
- (double)doubleForKey:(NSString *)defaultName;

- (NSNumber *)numberForKey:(NSString *)defaultName;
- (NSString *)stringForKey:(NSString *)defaultName;
- (NSData *)dataForKey:(NSString *)defaultName;
- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
- (NSDate *)dateForKey:(NSString *)defaultName;
- (NSColor *)colorForKey:(NSString *)defaultName;

- (NSMutableDictionary *)mutableDictionaryForKey:(NSString *)defaultName;
- (NSMutableArray *)mutableArrayForKey:(NSString *)defaultName;
@end

@interface NSMutableDictionary (MPEAdditions)
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (void)setDouble:(double)value forKey:(NSString *)defaultName;

- (void)archiveAndSetColor:(NSColor *)color forKey:(NSString *)defaultName;
@end

@interface Protocol (MPEAdditions)
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector isRequired:(BOOL)isRequiredMethod isInstanceMethod:(BOOL)isInstanceMethod;
@end

@interface NSMenu (MPEAdditions)
- (void)setStateOfAllItemsTo:(NSInteger)itemState;
#if __MAC_OS_X_VERSION_MIN_REQUIRED <= __MAC_OS_X_VERSION_10_5
- (void)removeAllItems;
#endif
- (NSMenuItem *)itemWithRepresentedIntegerValue:(NSInteger)value;
@end