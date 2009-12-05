/*  
 *  EqualizerController.m
 *  MPlayerOSX Extended
 *  
 *  Created on 30.11.09
 *  
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License
 *  as published by the Free Software Foundation; either version 2
 *  of the License, or (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#import "EqualizerController.h"

#import "AppController.h"
#import "PlayerController.h"

#import "Preferences.h"

#import "CocoaAdditions.h"

@implementation EqualizerController

- (void) awakeFromNib
{
	// Listen to enabling/disabling of equalizer
	[PREFS addObserver:self
		    forKeyPath:MPEVideoEqualizerEnabled
			   options:0 
			   context:nil];
	[PREFS addObserver:self
			forKeyPath:MPEAudioEqualizerEnabled 
			   options:0
			   context:nil];
	
	// Select current preset (no object: custom preset)
	if ([PREFS objectForKey:MPEAudioEqualizerSelectedPreset])
		[presetSelectionPopUp selectItemWithTitle:[PREFS objectForKey:MPEAudioEqualizerSelectedPreset]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPEVideoEqualizerEnabled]
		|| [keyPath isEqualToString:MPEAudioEqualizerEnabled])
		[self applyWithRestart:self];
}

- (IBAction) applyWithRestart:(id)sender
{
	[audioApplyButton setEnabled:NO];
	[[[AppController sharedController] playerController] applyChangesWithRestart:YES];
}

- (void) openVideoEqualizer
{
	[videoEqualizerWindow makeKeyAndOrderFront:self];
}

- (IBAction) resetVideoEqualizer:(id)sender
{
	[PREFS removeObjectForKey:MPEVideoEqualizerValues];
}

+ (NSString *)eq2FilterValues
{
	NSDictionary *eqValues = [PREFS objectForKey:MPEVideoEqualizerValues];
	NSMutableArray *values = [NSMutableArray array];
	float value;
	
	value = [eqValues floatForKey:MPEVideoEqualizerGamma];
	if (value < 0)
		value = 0.123f + 0.777f * (100.0f + value)/100.0f;
	else
		value = 1.0f + 9.0f * (value/100.0f);
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerContrast];
	value = (value + 100.0f)/100.0f;
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerBrightness];
	value = value/100.0f;
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerSaturation];
	if (value < 0)
		value = (100.0f + value)/100.0f;
	else
		value = 1.0f + (value/100.f);
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	return [values componentsJoinedByString:@":"];
}

+ (NSString *)hueFilterValue
{
	float value = [[PREFS objectForKey:MPEVideoEqualizerValues] floatForKey:MPEVideoEqualizerHue];
	return [NSString stringWithFormat:@"%.2f",(value*1.8f)];
}

- (void) openAudioEqualizer
{
	[audioEqualizerWindow makeKeyAndOrderFront:self];
}

- (IBAction) resetAudioEqualizer:(id)sender
{
	[PREFS removeObjectForKey:MPEAudioEqualizerValues];
}

- (IBAction) changePreset:(NSPopUpButton *)sender
{
	if ([sender selectedTag] == 0)
		return;
	
	NSString *presetName = [[sender selectedItem] title];
	NSDictionary *preset = [[PREFS objectForKey:MPEAudioEqualizerPresets] objectForKey:presetName];
	
	if (preset) {
		[PREFS setObject:preset forKey:MPEAudioEqualizerValues];
		[PREFS setObject:presetName forKey:MPEAudioEqualizerSelectedPreset];
		
		[self setAudioEqualizerDirty];
	}
}

- (IBAction) changeAudioValue:(NSSlider *)sender
{
	[presetSelectionPopUp selectItemWithTag:0];
	[PREFS removeObjectForKey:MPEAudioEqualizerSelectedPreset];
	
	[self setAudioEqualizerDirty];
}

- (IBAction) addAudioPreset:(NSButton *)sender
{
	NSAlert *alert = [[NSAlert new] autorelease];
	[alert setAlertStyle:NSInformationalAlertStyle];
	[alert setMessageText:@"Preset Name"];
	[alert setInformativeText:@"Please choose a new for the new preset:"];
	[alert setAccessoryView:presetNameView];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	
	[alert layout];
	[presetNameField setStringValue:@""];
	[presetNameField becomeFirstResponder];
	
	if ([alert runModal] == NSAlertFirstButtonReturn) {
		NSMutableDictionary *presets = [[[PREFS objectForKey:MPEAudioEqualizerPresets] mutableCopy] autorelease];
		NSString *name = [presetNameField stringValue];
		// Generate a name if none was given or is already taken
		if ([name length] == 0 || [presets objectForKey:name]) {
			if ([name length] == 0)
				name = @"Untitled Preset";
			// Add a number to the end and increment it until the name is unique
			NSString *newName = name;
			int num = 1;
			while ([presets objectForKey:newName])
				newName = [NSString stringWithFormat:@"%@ %d",name,num++];
			name = newName;
		}
		[presets setObject:[PREFS objectForKey:MPEAudioEqualizerValues] forKey:name];
		[PREFS setObject:presets forKey:MPEAudioEqualizerPresets];
		// Select new preset
		[PREFS setObject:name forKey:MPEAudioEqualizerSelectedPreset];
		[presetSelectionPopUp selectItemWithTitle:name];
	}
}

- (IBAction) removeAudioPreset:(NSButton *)sender
{
	NSMutableDictionary *presets = [[[PREFS objectForKey:MPEAudioEqualizerPresets] mutableCopy] autorelease];
	[presets removeObjectForKey:[[presetSelectionPopUp selectedItem] title]];
	[PREFS setObject:presets forKey:MPEAudioEqualizerPresets];
	// Reset selection to custom preset
	[PREFS removeObjectForKey:MPEAudioEqualizerSelectedPreset];
}

- (void) setAudioEqualizerDirty
{
	if ([[[AppController sharedController] playerController] isRunning])
		[audioApplyButton setEnabled:YES];
}

+ (NSString *)equalizerFilterValues
{
	NSArray *arguments = [NSArray arrayWithObjects:
						  @"MPEAudioEqualizer31Hz",
						  @"MPEAudioEqualizer62Hz",
						  @"MPEAudioEqualizer125Hz",
						  @"MPEAudioEqualizer250Hz",
						  @"MPEAudioEqualizer500Hz",
						  @"MPEAudioEqualizer1kHz",
						  @"MPEAudioEqualizer2kHz",
						  @"MPEAudioEqualizer4kHz",
						  @"MPEAudioEqualizer8kHz",
						  @"MPEAudioEqualizer16kHz",
						  nil];
	NSMutableArray *parts = [NSMutableArray array];
	
	NSDictionary *values = [PREFS objectForKey:MPEAudioEqualizerValues];
	
	for (NSString *arg in arguments)
		[parts addObject:[NSString stringWithFormat:@"%.2f",[values floatForKey:arg]]];
	
	return [parts componentsJoinedByString:@":"];					  
}

@end
