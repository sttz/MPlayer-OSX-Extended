/*
 *  LoacalizedInterface.h
 *  MPlayer OS X
 *
 *	Description:
 *		Cathegory methods that augment classes restored from nib file to load localized
 *	versions of their titles and string values.
 *		If you are subclassing one of these classes you have to call super's awakeFromNib
 *	on the beginning of your subclass awakeFromNib to get it localized
 *
 *  Created by Jan Volf on Thu Dec 05 2002.
 *	<javol@seznam.cz>
 *  Copyright (c) 2003 Jan Volf. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface NSMenu (Localization)
- (void) awakeFromNib;
@end

@interface NSMenuItem (Localization)
- (void) awakeFromNib;
@end

@interface NSCell (Localization)
- (void) awakeFromNib;
@end

@interface NSButton (Localization)
- (void) awakeFromNib;
@end

@interface NSSlider (Localization)
- (void) awakeFromNib;
@end

@interface NSTextField (Localization)
- (void) awakeFromNib;
@end

@interface NSWindow (Localization)
- (void) awakeFromNib;
@end

@interface NSTabViewItem (Localization)
- (void) awakeFromNib;
@end

@interface NSTableColumn (Localization)
- (void) awakeFromNib;
@end

@interface NSBox (Localization)
- (void) awakeFromNib;
@end
