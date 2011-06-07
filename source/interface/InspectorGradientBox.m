//
//  InspectorGradientBox.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 23.04.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BWGradientBox.h"

@interface InspectorGradientBox : BWGradientBox {
@private
    
}
@end


@implementation InspectorGradientBox

- (void)awakeFromNib
{
	[self setHasGradient:YES];
	[self setHasFillColor:NO];
	
	[self setHasTopBorder:YES];
	[self setHasBottomBorder:YES];
	
	[self setTopInsetAlpha:0.3];
	[self setBottomInsetAlpha:0.0];
	
	[self setFillStartingColor:[NSColor colorWithCalibratedRed:210.0/255.0 green:214.0/255.0 blue:223.0/255.0 alpha:1.0]];
	[self setFillEndingColor:[NSColor colorWithCalibratedRed:181.0/255.0 green:183.0/255.0 blue:193.0/255.0 alpha:1.0]];
	[self setTopBorderColor:[NSColor colorWithCalibratedRed:156.0/255.0 green:166.0/255.0 blue:178.0/255.0 alpha:1.0]];
	[self setBottomBorderColor:[NSColor colorWithCalibratedRed:131.0/255.0 green:140.0/255.0 blue:149.0/255.0 alpha:1.0]];
}

@end
