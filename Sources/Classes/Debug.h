//
//  Debug.h
//  MPlayer OSX
//
//  Created by Adrian on 11.08.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <asl.h>

#define dSender		"MPlayer OSX"
#define dFacility	"user"
#define dFilterUpto	ASL_LEVEL_WARNING

@interface Debug : NSObject {
	
}

// Initialize debugger
+ (void) init;

// Log to file
+ (void) logToFile:(NSString *)path;

// Log message
+ (void) log:(int)level withMessage:(NSString *)message, ...;

@end
