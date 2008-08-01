/*
 *  LoacalizedInterface.m
 *  MPlayer OS X
 *
 *  Created by Jan Volf on Thu Dec 05 2002.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import "LocalizedInterface.h"


@implementation NSMenu (Localization)
- (void) awakeFromNib
{
	[self setTitle:NSLocalizedString([self title],@"")];
}
@end

@implementation NSMenuItem (Localization)
- (void) awakeFromNib
{
	[self setTitle:NSLocalizedString([self title],@"")];
}
@end

@implementation NSCell (Localization)
- (void) awakeFromNib
{
	[self setStringValue:NSLocalizedString([self stringValue],@"")];
}
@end
@implementation NSButton (Localization)
- (void) awakeFromNib
{
	if ([self imagePosition] != NSImageOnly) {
		[self setTitle:NSLocalizedString([self title],@"")];
		[self setAlternateTitle:NSLocalizedString([self alternateTitle],@"")];
	}
	if ([self toolTip])
		[self setToolTip:NSLocalizedString([self toolTip],@"")];

}
@end

@implementation NSSlider (Localization)
- (void) awakeFromNib
{
	if ([self toolTip])
		[self setToolTip:NSLocalizedString([self toolTip],@"")];
}
@end

@implementation NSTextField (Localization)
- (void) awakeFromNib
{
	[self setStringValue:NSLocalizedString([self stringValue],@"")];
	if ([self toolTip])
		[self setToolTip:NSLocalizedString([self toolTip],@"")];
}
@end

@implementation NSWindow (Localization)
- (void) awakeFromNib
{
	[self setTitle:NSLocalizedString([self title],@"")];
}
@end

@implementation NSTabViewItem (Localization)
- (void) awakeFromNib
{
	[self setLabel:NSLocalizedString([self label],@"")];
}
@end

@implementation NSTableColumn (Localization)
- (void) awakeFromNib
{
	[[self headerCell] setStringValue:NSLocalizedString([[self headerCell] stringValue],@"")];
}
@end

@implementation NSBox (Localization)
- (void) awakeFromNib
{
	[self setTitle:NSLocalizedString([self title],@"")];
	if ([self toolTip])
		[self setToolTip:NSLocalizedString([self toolTip],@"")];

}
@end

