/*  
 *  MovieMethods.h
 *  MPlayerOSX Extended
 *  
 *  Created by Bilal Syed Hussain on  2011-10-15
 *  
 */

#import <Foundation/Foundation.h>


@interface MovieMethods : NSObject {
@private
    
}

// Return the filepath of the Next episode based on filepath
// returns nil if not found.
// exts is the set of vaild extension, pass null to consider all extensions
+ (NSString*) findNextEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts;

// As Above with all movie formats
+ (NSString*) findNextEpisodePathFrom:(NSString*)filepath;


// Return the filepath of the Previous episode based on filepath
// returns nil if not found.
// exts is the set of vaild extension, pass null to consider all extensions
+ (NSString*) findPreviousEpisodePathFrom:(NSString*)filepath inFormats:(NSSet*)exts;
// As Above with all movie formats
+ (NSString*) findPreviousEpisodePathFrom:(NSString*)filepath;

// Return the filepath of the episode that is accepted by the selector based on the filepath
// returns nil if not found.
// exts is the set of vaild extension, pass null to consider all extensions
+ (NSString*) episodePathFrom:(NSString*)filepath 
				   inFormats:(NSSet*)exts
					  accept:(SEL)accept;

@end
