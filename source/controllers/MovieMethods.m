/*  
 *  MovieMethods.h
 *  MPlayerOSX Extended
 *  
 *  Created by Bilal Syed Hussain on 2011-10-15
 *  
 */

#import "MovieMethods.h"
#import "Debug.h"

#include <ctype.h>
#include <stdlib.h>

@interface MovieMethods(){}
+ (NSArray*) enumerateAllFilesAtDirectory:(NSString*)dirPath
								withExtensions:(NSSet*)exts
							  beginningWith:(NSString*)seriesName;

+ (NSNumber*) acceptNextEpisode:(NSNumber*)current
						number:(NSNumber*)newNumber;

+ (NSNumber*) acceptPreviousEpisode:(NSNumber*)current
							number:(NSNumber*)newNumber;

@end

static char ** ep_num (char *s);

@implementation MovieMethods

#pragma mark - Finding the Next Episode

+(NSArray*) enumerateAllFilesAtDirectory:(NSString*)dirPath
								withExtensions:(NSSet*)exts
						   beginningWith:(NSString*)seriesName
{
	NSMutableArray *ret = nil;
	
	NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirPath];
	
	for (NSString *file in directoryEnumerator) {
		// enumerate the directory
		NSDictionary *fileAttr = [directoryEnumerator fileAttributes];
		
		if ([[fileAttr objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
			// skip all subdirectories
			[directoryEnumerator skipDescendants];
			
		// the normal file and the file extension is OK or if exts is nil, don't care the extensions
		} else if ([[fileAttr objectForKey:NSFileType] isEqualToString: NSFileTypeRegular] &&
				   ((exts && [exts containsObject:[[file pathExtension] lowercaseString]]) || (!exts))) {
			if ([file rangeOfString:seriesName options:NSAnchoredSearch].location != NSNotFound){
				if (!ret) { // lazy load
					ret = [[NSMutableArray alloc] initWithCapacity:20];
				}
				[ret addObject:file];	
			}
		}
	}
	return [ret autorelease];
}



+ (NSString*) findNextEpisodePathFrom:(NSString*)filepath
{
	//	All Movies
	NSSet *exts = [NSSet setWithObjects:@"3gp", @"3iv", @"asf", @"avi", @"asf", @"bin", @"cpk", @"dat", @"divx", @"dv", @"dvr-ms", @"fli", @"flv", @"h264", @"i263", @"m1v", @"m2t", @"m2ts", @"m2v", @"m4v", @"mkv", @"mov", @"mp2", @"mp4", @"mpeg", @"mpg", @"mpg2", @"mpg4", @"mpv", @"mqv", @"nut", @"nuv", @"nsv", @"ogg", @"ogm", @"ogv", @"qt", @"ram", @"rec", @"rm", @"rmvb", @"ts", @"vcd", @"vfw", @"vob", @"wmv", @"webm", nil];
	
	return [self findNextEpisodePathFrom:filepath 
			inFormats:exts];
}


+(NSString*) findNextEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts
{
	return [self episodePathFrom:filepath 
				inFormats:exts 
				   accept:@selector(acceptNextEpisode:number:)];
}

+ (NSString*) findPreviousEpisodePathFrom:(NSString*)filepath
{
	//	All Movies
	NSSet *exts = [NSSet setWithObjects:@"3gp", @"3iv", @"asf", @"avi", @"asf", @"bin", @"cpk", @"dat", @"divx", @"dv", @"dvr-ms", @"fli", @"flv", @"h264", @"i263", @"m1v", @"m2t", @"m2ts", @"m2v", @"m4v", @"mkv", @"mov", @"mp2", @"mp4", @"mpeg", @"mpg", @"mpg2", @"mpg4", @"mpv", @"mqv", @"nut", @"nuv", @"nsv", @"ogg", @"ogm", @"ogv", @"qt", @"ram", @"rec", @"rm", @"rmvb", @"ts", @"vcd", @"vfw", @"vob", @"wmv", @"webm", nil];
	
	return [self findPreviousEpisodePathFrom:filepath 
							   inFormats:exts];
}


+ (NSString*) findPreviousEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts
{
	return [self episodePathFrom:filepath 
					   inFormats:exts 
						  accept:@selector(acceptPreviousEpisode:number:)];
}



// Finds the next episode that that is accept by the selector
+ (NSString*) episodePathFrom:(NSString*)filepath 
				   inFormats:(NSSet*)exts
					  accept:(SEL)accept
{
	NSString *nextPath = nil;	
	if (filepath) {		
		NSString *dirPath = [filepath stringByDeletingLastPathComponent];
		NSString *movieName = [[filepath lastPathComponent] stringByDeletingPathExtension];
		char* cMovieName = strdup([movieName UTF8String]);
		char **ans = ep_num(cMovieName);
		if (ans[0] != NULL) { // The filename was parsed successfully 
			// Gets the episodeNumber		
			long episodeNumber = strtol(ans[0] + 1, NULL, 10);
			if (episodeNumber == 0 ) episodeNumber++;  
			
			// Get the series name 
			int index = ans[1] != NULL ? 1 : 0;
			char name[ ans[index] - cMovieName + 1];
			strncpy(name, cMovieName, ans[index] - cMovieName);
			name[ans[index] - cMovieName] = '\0';   
			
			free(ans);
			free(cMovieName);
			
			
			NSArray *arr = [self enumerateAllFilesAtDirectory:dirPath 
													 withExtensions:exts 
												beginningWith:[[NSString alloc] initWithUTF8String:name]];
			
			if (arr){
				[Debug log:ASL_LEVEL_DEBUG withMessage:@"Resulting filenames=%@ ",arr ];
				for (NSString *s in arr) {
					char* cName = strdup([s UTF8String]);
					char **result = ep_num(cName);
					if (result[0] != NULL){
						long newEpisodeNumber = strtol(result[0] + 1, NULL, 10);
						BOOL use = 
						[[self performSelector:accept 
								   withObject:[NSNumber numberWithInt:episodeNumber]
								   withObject:[NSNumber numberWithInt:newEpisodeNumber]] boolValue];
						if (use){
							nextPath = [dirPath stringByAppendingPathComponent:s];
							free(result);
							free(cName);
							break;
						}
					}
					free(result);
					free(cName);
				}	
			}
		}
	}	
	[Debug log:ASL_LEVEL_DEBUG withMessage:@"nextPath =%@ ",nextPath ];
	return [nextPath retain];
}

+ (NSNumber*) acceptNextEpisode:(NSNumber*)current
						number:(NSNumber*)newNumber
{
	return [NSNumber numberWithInt:[current intValue]+1 == [newNumber intValue]];
}

+ (NSNumber*) acceptPreviousEpisode:(NSNumber*)current
							number:(NSNumber*)newNumber
{
	return [NSNumber numberWithInt:[current intValue]-1 == [newNumber intValue]];
}


/**
 * Get the postion of the name and number from the filename.
 *
 * @param  s - A c string.
 * @return An array containg:
 *         [0] - The index before the number starts.
 *         [1] - arr[index - s + 1] is the name part of the string,
 *               where index = (arr[1] != NULL) ? 1 : 0
 *
 * @error        [0] == NULL - Number not found
 */ 
static char **ep_num (char *s) 
{
	assert (s);
	char *start  = s;
	char **ans = calloc(2, sizeof(size_t));
	int index = 0;
	int num   = 0;
	int dashes = 0;
	
	bool hack = false;
	
	// To handle space at start of filename
	if    (*s == ' ') hack = true;
	while (*s == ' ') s++; 
	
	if (hack){
		start = s;
	}
	
	// finds the end of the string
	while (*s != '\0' ) {
		if (num ==0 && isdigit(*s) ) num++;
		else if (*s == '-' ) dashes++;
		s++;	
	}
	
	// if there is no number (e.g movie) the whole string is the name.
	if (num == 0 ){
		ans[0] = ans[1] = s;
		char *temp = s - 1;
		while ( temp != start ){
			if ( *temp == '.'){
				ans[1] = temp;
				break;
			}
			temp--;
		}
		return ans;
	}
	
	while (*s != *start) {
		if (index == 0 && (*s == '-' || *s == ' ' || *s == '_'  || *s  == '~' ) ) {
			//if for 'word - 22 .mkv' types
			if(! isdigit(*(s-1))){
				ans[index]  = s;
				index++;
				// To handle - types
				if( (s - start) >=2 ) ans[index] = s-2;
			}
		}
		
		if(index == 1 && !(*s == ' ' || *s == '-' || *s == '_' || *s  == '~'  ) ) {
			char *t = (s + 1);
			if( *t == ' ' || *t == '-' || *t == '_' || *t  == '~' ) {
				if (*t == '~' && dashes > 0 ) t++;
				ans[index] = t;
				break;
			}
		}
		
		s--;
	}
	
	return ans;
}

@end
