#include <stdint.h>
#include "entry.h"

void halt() {
	__asm__("cli");
	for(;;);
}

void __attribute__((__cdecl__)) main() {
	// Visual sign that indicates we've been here.
	char* vgabuf = (char*) 0xB8000;
	vgabuf[0] = '!';
	vgabuf[1] = 0x0A;

	// Call to 'halt' to make sure we don't return.
	halt();
}