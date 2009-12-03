#import "PlayerWindow.h"

#import "PlayerController.h"

#import <Carbon/Carbon.h>

#define SCROLL_SEEK_MULT	10.0

@implementation PlayerWindow

- (void)keyDown:(NSEvent *)theEvent
{
	BOOL keyHandled = NO;
	
	NSString *characters = [theEvent characters];
	NSString *uCharacters = [theEvent charactersIgnoringModifiers];
	
	// Handle additional keys not set as key equivalent
	if (keyHandled = [characters isEqualToString:@"f"])
		[playerController switchFullscreen:self];
	else if (keyHandled = [characters isEqualToString:@"m"])
		[playerController toggleMute:self];
	else if (keyHandled = [characters isEqualToString:@"q"])
		[playerController stop:self];
	else if (keyHandled = [characters isEqualToString:@"p"])
		[playerController playPause:self];
	else if (keyHandled = ([characters isEqualToString:@"9"]
						   || [uCharacters isEqualToString:@"/"]))
		[playerController decreaseVolume:self];
	else if (keyHandled = ([characters isEqualToString:@"0"]
						   || [uCharacters isEqualToString:@"*"]))
		[playerController increaseVolume:self];
	
	if (!keyHandled)
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
		if (![playerController isSeeking]) {
			[playerController seek:(-scrollXAcc*SCROLL_SEEK_MULT) mode:MIRelativeSeekingMode];
			scrollXAcc = 0;
		}
	}
}
@end
