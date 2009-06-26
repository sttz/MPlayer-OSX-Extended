//
//  main.m
//  MPlayer OSX
//
//  Created by Nicolas Plourde on 13/06/05.
//  Copyright The MPlayer Project 2005. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Debug.h"

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
#ifdef DEBUG
	[Debug setSharedDebuggerConnectsStderr:YES];
#endif
	
	Debug *logger = [Debug sharedDebugger];
	[logger logToFile:[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MPlayerOSX.log"]];
	
	[Debug log:ASL_LEVEL_INFO withMessage: @"===================== MPlayer OSX Started ====================="];
    
	[pool release];
	
	return NSApplicationMain(argc,  (const char **) argv);
}
