/*  
 *  LayeredDictionary.m
 *  MPlayerOSX Extended
 *  
 *  Created on 30.11.09
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

#import "LocalUserDefaults.h"

#import "CocoaAdditions.h"

#import "Preferences.h"

@implementation LocalUserDefaults
@synthesize globalDefaults, localDefaults;

/* Allow using KVC to set values inside dictionaries in LocalUserDefaults.
 * e.g. in case something is bound to "localDefaults.someDictionary.someKey"
 * this will make someDictionary mutable, set the value of someKey and save 
 * the dictionary back again.
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	if ([keyPath rangeOfString:@"."].location == NSNotFound)
		return [self setObject:value forKey:keyPath];
	
	NSArray *pathComponents = [keyPath componentsSeparatedByString:@"."];
	
	if ([pathComponents count] > 2)
		@throw [NSException exceptionWithName:@"NotImplementedException"
									   reason:@"LocalUserDefaults doesn't implement setting objects in nested collections."
									 userInfo:nil];
	
	id object = [self objectForKey:[pathComponents objectAtIndex:0]];
	
	if (![object isKindOfClass:[NSDictionary class]]
		&& ![object isKindOfClass:[NSArray class]])
		@throw [NSException exceptionWithName:@"InvalidKeyPathException"
									   reason:[NSString stringWithFormat:@"Trying to set a value of a non-collection object: %@",object]
									 userInfo:nil];
	
	id mutableObject = [object mutableCopy];
	[mutableObject setValue:value forKey:[pathComponents objectAtIndex:1]];
	
	[self setObject:mutableObject forKey:[pathComponents objectAtIndex:0]];
}

/* Forward observations from NSUserDefaults to LocalUserDefaults.
 * When an observer is registered on LocalUserDefaults, it registers itself 
 * with NSUserDefaults for the same key and sends change notifications
 * in case NSUSerDefaults changes and there's no local object shadowing the change.
 */
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
	if (![observers objectForKey:keyPath]) {
		[globalDefaults addObserver:self forKeyPath:keyPath options:options context:context];
		[observers setInteger:1 forKey:keyPath];
	} else
		[observers setInteger:([observers integerForKey:keyPath] + 1) forKey:keyPath];
	
	[super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
	if ([observers integerForKey:keyPath] > 1)
		[observers setInteger:([observers integerForKey:keyPath] - 1) forKey:keyPath];
	else {
		[globalDefaults removeObserver:self forKeyPath:keyPath];
		[observers removeObjectForKey:keyPath];
	}
	
	[super removeObserver:observer forKeyPath:keyPath];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object != globalDefaults)
		return;
	
	if (![localDefaults objectForKey:keyPath]) {
		[self willChangeValueForKey:keyPath];
		[self didChangeValueForKey:keyPath];
	}
}

/* Completely disable automatic notifications as they will either come
 * from setObject:ForKey: removeObjectForKey: or NSUserDefaults.
 */
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
	return NO;
}

/* Initialization / Deallocation
 */
- (id)init
{
	return [self initWithCapacity:0];
}

- (id)initWithCapacity:(NSUInteger)capacity
{
	return [self initWithLocalDefaults:[NSDictionary dictionary]];
}

- (id)initWithLocalDefaults:(NSDictionary *)local
{
	if ((self = [super init])) {
		localDefaults = [local mutableCopy];
		globalDefaults = [NSUserDefaults standardUserDefaults];
		
		observers = [NSMutableDictionary new];
	}
	return self;
}

- (void)dealloc
{
	[localDefaults release];
	[observers release];
	
	[super dealloc];
}

- (id)copy
{
	return [self mutableCopy];
}

/* Send KVO notification for both setObject and removeObject.
 */
- (void)setObject:(id)anObject forKey:(id)aKey
{
	[self willChangeValueForKey:aKey];
	[localDefaults setObject:anObject forKey:aKey];
	[self didChangeValueForKey:aKey];
}

- (void)removeObjectForKey:(id)aKey
{
	[self willChangeValueForKey:aKey];
	[localDefaults removeObjectForKey:aKey];
	[self didChangeValueForKey:aKey];
}

- (NSArray *)allKeys
{
	NSMutableArray *keys = [[[[globalDefaults dictionaryRepresentation] allKeys] mutableCopy] autorelease];
	
	for (NSString *key in [localDefaults allKeys])
		if (![keys containsObject:key])
			[keys addObject:key];
	
	return keys;
}

- (NSUInteger)count
{
	NSUInteger localUniqueCount = 0;
	for (NSString *key in [localDefaults allKeys])
		if (![globalDefaults objectForKey:key])
			localUniqueCount++;
	
	return [[globalDefaults dictionaryRepresentation] count] + localUniqueCount;
}

/* Return the local object if it exists, return the NSUserDefaults value instead.
 */
- (id)objectForKey:(id)aKey
{
	if ([localDefaults objectForKey:aKey])
		return [localDefaults objectForKey:aKey];
	
	return [globalDefaults objectForKey:aKey];
}

- (NSEnumerator *)keyEnumerator
{
	return [[self allKeys] objectEnumerator];
}

- (NSEnumerator *)reverseKeyEnumerator
{
	return [[self allKeys] reverseObjectEnumerator];
}

@end
