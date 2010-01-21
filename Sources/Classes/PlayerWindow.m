#import "PlayerWindow.h"

#import "PlayerController.h"
#import "MPlayerInterface.h"

#import "Preferences.h"

#import <Carbon/Carbon.h>

@implementation PlayerWindow

- (void)keyDown:(NSEvent *)theEvent
{
	BOOL keyHandled = NO;
	
	NSString *characters = [theEvent characters];
	NSString *uCharacters = [theEvent charactersIgnoringModifiers];
	
	// Handle additional keys not set as key equivalent
	if (keyHandled = [characters isEqualToString:@"f"])
		[playerController switchFullscreen:self];
	
	// Playback
	else if (keyHandled = [characters isEqualToString:@"q"])
		[playerController stop:self];
	else if (keyHandled = [characters isEqualToString:@"p"])
		[playerController playPause:self];
	else if (keyHandled = ([theEvent keyCode] == kVK_Return))
		[playerController seekNext:self];
	
	// Volume
	else if (keyHandled = [characters isEqualToString:@"m"])
		[playerController toggleMute:self];
	else if (keyHandled = ([characters isEqualToString:@"9"]
						   || [uCharacters isEqualToString:@"/"]))
		[playerController decreaseVolume:self];
	else if (keyHandled = ([characters isEqualToString:@"0"]
						   || [uCharacters isEqualToString:@"*"]))
		[playerController increaseVolume:self];
	
	// Cycle Streams
	else if (keyHandled = [characters isEqualToString:@"j"])
		[playerController cycleSubtitleStreamsWithOSD:YES];
	else if (keyHandled = [characters isEqualToString:@"#"])
		[playerController cycleAudioStreamsWithOSD:YES];
	
	// Cycle OSD
	else if (keyHandled = [characters isEqualToString:@"o"])
		[playerController cycleOSD:self];
	
	// Audio Delay
	else if (keyHandled = ([characters isEqualToString:@"+"]
						   || [characters isEqualToString:@"="]))
		[playerController setAudioDelay:0.1 relative:YES];
	else if (keyHandled = [characters isEqualToString:@"-"])
		[playerController setAudioDelay:-0.1 relative:YES];
	
	// Subtitle Delay
	else if (keyHandled = [characters isEqualToString:@"x"])
		[playerController setSubtitleDelay:0.1 relative:YES];
	else if (keyHandled = [characters isEqualToString:@"z"])
		[playerController setSubtitleDelay:-0.1 relative:YES];
	
	// Playback Speed
	else if (keyHandled = [characters isEqualToString:@"["])
		[playerController setPlaybackSpeed:0.9091 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"]"])
		[playerController setPlaybackSpeed:1.1 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"{"])
		[playerController setPlaybackSpeed:0.5 multiply:YES];
	else if (keyHandled = [characters isEqualToString:@"}"])
		[playerController setPlaybackSpeed:2.0 multiply:YES];
	else if (keyHandled = ([theEvent keyCode] == kVK_Delete))
		[playerController setPlaybackSpeed:1.0 multiply:NO];
	
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
		if (![[playerController playerInterface] state] == MIStatePlaying) {
			[playerController seek:(-scrollXAcc*[PREFS floatForKey:MPEScrollWheelSeekMultiple]) mode:MISeekingModeRelative];
			scrollXAcc = 0;
		}
	}
}
@end
