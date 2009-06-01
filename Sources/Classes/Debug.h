/*  
 *  Debug.h
 *  MPlayerOSX Extended
 *  
 *  Created on 11.08.2008
 *  
 *  Description:
 *	Wrapper class around ASL
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
#import <asl.h>

#define dSender		"MPlayer OSX"
#define dFacility	"user"
#define dFilterUpto	ASL_LEVEL_WARNING

@interface Debug : NSObject {
	
}

// Initialize debugger
+ (void) init;

// Unitialize debugger
+ (void) uninit;

// Log to file
+ (void) logToFile:(NSString *)path;

// Log message
+ (void) log:(int)level withMessage:(NSString *)message, ...;

@end
