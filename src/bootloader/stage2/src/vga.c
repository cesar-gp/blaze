#include <stdint.h>
#include "vga.h"
#include "ports.h"

static const uint8_t digits[] = "0123456789ABCDEF";

/**
 *	Writes a character to a specific cell of the
 *	VGA buffer, given its coordinates and a color.
 * 
 *	Input:	self:	VGA graphics struct.
 *			chr:	ASCII character.
 *			x:		Column (x coordinate).
 *			y:		Row (y coordinate).
 * 
 *	See:	VGA (p. 7, 1.2.1)
 *			for VGA Text Modes reference.
 */
static void _vga_write(vga_t self, uint8_t chr, uint8_t x, uint8_t y) {
	((uint16_t*) MEM_VGABUFFER)[x + (VGA_COLS * y)] = (uint16_t) (self.color << 8) | chr;
}

/**
 *	Reads a value from the VGA CRTC data register
 *	given its offset, and returns it.
 * 
 *	Input:	self:	VGA graphics struct.
 *			offset:	VGA CRTC index register offset.
 * 
 *	See:	VGA (p. 21, 3.3)
 *			for VGA CRTC registers reference.
 */
static uint8_t _vga_in(vga_t self, uint8_t offset) {
	outb(self.crtci, offset);
	io_wait();
	return inb(self.crtcd);
}

/**
 *	Writes a value to a specific offset of the
 *	VGA CRTC data register.
 *
 *	Input:	self:	VGA graphics struct.
 *			offset:	VGA CRTC index register offset.
 *			value:	Value to write on the offset.
 *
 *	See:	VGA (p. 21, 3.3)
 *			for VGA CRTC registers reference.
 */
static void _vga_out(vga_t self, uint8_t offset, uint8_t value) {
	outb(self.crtci, offset);
	io_wait();
	outb(self.crtcd, value);
}

/**
 *	Initializes default values and port locations
 *	for VGA graphics. It should be called if the
 *	values of the VGA Miscellaneous Output Register
 *	have changed or are unknown.
 * 
 *	See:	VGA (p. 16, 3.1.1)
 *			for M.O. Register reference.
 */
vga_t* vga_init() {
	// Get CRT register port using I/O Address Select bit.
	uint8_t iosel = inb(PORT_VGAMOR) & 0x01;
	uint16_t crtci = iosel ? PORT_VGACRT1 : PORT_VGACRT0;

	// Initialize VGA struct.
	vga_t* out = (vga_t*) MEM_VGASTRUCT;

	// Set port values.
	out->crtci = crtci;
	out->crtcd = crtci + 1;

	// Get cursor position from I/O ports.
	uint8_t cursorh = _vga_in(*out, OFF_CURSORH);
	uint8_t cursorl = _vga_in(*out, OFF_CURSORL);

	uint16_t cursor = (uint16_t) (cursorh << 8) | (uint16_t) cursorl;
	out->x = cursor % VGA_COLS;
	out->y = cursor / VGA_COLS;

	// Set color to default.
	out->color = VGA_DEFCOLOR;

	// Return VGA graphics struct.
	return out;
}

/**
 *	Moves the VGA cursor to the specified cell
 *	and updates VGA graphics struct x and y values.
 * 
 *	Input:	self:	Pointer to VGA graphics struct.
 *			x:		Column (x coordinate).
 *			y:		Row (y coordinate).
 */
void vga_move(vga_t* self, uint8_t x, uint8_t y) {
	// Update VGA cursor position.
	uint16_t pos = y * VGA_COLS + x;
	_vga_out(*self, OFF_CURSORH, (uint8_t) (pos >> 8));
	_vga_out(*self, OFF_CURSORL, (uint8_t) pos);

	// Update VGA graphics struct variables.
	self->x = x;
	self->y = y;
}

/**
 *	Fills the VGA buffer with spaces of the
 *	current printing color.
 * 
 *	This function doesn't change the position
 *	of the cursor, nor does it initialize VGA
 *	graphics data.
 * 
 *	See:	`vga_move`
 *			to change cursor position.
 * 
 *			`vga_init`
 *			to initialize VGA graphics data.
 */
void vga_clear(vga_t self) {
	for(int y = 0; y < VGA_ROWS; y++)
		for(int x = 0; x < VGA_COLS; x++)
			_vga_write(self, ' ', x, y);
}

/**
 *	Advances the cursor a certain number of
 *	steps on the X axis, introducing new lines
 *	on row ends and overflowing on screen end.
 * 
 *	If a negative number is received, the steps
 *	will be performed to the left, and new lines
 *	will go upwards.
 * 
 *	Input:	deltax: Number of steps to advance.
 *					Can be a negative number.
 * 
 *	Note:	This function doesn't perform the
 *			movements one by one. It calculates
 *			the destination and moves the cursor
 *			there, which makes it less complex
 *			[O(1)] than the step approach, which
 *			has a complexity of O(deltax).
 */
void vga_step(vga_t* self, int16_t deltax) {
	// Calculate x and y after movement.
	int16_t movx = self->x + deltax;
	int16_t deltay = -(movx < 0) + (movx / VGA_COLS);
	int16_t movy = self->y + deltay;

	// Adjust x and y to the grid in case of negative stepping.
	if(movx < 0) movx = VGA_COLS + (movx % VGA_COLS);
	if(movy < 0) movy = VGA_ROWS + (movy % VGA_ROWS);

	// Move the cursor.
	vga_move(self, movx % VGA_COLS, movy % VGA_ROWS);
}

/**
 *	Outputs a character on the current position
 *	of the cursor and takes it to the next cell.
 * 
 *	The color of character will be defined by
 *	the `color` attribute of the VGA graphics
 *	struct.
 *
 *	Input:	self:	VGA graphics struct.
 *			chr:	Character to output.
 */
void vga_putc(vga_t* self, uint8_t chr) {
	// Handle special characters.
	switch(chr) {
		case '\n':
			vga_move(self, self->x, self->y + 1);
			return;
		case '\r':
			vga_move(self, 0, self->y);
			return;
		case '\t':
			uint8_t dstx = self->x + (4 - (self->x % 4));
			if(dstx >= VGA_COLS) vga_move(self, 0, self->y + 1);
			else vga_move(self, dstx, self->y);
			return;
	}

	// Write character and advance cursor.
	_vga_write(*self, chr, self->x, self->y);
	vga_step(self, 1);
}

/**
 *	TODO:	This function will be moved out of the VGA
 *			driver in future releases.
 */
void vga_putn(vga_t* self, int64_t num, radix_t rad) {
	// Zero? Output zero character and done.
	if(num == 0) {
		vga_putc(self, '0');
		return;
	}

	// Negative? Write sign and continue.
	if(num < 0) {
		vga_putc(self, '-');
		num *= -1;
	}

	// Create buffer for number digits and length.
	uint8_t numlen = 0;
	uint8_t numdig[20];

	// Write each digit on the buffer.
	while(num) {
		numdig[numlen++] = digits[num % rad];
		num /= rad;
	}

	// Output each character.
	for(uint8_t i = 0; i < numlen; i++)
		vga_putc(self, numdig[numlen - 1 - i]);
}

/**
 *	TODO:	This function will be moved out of the VGA
 *			driver in future releases.
 */
void vga_puts(vga_t* self, char* str) {
	while(*str) vga_putc(self, *str++);
}