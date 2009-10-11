/* PlayerWindow */

#import <Cocoa/Cocoa.h>

@class PlayerController;

@interface PlayerWindow : NSWindow
{
	IBOutlet PlayerController *playerController;
	
	float scrollXAcc;
}
@end
