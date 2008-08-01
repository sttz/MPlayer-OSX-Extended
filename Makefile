# export NEXT_ROOT=/Developer/SDKs/MacOSX10.3.9.sdk
# export MACOSX_DEPLOYMENT_TARGET=10.3
# CFLAGS="-isystem /Developer/SDKs/MacOSX10.3.9.sdk/usr/include/gcc/darwin/3.3 -isystem /Developer/SDKs/MacOSX10.3.9.sdk/usr/include"
# LDFLAGS="-L/Developer/SDKs/MacOSX10.3.9.sdk/usr/lib/gcc/darwin/3.3"
# ./configure --with-termcaplib=ncurses.5 --disable-gl --disable-x11
# ./configure --with-termcaplib=ncurses.5 --disable-gl --disable-x11 --disable-altivec

all:
	xcodebuild -target "MPlayer OSX" -configuration Release build

dist:	all
	rm -rf dist
	mkdir dist
	cp -r ./build/Release/* dist/
	cp *.rtf dist/
	cp *.webloc dist/
	./create_dmg

clean:
	xcodebuild clean
	rm -rf build build_ppc *.dmg dist

