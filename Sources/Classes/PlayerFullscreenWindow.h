/*  
 *  PlayerFullscreenWindow.h
 *  MPlayerOSX Extended
 *  
 *  Created on 20.10.2008
 *  
 *  Description:
 *	Borderless window used to go into and display video in fullscreen.
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
#import "PlayerWindow.h"

@class FullscreenControls;

@interface PlayerFullscreenWindow : PlayerWindow {
	
	IBOutlet FullscreenControls *fullscreenControls;
	
	BOOL isFullscreen;
	BOOL mouseInWindow;
	BOOL mouseOverControls;
	
	NSTrackingRectTag fsTrackTag, fcTrackTag;
	NSTimer *osdTimer;
	NSPoint lastMousePosition;
}

-(id) initWithContentRect: (NSRect) contentRect 
				styleMask: (unsigned int) styleMask 
				  backing: (NSBackingStoreType) backingType 
					defer: (BOOL) flag;

- (void) hideOSD;
- (void) setFullscreen: (bool)aBool;
- (void) startMouseTracking;
- (void) stopMouseTracking;
- (void) refreshOSDTimer;

- (void) mouseEnteredFSWindow;
- (void) mouseExitedFSWindow;
- (void) mouseEnteredFCWindow;
- (void) mouseExitedFCWindow;

@end
