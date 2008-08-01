//
//  main.m
//  MPlayer OSX
//
//  Created by Nicolas Plourde on 13/06/05.
//  Copyright The MPlayer Project 2005. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
	id pool = [NSAutoreleasePool new];
	NSString *logPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/MPlayerOSX.log"];
	freopen([logPath fileSystemRepresentation], "a", stderr);
	[pool release];
	
	NSLog(@"===================== MPlayer OSX Started =====================");
    
	return NSApplicationMain(argc,  (const char **) argv);
}
