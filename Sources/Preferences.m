/*  
 *  LanguageCodes.m
 *  MPlayerOSX Extended
 *  
 *  Created on 02.11.2009
 *  
 *  Description:
 *	Constants used to query preferences stored in NSUserDefaults.
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

#include "Preferences.h"

NSString* const MPEAdvancedOptions                    = @"MPEAdvancedOptions";
NSString* const MPEAnimateInterfaceTransitions        = @"MPEAnimateInterfaceTransitions";
NSString* const MPEAspectRatio                        = @"MPEAspectRatio";
NSString* const MPEBS2BFilter                         = @"MPEBS2BFilter";
NSString* const MPEBlackOutOtherScreensInFullscreen   = @"MPEBlackOutOtherScreensInFullscreen";
NSString* const MPECacheSizeInMB                      = @"MPECacheSizeInMB";
NSString* const MPECheckForUpdatesIncludesPrereleases = @"MPECheckForUpdatesIncludesPrereleases";
NSString* const MPECustomAspectRatio                  = @"MPECustomAspectRatio";
NSString* const MPECustomScreenshotsSavePath          = @"MPECustomScreenshotsSavePath";
NSString* const MPECustomSizeInPx                     = @"MPECustomSizeInPx";
NSString* const MPEDefaultAudioLanguages              = @"MPEDefaultAudioLanguages";
NSString* const MPEDefaultDirectory                   = @"MPEDefaultDirectory";
NSString* const MPEDefaultSubtitleLanguages           = @"MPEDefaultSubtitleLanguages";
NSString* const MPEDeinterlaceFilter                  = @"MPEDeinterlaceFilter";
NSString* const MPEDisplaySize                        = @"MPEDisplaySize";
NSString* const MPEDropFrames                         = @"MPEDropFrames";
NSString* const MPEEnableAudio                        = @"MPEEnableAudio";
NSString* const MPEEnableVideo                        = @"MPEEnableVideo";
NSString* const MPEFastDecoding                       = @"MPEFastDecoding";
NSString* const MPEFlipDisplayHorizontally            = @"MPEFlipDisplayHorizontally";
NSString* const MPEFlipDisplayVertically              = @"MPEFlipDisplayVertically";
NSString* const MPEFont                               = @"MPEFont";
NSString* const MPEFontStyle                          = @"MPEFontStyle";
NSString* const MPEFullscreenDisplayNumber            = @"MPEFullscreenDisplayNumber";
NSString* const MPEGoToFullscreenOn                   = @"MPEGoToFullscreenOn";
NSString* const MPEGuessTextEncoding                  = @"MPEGuessTextEncoding";
NSString* const MPEHRTFFilter                         = @"MPEHRTFFilter";
NSString* const MPEHardwareAC3Passthrough             = @"MPEHardwareAC3Passthrough";
NSString* const MPEHardwareDTSPassthrough             = @"MPEHardwareDTSPassthrough";
NSString* const MPEKaraokeFilter                      = @"MPEKaraokeFilter";
NSString* const MPELoadEmbeddedFonts                  = @"MPELoadEmbeddedFonts";
NSString* const MPEOSDLevel                           = @"MPEOSDLevel";
NSString* const MPEOSDScale                           = @"MPEOSDScale";
NSString* const MPEOverrideAudioCodecs                = @"MPEOverrideAudioCodecs";
NSString* const MPEOverrideVideoCodecs                = @"MPEOverrideVideoCodecs";
NSString* const MPEPostprocessingFilter               = @"MPEPostprocessingFilter";
NSString* const MPERenderSubtitlesFirst               = @"MPERenderSubtitlesFirst";
NSString* const MPEScreenshotSaveLocation             = @"MPEScreenshotSaveLocation";
NSString* const MPEStartPlaybackDisplayType           = @"MPEStartPlaybackDisplayType";
NSString* const MPESubtitleBorderColor                = @"MPESubtitleBorderColor";
NSString* const MPESubtitleScale                      = @"MPESubtitleScale";
NSString* const MPESubtitleTextColor                  = @"MPESubtitleTextColor";
NSString* const MPETextEncoding                       = @"MPETextEncoding";
NSString* const MPEWindowOnTopMode                    = @"MPEWindowOnTopMode";

NSString* const MPECustomAspectRatioStringKey         = @"MPECustomAspectRatioString";
NSString* const MPECustomAspectRatioValueKey          = @"MPECustomAspectRatioValue";

NSString* const MPEAdvancedOptionsStringKey           = @"MPEAdvancedOptionString";
NSString* const MPEAdvancedOptionsEnabledKey          = @"MPEAdvancedOptionEnabled";

int const MPEStartPlaybackDisplayTypeWindow           = 0;
int const MPEStartPlaybackDisplayTypeFullscreen       = 1;
int const MPEStartPlaybackDisplayTypeDesktop          = 2;

int const MPEWindowOnTopModeNever                     = 0;
int const MPEWindowOnTopModeWhilePlaying              = 1;
int const MPEWindowOnTopModeAlways                    = 2;

int const MPEDisplaySizeHalf                          = 0;
int const MPEDisplaySizeOriginal                      = 1;  
int const MPEDisplaySizeDouble                        = 2;
int const MPEDisplaySizeFitScreen                     = 3;
int const MPEDisplaySizeCustom                        = 4;

int const MPEScreenshotsDisabled                      = 0;
int const MPEScreenshotSaveLocationHomeFolder         = 1;
int const MPEScreenshotSaveLocationDocumentsFolder    = 2;
int const MPEScreenshotSaveLocationPicturesFolder     = 3;
int const MPEScreenshotSaveLocationDesktop            = 4;
int const MPEScreenshotSaveLocationCustom             = 5;

int const MPEGoToFullscreenOnSameScreen               = 0;
int const MPEGoToFullscreenOnFixedScreen              = 1;

int const MPEDropFramesNever                          = 0;
int const MPEDropFramesSoft                           = 1;
int const MPEDropFramesHard                           = 2;

int const MPEDeinterlaceFilterOff                     = 0;
int const MPEDeinterlaceFilterYadif                   = 1;
int const MPEDeinterlaceFilterKernel                  = 2;
int const MPEDeinterlaceFilterFFmpeg                  = 3;
int const MPEDeinterlaceFilterFilm                    = 4;
int const MPEDeinterlaceFilterBlend                   = 5;

int const MPEPostprocessingFilterOff                  = 0;
int const MPEPostprocessingFilterDefault              = 1;
int const MPEPostprocessingFilterFast                 = 2;
int const MPEPostprocessingFilterHighQuality          = 3;



