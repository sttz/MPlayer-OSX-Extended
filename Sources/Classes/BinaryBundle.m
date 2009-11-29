/*  
 *  BinaryBundle.m
 *  MPlayerOSX Extended
 *  
 *  Created on 28.11.09
 *  
 *  Description:
 *	NSBundle wrapper that allows to "reload" the bundle.
 *  Reloading is limited to the info dictionary as well as 
 *  the executable architectures.
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

#include <mach-o/fat.h>
#include <mach-o/arch.h>
#include <mach-o/loader.h>

#import "BinaryBundle.h"

#import "RegexKitLite.h"

static NSString* const checkForArches = @"x86_64,i386,ppc64,ppc";

/*  Byte-swaps an executable's header (which consists entirely of four-byte quantities on four-byte boundaries).
 */
static void swap_header(uint8_t *bytes, ssize_t length) {
	ssize_t i;
	for (i = 0; i < length; i += 4) *(uint32_t *)(bytes + i) = OSSwapInt32(*(uint32_t *)(bytes + i));
}

@implementation BinaryBundle

- (void) invalidateBinaryBundle
{
	// Invalidate the info dictionary so it will be reloaded the next time it's accessed
	[infoDict release];
	infoDict = nil;
}

- (id) initWithPath:(NSString *)path
{
	if ((self = [super initWithPath:path]))
		// Save path to bundle to load info dictionary and executable architectures
		// For some reasons, using [self bundlePath] in -infoDictionary creates an endless loop
		pathToBundle = [[[NSURL fileURLWithPath:[path stringByStandardizingPath]] path] retain];
	return self;
}

- (NSDictionary *) infoDictionary
{
	if (!infoDict) {
		// Assume the info dictionary is located at Contents/Info.plist
		NSString *dictPath = [pathToBundle stringByAppendingPathComponent:@"Contents/Info.plist"];
		infoDict = [[NSDictionary dictionaryWithContentsOfFile:dictPath] retain];
	}
	
	return infoDict;
}

// Also override the following functions to make sure they all use the reloadable dictioanry
- (id) objectForInfoDictionaryKey:(NSString *)key
{
	return [[self infoDictionary] objectForKey:key];
}

- (NSString *)bundleIdentifier
{
	return [self objectForInfoDictionaryKey:@"CFBundleIdentifier"];
}

- (NSString *) executablePath
{
	// Assume the executable lies in Contents/MacOS/
	return [[pathToBundle stringByAppendingPathComponent:@"Contents/MacOS/"] 
			stringByAppendingPathComponent:[self objectForInfoDictionaryKey:@"CFBundleExecutable"]];
}

- (NSArray *) executableArchitectureStrings
{
	NSString *path = [self executablePath];
	
	int fd = open([path UTF8String], O_RDONLY, 0777);
	uint8_t bytes[512];
	ssize_t length;
	
	if (fd < 0)
		return nil;
	
	length = read(fd, bytes, 512); close(fd);
	
	if (length < sizeof(struct mach_header_64))
		return nil;
	
	uint32_t magic = 0, num_fat = 0, max_fat = 0;
	struct fat_arch one_fat = {0}, *fat = NULL;
	
	// Look for any of the six magic numbers relevant to Mach-O executables, and swap the header if necessary.
	magic = *((uint32_t *)bytes);
	max_fat = (length - sizeof(struct fat_header)) / sizeof(struct fat_arch);
	if (MH_MAGIC == magic || MH_CIGAM == magic) {
		struct mach_header *mh = (struct mach_header *)bytes;
		if (MH_CIGAM == magic) swap_header(bytes, length);
		one_fat.cputype = mh->cputype;
		one_fat.cpusubtype = mh->cpusubtype;
		fat = &one_fat;
		num_fat = 1;
	} else if (MH_MAGIC_64 == magic || MH_CIGAM_64 == magic) {
		struct mach_header_64 *mh = (struct mach_header_64 *)bytes;
		if (MH_CIGAM_64 == magic) swap_header(bytes, length);
		one_fat.cputype = mh->cputype;
		one_fat.cpusubtype = mh->cpusubtype;
		fat = &one_fat;
		num_fat = 1;
	} else if (FAT_MAGIC == magic || FAT_CIGAM == magic) {
		fat = (struct fat_arch *)(bytes + sizeof(struct fat_header));
		if (FAT_CIGAM == magic) swap_header(bytes, length);
		num_fat = ((struct fat_header *)bytes)->nfat_arch;
		if (num_fat > max_fat) num_fat = max_fat;
	}
	
	// Check if the header appears to be valid
	if (fat && num_fat < 0)
		return nil;
	
	// Check for a given set of arches
	const NXArchInfo *arch;
	NSMutableArray *foundArches = [NSMutableArray array];
	
	for (NSString *hasArch in [checkForArches componentsSeparatedByString:@","]) {
		arch = NXGetArchInfoFromName([hasArch UTF8String]);
		if (NXFindBestFatArch(arch->cputype, arch->cpusubtype, fat, num_fat))
			[foundArches addObject:hasArch];
	}
	
	return foundArches;
}

- (void) dealloc
{
	[infoDict release];
	[pathToBundle release];
	[super dealloc];
}

@end
