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

#define PREFS [NSUserDefaults standardUserDefaults]

// *** Top-Level preferences keys
extern NSString* const MPEAdvancedOptions;
extern NSString* const MPEAnimateInterfaceTransitions;
extern NSString* const MPEUseYUY2VideoFilter;
extern NSString* const MPEAspectRatio;
extern NSString* const MPEAudioDelay;
extern NSString* const MPEAudioEqualizerEnabled;
extern NSString* const MPEAudioEqualizerPresets;
extern NSString* const MPEAudioEqualizerSelectedPreset;
extern NSString* const MPEAudioEqualizerValues;
extern NSString* const MPEAudioItemRelativeVolume;
extern NSString* const MPEAudioMute;
extern NSString* const MPEAudioOutputDevice;
extern NSString* const MPEAudioVolume;
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
extern NSString* const MPEExpandedInspectorSections;
extern NSString* const MPEFastDecoding;
extern NSString* const MPEFlipDisplayHorizontally;
extern NSString* const MPEFlipDisplayVertically;
extern NSString* const MPEFont;
extern NSString* const MPEFontStyle;
extern NSString* const MPEFullscreenBlockOthers;
extern NSString* const MPEFullscreenDisplayNumber;
extern NSString* const MPEGoToFullscreenOn;
extern NSString* const MPEGuessTextEncoding;
extern NSString* const MPEHRTFFilter;
extern NSString* const MPEHardwareAC3Passthrough;
extern NSString* const MPEHardwareDTSPassthrough;
extern NSString* const MPEInspectorOpen;
extern NSString* const MPEKaraokeFilter;
extern NSString* const MPELoadEmbeddedFonts;
extern NSString* const MPELoopMovie;
extern NSString* const MPEOSDLevel;
extern NSString* const MPEOSDScale;
extern NSString* const MPEOverrideAudioCodecs;
extern NSString* const MPEOverrideVideoCodecs;
extern NSString* const MPEPlaybackSpeed;
extern NSString* const MPEPlaylist;
extern NSString* const MPEPlaylistOpen;
extern NSString* const MPEPlaylistPlayMode;
extern NSString* const MPEPostprocessingFilter;
extern NSString* const MPERenderSubtitlesFirst;
extern NSString* const MPEScaleMode;
extern NSString* const MPEScreenshotSaveLocation;
extern NSString* const MPESelectedBinary;
extern NSString* const MPESelectedPreferencesSection;
extern NSString* const MPEStartPlaybackDisplayType;
extern NSString* const MPEStartTime;
extern NSString* const MPESubtitleBorderColor;
extern NSString* const MPESubtitleDelay;
extern NSString* const MPESubtitleItemRelativeScale;
extern NSString* const MPESubtitleScale;
extern NSString* const MPESubtitleTextColor;
extern NSString* const MPETextEncoding;
extern NSString* const MPEUpdateBinaries;
extern NSString* const MPEUse32bitBinaryon64bit;
extern NSString* const MPEVideoEqualizerValues;
extern NSString* const MPEVideoEqualizerEnabled;
extern NSString* const MPEWindowOnTopMode;

// *** Top-level constants keys
extern NSString* const MPEAudioDelayStepSize;
extern NSString* const MPEFullscreenControlsHideTimeout;
extern NSString* const MPEFullscreenControlsSensitivity;
extern NSString* const MPEPlaybackSpeedMultiplierSmall;
extern NSString* const MPEPlaybackSpeedMultiplierBig;
extern NSString* const MPEPreflightNumInstances;
extern NSString* const MPERemoteSeekBase;
extern NSString* const MPERemoteSkipStep;
extern NSString* const MPEScrollWheelSeekMultiple;
extern NSString* const MPESeekStepLarge;
extern NSString* const MPESeekStepMedium;
extern NSString* const MPESeekStepSmall;
extern NSString* const MPESubtitleDelayStepSize;
extern NSString* const MPEVolumeStepSize;

// *** MPECustomAspectRatio dictionary keys
extern NSString* const MPECustomAspectRatioStringKey;
extern NSString* const MPECustomAspectRatioValueKey;

// *** MPEAdvancedOptions dictionaries keys
extern NSString* const MPEAdvancedOptionsStringKey;
extern NSString* const MPEAdvancedOptionsEnabledKey;

// *** MPEStartPlaybackDisplayType values
extern int const MPEStartPlaybackDisplayTypeWindow;
extern int const MPEStartPlaybackDisplayTypeFullscreen;
extern int const MPEStartPlaybackDisplayTypeDesktop;

// *** MPEWindowOnTopMode values
extern int const MPEWindowOnTopModeNever; 
extern int const MPEWindowOnTopModeWhilePlaying;
extern int const MPEWindowOnTopModeAlways;

// *** MPEDisplaySize values
extern int const MPEDisplaySizeHalf;
extern int const MPEDisplaySizeOriginal;
extern int const MPEDisplaySizeDouble;
extern int const MPEDisplaySizeFitScreen;
extern int const MPEDisplaySizeCustom;

// *** MPEScreenshotSaveLocation values
extern int const MPEScreenshotsDisabled;
extern int const MPEScreenshotSaveLocationHomeFolder;
extern int const MPEScreenshotSaveLocationDocumentsFolder;
extern int const MPEScreenshotSaveLocationPicturesFolder;
extern int const MPEScreenshotSaveLocationDesktop;
extern int const MPEScreenshotSaveLocationCustom;

// *** MPEGoToFullscreenOn values
extern int const MPEGoToFullscreenOnSameScreen;
extern int const MPEGoToFullscreenOnFixedScreen;

// *** MPEDropFrames values
extern int const MPEDropFramesNever;
extern int const MPEDropFramesSoft;
extern int const MPEDropFramesHard;

// *** MPEDeinterlaceFilter values
extern int const MPEDeinterlaceFilterOff;
extern int const MPEDeinterlaceFilterYadif;
extern int const MPEDeinterlaceFilterKernel;
extern int const MPEDeinterlaceFilterFFmpeg;
extern int const MPEDeinterlaceFilterFilm;
extern int const MPEDeinterlaceFilterBlend;

// *** MPEPostprocessingFilter values
extern int const MPEPostprocessingFilterOff;
extern int const MPEPostprocessingFilterDefault;
extern int const MPEPostprocessingFilterFast;
extern int const MPEPostprocessingFilterHighQuality;

// *** MPEVideoEqualizerValues dictionary keys
extern NSString* const MPEVideoEqualizerBrightness;
extern NSString* const MPEVideoEqualizerContrast;
extern NSString* const MPEVideoEqualizerGamma;
extern NSString* const MPEVideoEqualizerHue;
extern NSString* const MPEVideoEqualizerSaturation;
