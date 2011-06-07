//
//  InspectorGradientBox.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 23.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BWGradientBox.h"

@interface PlayerGradientBox : BWGradientBox {
@private
    
}
@end


@implementation PlayerGradientBox

- (void)awakeFromNib
{
	[self setHasGradient:YES];
	[self setHasFillColor:NO];
	
	[self setHasTopBorder:NO];
	[self setHasBottomBorder:NO];
	
	[self setTopInsetAlpha:0.0];
	[self setBottomInsetAlpha:0.3];
	
	[self setFillStartingColor:[NSColor colorWithCalibratedRed:131.0/255.0 green:145.0/255.0 blue:157.0/255.0 alpha:1.0]];
	[self setFillEndingColor:[NSColor colorWithCalibratedRed:172.0/255.0 green:184.0/255.0 blue:195.0/255.0 alpha:1.0]];
}

- (BOOL)isFlipped
{
	return NO;
}

@end
