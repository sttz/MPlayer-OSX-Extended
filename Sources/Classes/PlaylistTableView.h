/*
 PlaylistTableView.h

 Author: MCF
 
 */


#import <Cocoa/Cocoa.h>
#import "PlayListController.h"
#import "PlayerController.h"

@interface PlaylistTableView : NSTableView
{
    IBOutlet PlayListController	*playListController;
	IBOutlet PlayerController	*playerController;
}
// 1st responderaction implementation
- (void)keyDown:(NSEvent *)theEvent;
- (void)clear:(id)sender;
// delegate methods
- (BOOL)validateMenuItem:(id <NSMenuItem>)anItem;
@end
