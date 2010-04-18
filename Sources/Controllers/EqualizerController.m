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
#import "MovieInfo.h"

#import "CocoaAdditions.h"

@implementation EqualizerController

- (void) awakeFromNib
{
	// Listen to enabling/disabling of equalizer
	NSString *localPrefsPath = @"movieInfoProvider.currentMovieInfo.prefs.";
	[[AppController sharedController] addObserver:self
									   forKeyPath:[localPrefsPath stringByAppendingString:MPEVideoEqualizerEnabled]
										  options:0 
										  context:nil];
	[[AppController sharedController] addObserver:self
									   forKeyPath:[localPrefsPath stringByAppendingString:MPEAudioEqualizerEnabled]
										  options:0
										  context:nil];
	[[AppController sharedController] addObserver:self
									   forKeyPath:[localPrefsPath stringByAppendingString:MPEAudioEqualizerSelectedPreset]
										  options:0
										  context:nil];
	
	[PREFS addObserver:self
			forKeyPath:MPEVideoEqualizerEnabled
			   options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)
			   context:nil];
	
	[PREFS addObserver:self
			forKeyPath:MPEAudioEqualizerEnabled
			   options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial)
			   context:nil];
	
	[self selectAudioEqualizerPreset];
}

- (void)selectAudioEqualizerPreset
{
	// Select current preset (no object: custom preset)
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	NSString *title = [info.prefs objectForKey:MPEAudioEqualizerSelectedPreset];
	
	if (title)
		if ([presetSelectionPopUp itemWithTitle:title]) {
			[presetSelectionPopUp selectItemWithTitle:title];
			return;
		} else
			// Reset removed preset
			[[info prefs] removeObjectForKey:MPEAudioEqualizerSelectedPreset];
	
	[presetSelectionPopUp selectItemWithTag:0];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPEVideoEqualizerEnabled]) {
		[enableVideoEqualizerByDefaultItem setState:[change integerForKey:NSKeyValueChangeNewKey]];
		return;
	} else if ([keyPath isEqualToString:MPEAudioEqualizerEnabled]) {
		[enableAudioEqualizerByDefaultItem setState:[change integerForKey:NSKeyValueChangeNewKey]];
		return;
	}
	
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	
	if (([keyPath hasSuffix:MPEVideoEqualizerEnabled] || [keyPath hasSuffix:MPEAudioEqualizerEnabled])
		&& [[[info player] player] localChangesNeedRestart])
		[self applyWithRestart:self];
	
	else if ([keyPath hasSuffix:MPEAudioEqualizerSelectedPreset])
		[self selectAudioEqualizerPreset];
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
	NSDictionary *values = [[NSDictionary new] autorelease];
	
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	[info.prefs setObject:values forKey:MPEVideoEqualizerValues];
}

- (IBAction) toggleEnableVideoEqualizerByDefault:(id)sender
{
	BOOL current = [PREFS boolForKey:MPEVideoEqualizerEnabled];
	[PREFS setBool:!current forKey:MPEVideoEqualizerEnabled];
}

- (IBAction) setVideoValuesAsDefault:(id)sender
{
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	NSDictionary *values = [info.prefs objectForKey:MPEVideoEqualizerValues];
	
	[PREFS setObject:values forKey:MPEVideoEqualizerValues];
}

- (IBAction) resetVideoEqualizerToDefaults:(id)sender
{
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	[info.prefs removeObjectForKey:MPEVideoEqualizerValues];
}

+ (NSString *)eq2FilterValues
{
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	NSDictionary *eqValues = [info.prefs objectForKey:MPEVideoEqualizerValues];
	NSMutableArray *values = [NSMutableArray array];
	float value;
	
	value = [eqValues floatForKey:MPEVideoEqualizerGamma];
	value = exp(log(8.0f) * (value / 100.0f));
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerContrast];
	value = (value + 100.0f) / 100.0f;
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerBrightness];
	value = value / 100.0f;
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	value = [eqValues floatForKey:MPEVideoEqualizerSaturation];
	value = (value + 100.0f) / 100.0f;
	[values addObject:[NSString stringWithFormat:@"%.2f",value]];
	
	return [values componentsJoinedByString:@":"];
}

+ (NSString *)hueFilterValue
{
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	float value = [[info.prefs objectForKey:MPEVideoEqualizerValues] floatForKey:MPEVideoEqualizerHue];
	return [NSString stringWithFormat:@"%.2f",(value*1.8f)];
}

- (void) openAudioEqualizer
{
	[audioEqualizerWindow makeKeyAndOrderFront:self];
}

- (IBAction) resetAudioEqualizer:(id)sender
{
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	[info.prefs removeObjectForKey:MPEAudioEqualizerValues];
}

- (IBAction) toggleEnableAudioEqualizerByDefault:(id)sender
{
	BOOL current = [PREFS boolForKey:MPEAudioEqualizerEnabled];
	[PREFS setBool:!current forKey:MPEAudioEqualizerEnabled];
}

- (IBAction) changePreset:(NSPopUpButton *)sender
{
	if ([sender selectedTag] == 0)
		return;
	
	NSString *presetName = [[sender selectedItem] title];
	NSDictionary *preset = [[PREFS objectForKey:MPEAudioEqualizerPresets] objectForKey:presetName];
	
	if (preset) {
		MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
		[info.prefs setObject:preset forKey:MPEAudioEqualizerValues];
		[info.prefs setObject:presetName forKey:MPEAudioEqualizerSelectedPreset];
		
		[self setAudioEqualizerDirty];
	}
}

- (IBAction) changeAudioValue:(NSSlider *)sender
{
	[presetSelectionPopUp selectItemWithTag:0];
	
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	[info.prefs removeObjectForKey:MPEAudioEqualizerSelectedPreset];
	
	[self setAudioEqualizerDirty];
}

- (IBAction) addAudioPreset:(NSMenuItem *)sender
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
		MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
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
		[presets setObject:[info.prefs objectForKey:MPEAudioEqualizerValues] forKey:name];
		[PREFS setObject:presets forKey:MPEAudioEqualizerPresets];
		// Select new preset
		[info.prefs setObject:name forKey:MPEAudioEqualizerSelectedPreset];
		[presetSelectionPopUp selectItemWithTitle:name];
	}
}

- (IBAction) removeAudioPreset:(NSMenuItem *)sender
{
	NSMutableDictionary *presets = [[[PREFS objectForKey:MPEAudioEqualizerPresets] mutableCopy] autorelease];
	[presets removeObjectForKey:[[presetSelectionPopUp selectedItem] title]];
	[PREFS setObject:presets forKey:MPEAudioEqualizerPresets];
	// Reset selection to custom preset
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	[info.prefs removeObjectForKey:MPEAudioEqualizerSelectedPreset];
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
	
	MovieInfo *info = [AppController sharedController].movieInfoProvider.currentMovieInfo;
	NSDictionary *values = [info.prefs objectForKey:MPEAudioEqualizerValues];
	
	for (NSString *arg in arguments)
		[parts addObject:[NSString stringWithFormat:@"%.2f",[values floatForKey:arg]]];
	
	return [parts componentsJoinedByString:@":"];					  
}

@end
