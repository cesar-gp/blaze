#include <stdint.h>
#include "vga.h"

static uint16_t* VGA_BUFFER = (uint16_t*) 0xB8000;

static uint8_t x = 0;
static uint8_t y = 0;
static uint8_t color = VGA_DEFCOLOR;

void _vga_write(char chr, uint8_t x, uint8_t y, uint8_t color) {
	VGA_BUFFER[x + (VGA_COLS * y)] = (uint16_t) (color << 8) | chr;
}

void vga_move(uint8_t dstx, uint8_t dsty) {
	x = dstx % VGA_COLS;
	y = dsty % VGA_ROWS;

	VGA_CURMOVE(x, y);
}

void _vga_advance(uint16_t deltax) {
	uint16_t movx = x + deltax;
	uint8_t deltay = movx / VGA_COLS;

	vga_move((uint8_t) (movx % VGA_COLS), y + deltay);
}

void _vga_putc(char chr) {
	switch(chr) {
		case '\n':
			vga_move(x, y + 1);
			return;
		case '\r':
			vga_move(0, y);
			return;
		case '\t':
			uint8_t dstx = x + (4 - (x % 4));

	}

	_vga_write(chr, x, y, color);
	_vga_advance(1);
}

void vga_clear() {
	for(int y = 0; y < VGA_ROWS; y++)
		for(int x = 0; x < VGA_COLS; x++) {
			_vga_write(' ', x, y, VGA_DEFCOLOR);
		}
}

void vga_puts(char* str) {
	while(*str) _vga_putc(*str++);
}