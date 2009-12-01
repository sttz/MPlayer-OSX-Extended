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
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:MPEVideoEqualizerEnabled])
		[self applyWithRestart];
}

- (void) applyWithRestart
{
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
	NSMutableArray *values = [NSMutableArray new];
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

@end
