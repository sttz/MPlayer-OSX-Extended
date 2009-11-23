/*
 *  Preferences.h
 *  MPlayer OSX Extended
 *
 *  Created by Adrian on 20.11.09.
 *  Copyright 2009 __MyCompanyName__. All rights reserved.
 *
 */

#define PREFS [NSUserDefaults standardUserDefaults]

extern NSString* const MPEAdvancedOptions;
extern NSString* const MPEAnimateInterfaceTransitions;
extern NSString* const MPEAspectRatio;
extern NSString* const MPEBS2BFilter;
extern NSString* const MPEBlackOutOtherScreensInFullscreen;
extern NSString* const MPECacheSizeInMB;
extern NSString* const MPECheckForUpdatesIncludesPrereleases;
extern NSString* const MPECustomAspectRatio;
extern NSString* const MPECustomScreenshotsSavePath;
extern NSString* const MPECustomSizeInPx;
extern NSString* const MPEDefaultAudioLanguages;
extern NSString* const MPEDefaultDirectory;
extern NSString* const MPEDefaultSubtitleLanguages;
extern NSString* const MPEDeinterlaceFilter;
extern NSString* const MPEDisplaySize;
extern NSString* const MPEDropFrames;
extern NSString* const MPEEnableAudio;
extern NSString* const MPEEnableVideo;
extern NSString* const MPEFastDecoding;
extern NSString* const MPEFlipDisplayHorizontally;
extern NSString* const MPEFlipDisplayVertically;
extern NSString* const MPEFont;
extern NSString* const MPEFontStyle;
extern NSString* const MPEFullscreenDisplayNumber;
extern NSString* const MPEGoToFullscreenOn;
extern NSString* const MPEGuessTextEncoding;
extern NSString* const MPEHRTFFilter;
extern NSString* const MPEHardwareAC3Passthrough;
extern NSString* const MPEHardwareDTSPassthrough;
extern NSString* const MPEKaraokeFilter;
extern NSString* const MPELoadEmbeddedFonts;
extern NSString* const MPEOSDLevel;
extern NSString* const MPEOSDScale;
extern NSString* const MPEOverrideAudioCodecs;
extern NSString* const MPEOverrideVideoCodecs;
extern NSString* const MPEPostprocessingFilter;
extern NSString* const MPERenderSubtitlesFirst;
extern NSString* const MPEScreenshotSaveLocation;
extern NSString* const MPEStartPlaybackDisplayType;
extern NSString* const MPESubtitleBorderColor;
extern NSString* const MPESubtitleScale;
extern NSString* const MPESubtitleTextColor;
extern NSString* const MPETextEncoding;
extern NSString* const MPEWindowOnTopMode;

extern NSString* const MPECustomAspectRatioStringKey;
extern NSString* const MPECustomAspectRatioValueKey;

extern NSString* const MPEAdvancedOptionsStringKey;
extern NSString* const MPEAdvancedOptionsEnabledKey;

extern int const MPEStartPlaybackDisplayTypeWindow;
extern int const MPEStartPlaybackDisplayTypeFullscreen;
extern int const MPEStartPlaybackDisplayTypeDesktop;

extern int const MPEWindowOnTopModeNever; 
extern int const MPEWindowOnTopModeWhilePlaying;
extern int const MPEWindowOnTopModeAlways;

extern int const MPEDisplaySizeHalf;
extern int const MPEDisplaySizeOriginal;
extern int const MPEDisplaySizeDouble;
extern int const MPEDisplaySizeFitScreen;
extern int const MPEDisplaySizeCustom;

extern int const MPEScreenshotsDisabled;
extern int const MPEScreenshotSaveLocationHomeFolder;
extern int const MPEScreenshotSaveLocationDocumentsFolder;
extern int const MPEScreenshotSaveLocationPicturesFolder;
extern int const MPEScreenshotSaveLocationDesktop;
extern int const MPEScreenshotSaveLocationCustom;

extern int const MPEGoToFullscreenOnSameScreen;
extern int const MPEGoToFullscreenOnFixedScreen;

extern int const MPEDropFramesNever;
extern int const MPEDropFramesSoft;
extern int const MPEDropFramesHard;

extern int const MPEDeinterlaceFilterOff;
extern int const MPEDeinterlaceFilterYadif;
extern int const MPEDeinterlaceFilterKernel;
extern int const MPEDeinterlaceFilterFFmpeg;
extern int const MPEDeinterlaceFilterFilm;
extern int const MPEDeinterlaceFilterBlend;

extern int const MPEPostprocessingFilterOff;
extern int const MPEPostprocessingFilterDefault;
extern int const MPEPostprocessingFilterFast;
extern int const MPEPostprocessingFilterHighQuality;