/*  
 *  FullscreenControls.m
 *  MPlayerOSX Extended
 *  
 *  Created on 03.11.2008
 *  
 *  Description:
 *	Window used for the fullscreen controls.
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

#import "FullscreenControls.h"
#import <AppKit/AppKit.h>
#import "Debug.h"

#import "ScrubbingBar.h"

@implementation FullscreenControls
@synthesize beingDragged;

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
	
    // Make the window borderless
    NSWindow* result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    
	// Put in same level as fullscreen window
	[result setLevel:NSModalPanelWindowLevel];
	
	// Prepare window transparency
    [result setBackgroundColor: [NSColor clearColor]];
    [result setAlphaValue:0.0];
    [result setOpaque:NO];
	
	// Enable shadow
    [result setHasShadow:YES];
	
	// Animation attributes
	currentFade = 0;
	currentState = 0;
	
	// Load images
	fcPlayImageOn = [[NSImage imageNamed:@"fc_play_on"] retain];
	fcPlayImageOff = [[NSImage imageNamed:@"fc_play"] retain];
	fcPauseImageOn = [[NSImage imageNamed:@"fc_pause_on"] retain];
	fcPauseImageOff = [[NSImage imageNamed:@"fc_pause"] retain];
	
    return result;
}

- (void)awakeFromNib
{
	// Redirect scrubbing event to player controller
	[[NSNotificationCenter defaultCenter] addObserver:playerController
											 selector:@selector(progresBarClicked:)
												 name:@"SBBarClickedNotification"
											   object:fcScrubbingBar];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	NSPoint currentDragPoint;
	NSPoint newOrigin;
	
    currentDragPoint = [self convertBaseToScreen:[self mouseLocationOutsideOfEventStream]];
    newOrigin.x = currentDragPoint.x - dragStartPoint.x;
    newOrigin.y = currentDragPoint.y - dragStartPoint.y;
    
    [self setFrameOrigin:newOrigin];
}

- (void)mouseDown:(NSEvent *)theEvent
{    
    NSRect windowFrame = [self frame];
	dragStartPoint = [self convertBaseToScreen:[theEvent locationInWindow]];
	dragStartPoint.x -= windowFrame.origin.x;
	dragStartPoint.y -= windowFrame.origin.y;
	beingDragged = YES;
}

- (void)mouseUp:(NSEvent *)theEvent
{
	beingDragged = NO;
}

- (void)orderFront:(id)sender
{
	[super orderFront:sender];
	[self fadeWith:NSViewAnimationFadeInEffect];
	[[playerController playerInterface] addClient:self];
}

- (void)orderOut:(id)sender
{
	[self fadeWith:NSViewAnimationFadeOutEffect];
	[self performSelector:@selector(endOrderOut:) withObject:sender afterDelay:0.5];
}

- (void)endOrderOut:(id)sender
{
	[super orderOut:sender];
	[[playerController playerInterface] removeClient:self];
}

- (void)fadeWith:(NSString*)effect
{
	NSMutableDictionary *adesc;
	
	// Setup animation
	adesc = [NSMutableDictionary dictionaryWithCapacity:3];
	[adesc setObject:self forKey:NSViewAnimationTargetKey];
	
	[adesc setObject:effect forKey:NSViewAnimationEffectKey];
	
	// Create animation object if needed
	if (animation == nil) {
		animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObjects: adesc, nil]];
	} else {
		[animation setViewAnimations:[NSArray arrayWithObjects: adesc, nil]];
	}
	
	[animation setAnimationBlockingMode:NSAnimationNonblockingThreaded];
	[animation setDuration:0.5];
	[animation setAnimationCurve:NSAnimationEaseIn];
	
	[animation startAnimation];
	
}

- (void) interface:(MplayerInterface *)mi hasChangedStateTo:(NSNumber *)statenumber fromState:(NSNumber *)oldstatenumber
{	
	MIState state = [statenumber unsignedIntValue];
	unsigned int stateMask = (1<<state);
	MIState oldState = [oldstatenumber unsignedIntValue];
	unsigned int oldStateMask = (1<<oldState);
	
	// First play after startup
	if (state == MIStatePlaying && (oldStateMask & MIStateStartupMask)) {
		[fcAudioCycleButton setEnabled:([[playerController playingItem] audioStreamCount] > 1)];
		[fcSubtitleCycleButton setEnabled:([[playerController playingItem] subtitleCountForType:SubtitleTypeAll] > 1)];
	}
	
	// Change of Play/Pause state
	if (!!(stateMask & MIStatePPPlayingMask) != !!(oldStateMask & MIStatePPPlayingMask)) {
		// Playing
		if (stateMask & MIStatePPPlayingMask) {
			// Update interface
			[fcPlayButton setImage:fcPauseImageOff];
			[fcPlayButton setAlternateImage:fcPauseImageOn];
		// Pausing
		} else {
			// Update interface
			[fcPlayButton setImage:fcPlayImageOff];
			[fcPlayButton setAlternateImage:fcPlayImageOn];			
		}
	}
	
	// Change of Running/Stopped state
	if (!!(stateMask & MIStateStoppedMask) != !!(oldStateMask & MIStateStoppedMask)) {
		// Stopped
		if (stateMask & MIStateStoppedMask) {
			// Update interface
			[fcTimeTextField setStringValue:@"00:00:00"];
			[fcFullscreenButton setEnabled:NO];
			// Disable stream buttons
			[fcAudioCycleButton setEnabled:NO];
			[fcSubtitleCycleButton setEnabled:NO];
		// Running
		} else {
			// Update interface
			[fcFullscreenButton setEnabled:YES];
		}
	}
	
	// Update progress bar
	if (stateMask & MIStateStoppedMask && !(oldStateMask & MIStateStoppedMask)) {
		// Reset progress bar
		[fcScrubbingBar setScrubStyle:MPEScrubbingBarEmptyStyle];
		[fcScrubbingBar setDoubleValue:0];
		[fcScrubbingBar setIndeterminate:NO];
	} else if (stateMask & MIStateIntermediateMask && !(oldStateMask & MIStateIntermediateMask)) {
		// Intermediate progress bar
		[fcScrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
		[fcScrubbingBar setIndeterminate:YES];
	} else if (stateMask & MIStatePositionMask && !(oldStateMask & MIStatePositionMask)) {
		// Progress bar
		if ([[playerController playingItem] length] > 0) {
			[fcScrubbingBar setMaxValue: [[playerController playingItem] length]];
			[fcScrubbingBar setScrubStyle:MPEScrubbingBarPositionStyle];
		} else {
			[fcScrubbingBar setScrubStyle:MPEScrubbingBarProgressStyle];
			[fcScrubbingBar setMaxValue:100];
			[fcScrubbingBar setIndeterminate:NO];
		}
	}
}

- (void) interface:(MplayerInterface *)mi volumeUpdate:(NSNumber *)volume isMuted:(NSNumber *)muted
{
	[fcVolumeSlider setFloatValue:[volume floatValue]];
}

- (void) interface:(MplayerInterface *)mi timeUpdate:(NSNumber *)newTime
{
	float seconds = [newTime floatValue];
	
	if ([[playerController playingItem] length] > 0)
		[fcScrubbingBar setDoubleValue:seconds];
	else
		[fcScrubbingBar setDoubleValue:0];
	
	int iseconds = (int)seconds;
	[fcTimeTextField setStringValue:[NSString stringWithFormat:@"%02d:%02d:%02d", iseconds/3600,(iseconds%3600)/60,iseconds%60]];
}

- (void) dealloc
{
	[fcPlayImageOn release];
	[fcPlayImageOff release];
	[fcPauseImageOn release];
	[fcPauseImageOff release];
	
	[animation release];
	[super dealloc];
}

@end
