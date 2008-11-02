//
//  PlayerFullscreenWindow.h
//  MPlayer OSX
//
//  Created by Adrian on 20.10.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PlayerWindow.h"

@interface PlayerFullscreenWindow : PlayerWindow {

}

-(id) initWithContentRect: (NSRect) contentRect 
				styleMask: (unsigned int) styleMask 
				  backing: (NSBackingStoreType) backingType 
					defer: (BOOL) flag;

@end
