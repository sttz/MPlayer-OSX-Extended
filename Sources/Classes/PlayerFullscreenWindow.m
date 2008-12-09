/*  
 *  PlayerFullscreenWindow.m
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

#import "PlayerFullscreenWindow.h"
#import "PlayerController.h"
#import "Debug.h"

@implementation PlayerFullscreenWindow

-(id) initWithContentRect: (NSRect) contentRect 
				styleMask: (unsigned int) styleMask 
				  backing: (NSBackingStoreType) backingType 
					defer: (BOOL) flag {
	
	if ((self = [super initWithContentRect:contentRect
								 styleMask: NSBorderlessWindowMask 
								   backing:backingType
									 defer: flag])) {
		/* May want to setup some other options, 
		 like transparent background or something */
	}
	
	return self;
}

- (BOOL) canBecomeKeyWindow
{
	return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void) awakeFromNib
{
	[self setAcceptsMouseMovedEvents:YES];
}

- (void)makeKeyAndOrderFront:(id)sender
{
	[super makeKeyAndOrderFront:sender];
	[self makeFirstResponder:self];
}

- (void) hideOSD 
{
	[Debug log:ASL_LEVEL_ERR withMessage:@"hide osd"];
	if(isFullscreen)
	{
		CGDisplayHideCursor(kCGDirectMainDisplay);
		[fullscreenControls orderOut:self];
	}
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	if(isFullscreen)
	{
		if (![fullscreenControls isVisible]) {
			CGDisplayShowCursor(kCGDirectMainDisplay);
			[fullscreenControls orderFront:self];
		}
		
		if(!osdTimer || ![osdTimer isValid])
		{
			[osdTimer release];
			osdTimer = [NSTimer	scheduledTimerWithTimeInterval:5
														target:self
													  selector:@selector(hideOSD)
													  userInfo:nil repeats:NO];
			[osdTimer retain];
		}
        else
        {
            [osdTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: 5]];
        }
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	if (isFullscreen && [theEvent clickCount] == 2)
		[playerController switchFullscreen: self];
}

- (void) setFullscreen: (bool)aBool;
{
	if (!aBool) {
		[fullscreenControls orderOut:self];
		if (osdTimer != nil)
			[osdTimer invalidate];
		CGDisplayShowCursor(kCGDirectMainDisplay);
	} else {
		CGDisplayHideCursor(kCGDirectMainDisplay);
	}
	isFullscreen = aBool;
}

@end
