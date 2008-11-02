//
//  PlayerFullscreenWindow.m
//  MPlayer OSX
//
//  Created by Adrian on 20.10.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PlayerFullscreenWindow.h"


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

@end
