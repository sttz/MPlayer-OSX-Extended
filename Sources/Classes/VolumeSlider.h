/* VolumeSlider */

#import <Cocoa/Cocoa.h>

@interface VolumeSliderCell : NSSliderCell
{
	NSImage *knobOff;
	NSImage *knobOn;
	
	BOOL isKnobSelected;
}
@end

@interface VolumeSlider : NSSlider
{
}
@end
