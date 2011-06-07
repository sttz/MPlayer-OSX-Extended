/*  
 *  BinaryBundle.h
 *  MPlayerOSX Extended
 *  
 *  Created on 28.11.09
 *  
 *  Description:
 *	NSBundle wrapper that allows to "reload" the bundle.
 *  Reloading is limited to the info dictionary as well as 
 *  the executable architectures.
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

// This is a hack around the problem that NSBundles are cached and cannot 
// be reloaded. MPlayer OSX Extended uses bundles for its binary packages 
// which should be updatable without a restart. This is not possible with 
// NSBundle because creating a new NSBundle object will just return the old 
// cached object containing outdated information.
// 
// This is a NSBundle subclass so that it can be passed to Sparkle for 
// updating (which also needs the updated info dictionary).
// 
// Only the re-implemented methods in this header should ever be called on
// objects of this class.

#import <Cocoa/Cocoa.h>

@interface BinaryBundle : NSBundle {
	
	NSString *pathToBundle;
	NSDictionary *infoDict;
}

- (void) invalidateBinaryBundle;

- (NSDictionary *) infoDictionary;
- (id) objectForInfoDictionaryKey:(NSString *)key;

- (NSString *)bundleIdentifier;

- (NSString *) executablePath;
- (NSArray *) executableArchitectureStrings;

@end
