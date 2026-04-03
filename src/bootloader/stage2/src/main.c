#include <stdint.h>
#include "entry.h"
#include "vga.h"

void __attribute__((__cdecl__)) main() {
	// Visual sign that indicates we've been here.
	vga_clear();
	vga_puts("System booted correctly!");
	
	// Call to 'halt' to make sure we don't return.
	HALT32();
}