#import "PlayerWindow.h"

#import "PlayerController.h"

#define SCROLL_SEEK_MULT	10.0

#define KEY_ENTER 13
#define KEY_TAB 9

#define KEY_BASE 0x100

/*  Function keys  */
#define KEY_F (KEY_BASE+64)

/* Control keys */
#define KEY_CTRL (KEY_BASE)
#define KEY_BACKSPACE (KEY_CTRL+0)
#define KEY_DELETE (KEY_CTRL+1)
#define KEY_INSERT (KEY_CTRL+2)
#define KEY_HOME (KEY_CTRL+3)
#define KEY_END (KEY_CTRL+4)
#define KEY_PAGE_UP (KEY_CTRL+5)
#define KEY_PAGE_DOWN (KEY_CTRL+6)
#define KEY_ESC (KEY_CTRL+7)

/* Control keys short name */
#define KEY_BS KEY_BACKSPACE
#define KEY_DEL KEY_DELETE
#define KEY_INS KEY_INSERT
#define KEY_PGUP KEY_PAGE_UP
#define KEY_PGDOWN KEY_PAGE_DOWN
#define KEY_PGDWN KEY_PAGE_DOWN

/* Cursor movement */
#define KEY_CRSR (KEY_BASE+16)
#define KEY_RIGHT (KEY_CRSR+0)
#define KEY_LEFT (KEY_CRSR+1)
#define KEY_DOWN (KEY_CRSR+2)
#define KEY_UP (KEY_CRSR+3)

/* XF86 Multimedia keyboard keys */
#define KEY_XF86_BASE (0x100+384)
#define KEY_XF86_PAUSE (KEY_XF86_BASE+1)
#define KEY_XF86_STOP (KEY_XF86_BASE+2)
#define KEY_XF86_PREV (KEY_XF86_BASE+3)
#define KEY_XF86_NEXT (KEY_XF86_BASE+4)
  
/* Keypad keys */
#define KEY_KEYPAD (KEY_BASE+32)
#define KEY_KP0 (KEY_KEYPAD+0)
#define KEY_KP1 (KEY_KEYPAD+1)
#define KEY_KP2 (KEY_KEYPAD+2)
#define KEY_KP3 (KEY_KEYPAD+3)
#define KEY_KP4 (KEY_KEYPAD+4)
#define KEY_KP5 (KEY_KEYPAD+5)
#define KEY_KP6 (KEY_KEYPAD+6)
#define KEY_KP7 (KEY_KEYPAD+7)
#define KEY_KP8 (KEY_KEYPAD+8)
#define KEY_KP9 (KEY_KEYPAD+9)
#define KEY_KPDEC (KEY_KEYPAD+10)
#define KEY_KPINS (KEY_KEYPAD+11)
#define KEY_KPDEL (KEY_KEYPAD+12)
#define KEY_KPENTER (KEY_KEYPAD+13)

@implementation PlayerWindow

- (void)keyDown:(NSEvent *)theEvent
{
	int key;
	switch([theEvent keyCode])
    {
		//case 0x31: [playerController playPause:nil]; break;
		case 0x34:
		case 0x24: key = KEY_ENTER; break;
		case 0x35: key = KEY_ESC; break;
		case 0x33: key = KEY_BACKSPACE; break;
		case 0x3A: key = KEY_BACKSPACE; break;
		case 0x3B: key = KEY_BACKSPACE; break;
		case 0x38: key = KEY_BACKSPACE; break;
		case 0x7A: key = KEY_F+1; break;
		case 0x78: key = KEY_F+2; break;
		case 0x63: key = KEY_F+3; break;
		case 0x76: key = KEY_F+4; break;
		case 0x60: key = KEY_F+5; break;
		case 0x61: key = KEY_F+6; break;
		case 0x62: key = KEY_F+7; break;
		case 0x64: key = KEY_F+8; break;
		case 0x65: key = KEY_F+9; break;
		case 0x6D: key = KEY_F+10; break;
		case 0x67: key = KEY_F+11; break;
		case 0x6F: key = KEY_F+12; break;
		case 0x72: key = KEY_INSERT; break;
		case 0x75: key = KEY_DELETE; break;
		case 0x73: key = KEY_HOME; break;
		case 0x77: key = KEY_END; break;
		//case 0x45: [playerController sendToMplayersInput:@"volume 100 1"]; break; //+
		//case 0x4E: [playerController sendToMplayersInput:@"volume 0 1"]; break; //-
		case 0x30: key = KEY_TAB; break;
		case 0x74: key = KEY_PAGE_UP; break;
		case 0x79: key = KEY_PAGE_DOWN; break;  
		case 0x7B: key = KEY_LEFT; break;
		case 0x7C: key = KEY_RIGHT; break;
		case 0x7D: key = KEY_DOWN; break;
		case 0x7E: key = KEY_UP; break;
		case 0x43: key = '*'; break;
		case 0x4B: key = '/'; break;
		case 0x4C: key = KEY_KPENTER; break;
		case 0x41: key = KEY_KPDEC; break;
		case 0x52: key = KEY_KP0; break;
		case 0x53: key = KEY_KP1; break;
		case 0x54: key = KEY_KP2; break;
		case 0x55: key = KEY_KP3; break;
		case 0x56: key = KEY_KP4; break;
		case 0x57: key = KEY_KP5; break;
		case 0x58: key = KEY_KP6; break;
		case 0x59: key = KEY_KP7; break;
		case 0x5B: key = KEY_KP8; break;
		case 0x5C: key = KEY_KP9; break;
		default:
		{
			key = *[[theEvent characters] UTF8String];
		}
		break;
    }

	[playerController sendKeyEvent: key];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
	float dY = [theEvent deltaY];
	float dX = [theEvent deltaX];
	
	// volume
	if (fabsf(dY) > 0.99 && fabsf(dY) > fabsf(dX)) {
		
		[playerController setVolume:[playerController volume]+dY];
	
	// seek
	} else if (fabsf(dX) > 0.99) {
		
		// reset accumulated time when reversing
		if ((dX < 0 && scrollXAcc > 0) || (dX > 0 && scrollXAcc < 0))
			scrollXAcc = 0;
		
		// accumulate time while player is busy
		scrollXAcc += dX;
		
		// seek when ready
		if (![playerController isSeeking]) {
			[playerController seek:(-dX*SCROLL_SEEK_MULT) mode:MIRelativeSeekingMode];
			dX = 0;
		}
	}
}
@end
