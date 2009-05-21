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

#define MP_FC_HIDEAFTERSECONDS	3
#define INITIAL_FC_X_POS		0.5
#define INITIAL_FC_Y_POS		0.15


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

/*- (BOOL)acceptsFirstResponder
{
	return YES;
}*/

/*- (void) awakeFromNib
{
	//[self setAcceptsMouseMovedEvents:YES];
	
}*/

/*- (void)makeKeyAndOrderFront:(id)sender
{
	[super makeKeyAndOrderFront:sender];
	//[self makeFirstResponder:self];
}*/

- (void) startMouseTracking
{
	fsTrackTag = [[self contentView] addTrackingRect:[[self contentView] frame] owner:self userData:nil assumeInside:NO];
	fcTrackTag = [[fullscreenControls contentView] addTrackingRect:[[fullscreenControls contentView] frame]	
														owner:self userData:nil assumeInside:NO];
	
	NSPoint mp = [[self contentView] convertPoint:[self mouseLocationOutsideOfEventStream] fromView:nil];
	if ([[self contentView] mouse:mp inRect:[[self contentView] frame]])
		[self mouseEnteredFSWindow];
	
	mp = [[fullscreenControls contentView] convertPoint:[fullscreenControls mouseLocationOutsideOfEventStream] fromView:nil];
	if ([[fullscreenControls contentView] mouse:mp inRect:[[fullscreenControls contentView] frame]])
		[self mouseEnteredFCWindow];
	
	// place controls on screen
	NSArray *pos;
	if ([[appController preferences] objectForKey:@"FullscreenControlsPosition"]) 
		pos = [[appController preferences] arrayForKey:@"FullscreenControlsPosition"];
	else
		pos = [NSArray arrayWithObjects:[NSNumber numberWithFloat:INITIAL_FC_X_POS],[NSNumber numberWithFloat:INITIAL_FC_Y_POS], nil];
	
	NSRect screenFrame = [[self screen] frame];
	NSRect controllerFrame = [fullscreenControls frame];
	NSPoint point;
	
	BOOL onScreen = NO;
	int i,j;
	for (j = 0; onScreen == NO && j < 2; j++) {
		
		// use percent values to get absolute origin
		point = NSMakePoint(
			screenFrame.origin.x + [[pos objectAtIndex:0] floatValue] * screenFrame.size.width - (controllerFrame.size.width / 2), 
			screenFrame.origin.y + [[pos objectAtIndex:1] floatValue] * screenFrame.size.height - (controllerFrame.size.height / 2));
		
		// check if point is on any screen
		for (i = 0; i < [[NSScreen screens] count]; i++) {
			if (NSPointInRect(point, [[[NSScreen screens] objectAtIndex:i] frame]))
				onScreen = YES;
		}
		
		// reset to default position if not on screen
		if (!onScreen)
			pos = [NSArray arrayWithObjects:[NSNumber numberWithFloat:INITIAL_FC_X_POS],[NSNumber numberWithFloat:INITIAL_FC_Y_POS], nil];
	}
	
	controllerFrame.origin.x = point.x;
	controllerFrame.origin.y = point.y;
	[fullscreenControls setFrame:controllerFrame display:YES];
}

- (void) stopMouseTracking
{
	[[self contentView] removeTrackingRect:fsTrackTag];
	[[fullscreenControls contentView] removeTrackingRect:fcTrackTag];
	[self mouseExitedFSWindow];
	
	// save controller position
	NSRect screenFrame = [[self screen] frame];
	NSRect controllerFrame = [fullscreenControls frame];
	
	// transform position to relative screen-coordiantes
	float px, py;
	px = ((controllerFrame.origin.x + (controllerFrame.size.width / 2)) - screenFrame.origin.x) / screenFrame.size.width;
	py = ((controllerFrame.origin.y + (controllerFrame.size.height / 2)) - screenFrame.origin.y) / screenFrame.size.height;
	
	// check values for sanity and reset to defaults if so
	if (!isfinite(px) || isnan(px) || !isfinite(py) || isnan(py))
		[[appController preferences] removeObjectForKey:@"FullscreenControlsPosition"];
	// save sane values in preferences
	else {
		NSArray *pos = [NSArray arrayWithObjects:
			[NSNumber numberWithFloat:px],[NSNumber numberWithFloat:py],nil];
		[[appController preferences] setObject:pos forKey:@"FullscreenControlsPosition"];
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	if ([theEvent window] == self)
		[self mouseEnteredFSWindow];
	else
		[self mouseEnteredFCWindow];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if ([theEvent window] == self)
		[self mouseExitedFSWindow];
	else
		[self mouseExitedFCWindow];
}

- (void)mouseEnteredFSWindow
{
	mouseInWindow = YES;
	[self setAcceptsMouseMovedEvents:YES];
	[self makeFirstResponder:[self contentView]];
	CGDisplayHideCursor(kCGDirectMainDisplay);
}

- (void)mouseExitedFSWindow
{
	mouseInWindow = NO;
	[self setAcceptsMouseMovedEvents:NO];
	CGDisplayShowCursor(kCGDirectMainDisplay);
}

- (void)mouseEnteredFCWindow
{
	mouseOverControls = YES;
	if (osdTimer)
		[osdTimer invalidate];
}

- (void)mouseExitedFCWindow
{
	mouseOverControls = NO;
	[self refreshOSDTimer];
}

- (void) hideOSD 
{
	if(isFullscreen)
	{
		if (mouseInWindow)
			CGDisplayHideCursor(kCGDirectMainDisplay);
		if (mouseOverControls)
			[self mouseExitedFCWindow];
		[fullscreenControls orderOut:self];
	}
}

- (void)mouseMoved:(NSEvent *)theEvent
{	
	if(isFullscreen)
	{
		CGDisplayShowCursor(kCGDirectMainDisplay);
		
		if (![fullscreenControls isVisible])
			[fullscreenControls orderFront:self];
		
		[self refreshOSDTimer];
	}
}

- (void)refreshOSDTimer
{
	if(!osdTimer || ![osdTimer isValid])
	{
		[osdTimer release];
		osdTimer = [NSTimer	scheduledTimerWithTimeInterval:MP_FC_HIDEAFTERSECONDS
													target:self
												  selector:@selector(hideOSD)
												  userInfo:nil repeats:NO];
		[osdTimer retain];
	}
	else
	{
		[osdTimer setFireDate: [NSDate dateWithTimeIntervalSinceNow: MP_FC_HIDEAFTERSECONDS]];
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
		//CGDisplayShowCursor(kCGDirectMainDisplay);
	} else {
		//CGDisplayHideCursor(kCGDirectMainDisplay);
	}
	isFullscreen = aBool;
}

@end
