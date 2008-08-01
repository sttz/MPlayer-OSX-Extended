/* PlayerWindow */

#import <Cocoa/Cocoa.h>

@interface PlayerWindow : NSWindow
{
	IBOutlet id playerController;
	bool isFullscreen;
	
	NSTimer *osdTimer;
}

- (void) displayOSD;
- (void) hideOSD: (NSTimer *) timer;
- (void) setFullscreen: (bool)aBool;
@end
