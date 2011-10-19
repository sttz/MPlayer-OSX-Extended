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
+(NSArray*) enumerateAllFilesAtDirectory:(NSString*)dirPath
								withExtensions:(NSSet*)exts
							  beginningWith:(NSString*)seriesName;
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
		// enumerate the folder
		NSDictionary *fileAttr = [directoryEnumerator fileAttributes];
		
		if ([[fileAttr objectForKey:NSFileType] isEqualToString:NSFileTypeDirectory]) {
			// skip all sub-folders
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


+(NSString*) findNextEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts
{
	NSString *nextPath = nil;	
	if (filepath) {		
		NSString *dirPath = [filepath stringByDeletingLastPathComponent];
		NSString *movieName = [[filepath lastPathComponent] stringByDeletingPathExtension];
		char* cMovieName = strdup([movieName UTF8String]);
		char **ans = ep_num(cMovieName);
		if (ans[0] != NULL) {
			
			long episodeNumber = strtol(ans[0] + 1, NULL, 10);
			if (episodeNumber == 0 ) episodeNumber++;  
			
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
						long nextEpisodeNumber = strtol(result[0] + 1, NULL, 10);
						if (nextEpisodeNumber == episodeNumber + 1){
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
	
	// Quick hack to fix space at start of filename
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
				// quick fix for - types
				if( (s - start) >=2 ) ans[index] = s-2;
			}
		}
		
		//else 
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
