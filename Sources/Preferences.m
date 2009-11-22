//
//  Preferences.m
//  MPlayer OSX Extended
//
//  Created by Adrian on 20.11.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

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

int const MPEStartPlaybackDisplayTypeWindow           = 0;
int const MPEStartPlaybackDisplayTypeFullscreen       = 1;
int const MPEStartPlaybackDisplayTypeDesktop          = 2;

int const MPEWindowOnTopModeNever                     = 0;
int const MPEWindowOnTopModeWhilePlaying              = 1;
int const MPEWindowOnTopModeAlways                    = 2;

int const MPEScreenshotsDisabled                      = 0;
int const MPEScreenshotSaveLocationHomeFolder         = 1;
int const MPEScreenshotSaveLocationPicturesFolder     = 2;
int const MPEScreenshotSaveLocationDesktop            = 3;
int const MPEScreenshotSaveLocationCustom             = 4;

int const MPEGoToFullscreenOnSameScreen               = 0;
int const MPEGoToFullscreenOnFixedScreen              = 1;