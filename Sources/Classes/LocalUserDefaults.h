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

#import <Cocoa/Cocoa.h>

/* LocalUserDefaults is an extension to NSUserDefaults which allows to
 * keep global preferences values in NSUserDefaults and override them
 * for individual LocalUserDefaults instances.
 * 
 * An empty LocalUserDefaults instance will return identical objects for
 * all keys in NSUserDefaults. All objects set through LocalUserDefaults 
 * will override NSUSerDefaults values for this instance and subsequent 
 * calls to objectForKey: will return the local instance. A call to 
 * removeObjectForKey: will reset the value to the NSUserDefaults one.
 * 
 * This class is KVO and KVC compliant and will properly rely changes 
 * to NSUserDefaults values in case they are not overwritten locally.
 * So it's possible to use LocalUserDefaults just like NSUserDefaults,
 * just with the added possibility to override NSUserDefaults values 
 * locally.
 * 
 * Additionally, LocalUserDefaults allows changing of top-level NSArray 
 * and NSDictionary contents. It's therefore possible to bind an interface
 * element to a key inside a dictionary inside LocalUserDefaults.
 * LocalUserDefaults will take care of making the collection mutable,
 * setting the corresponding key and updating the original collection
 * when using KVC.
 */
@interface LocalUserDefaults : NSMutableDictionary {
	
	NSUserDefaults *globalDefaults;
	NSMutableDictionary *localDefaults;
	
	NSMutableDictionary *observers;
}
@property (nonatomic,readonly) NSUserDefaults *globalDefaults;
@property (nonatomic,readonly) NSDictionary *localDefaults;
- (id)initWithLocalDefaults:(NSDictionary *)local;
@end
