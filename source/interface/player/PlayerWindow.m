#import "PlayerWindow.h"

#import "PlayerController.h"
#import "MPlayerInterface.h"

#import "Preferences.h"

@implementation PlayerWindow
@synthesize playerController;

- (void)keyDown:(NSEvent *)theEvent
{
	if (![playerController handleKeyEvent:theEvent])
		[super keyDown:theEvent];
}

- (void)cancelOperation:(id)sender
{
	// handle escape and command-.
	if ([playerController isFullscreen])
		[playerController switchFullscreen:self];
	else
		[playerController stop:self];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	float dY = [theEvent deltaY];
	float dX = [theEvent deltaX];
	
	// volume
	if (fabsf(dY) > 0.99 && fabsf(dY) > fabsf(dX)) {
		
		[playerController setVolume:[playerController volume]+dY];
	
	// seek
	} else if (fabsf(dX) > 0.99) {
		
		// reset accumulated time when reversing
		if ((dX < 0 && scrollXAcc > 0) || (dX > 0 && scrollXAcc < 0))
			scrollXAcc = 0;
		
		// accumulate time while player is busy
		scrollXAcc += dX;
		
		// seek when ready
		if (![[playerController playerInterface] state] == MIStatePlaying) {
			[playerController seek:(-scrollXAcc*[PREFS floatForKey:MPEScrollWheelSeekMultiple]) mode:MISeekingModeRelative];
			scrollXAcc = 0;
		}
	}
}
@end
