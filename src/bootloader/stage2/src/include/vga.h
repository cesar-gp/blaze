#pragma once

/**
 *	VGA Text Mode 2, 3 defaults.
 * 
 *	This implementation assumes the PC
 *	sets VGA BIOS Mode to 2 or 3 on boot.
 * 
 *	See:	RBIL (INTERRUP.LST, V-100F)
 *			for detecting video mode using
 *			INT 10h/AH=0Fh output.
 * 
 *			VGA (p. 7, 1.2.1, Table 1-1)
 *			for VGA Text Modes table.
 */
#define VGA_COLS		80
#define VGA_ROWS		25
#define VGA_DEFCOLOR	0x0F		// Blaze implementation.

/**
 *	Linear memory addresses for VGA data.
 * 
 *	See:	VGA (p. 7, 1.2.1, Table 1-1)
 *			for MEM_VGABUFFER reference.
 */
#define	MEM_VGABUFFER	0x000B8000
#define MEM_VGASTRUCT	0x00010000	// Blaze implementation.

/**
 *	VGA I/O Ports.
 * 
 *	See:	VGA (p. 16, 3.1.1)
 *			for PORT_VGAMOR reference.
 * 
 *			VGA (p. 21, 3.3)
 *			for PORT_VGACRT* reference.
 */
#define PORT_VGAMOR		0x03CC		// Miscellaneous Output Reg. read port.
#define PORT_VGACRT0	0x03B4		// CRTC data port on I/O Address Sel. 0.
#define PORT_VGACRT1	0x03D4		// CRTC data port on I/O Address Sel. 1.

/**
 *	VGA CRTC Index offsets.
 * 
 *	See:	VGA (p. 21, 3.3, Table 3-3)
 *			for CRTC Index reference.
 */
#define OFF_CURSORH		0x0E
#define OFF_CURSORL		0x0F

/**
 *	VGA Text Mode Attribute Byte bitmasks.
 * 
 *	See:	VGA (p. 7, 1, Table 1-2)
 *			for Attribute Byte reference.
 * 
 *	See:	VGA (p. 37, 3.5.3)
 *			for Attribute Mode Control
 *			reference.
 */
#define AB_BGIB			0x80		// Background Intensity / Blink.
#define	AB_BGR			0x40		// Background Red.
#define AB_BGG			0x20		// Background Green.
#define AB_BGB			0x10		// Background Blue.
#define	AB_FGIF			0x08		// Foreground Intensity / Font select.
#define AB_FGR			0x04		// Foreground Red.
#define AB_FGG			0x02		// Foreground Green.
#define AB_FGB			0x01		// Foreground Blue.

/**
 *	Radixes for common numeral systems.
 * 
 *	TODO: move with vga_putn.
 */
typedef enum {
	BINARY				= 2,
	OCTAL				= 8,
	DECIMAL				= 10,
	HEXADECIMAL			= 16
} radix_t;

/**
 *	VGA port and output data.
 */
typedef struct {
	uint16_t crtci;					// Read-only values.
	uint16_t crtcd;
	uint8_t x;
	uint8_t y;
	uint8_t color;					// Read-write values.
} vga_t;

vga_t* vga_init();
void vga_clear(vga_t self);
void vga_move(vga_t* self, uint8_t x, uint8_t y);
void vga_step(vga_t* self, int16_t deltax);
void vga_putc(vga_t* self, uint8_t chr);
void vga_puts(vga_t* self, char* str);
void vga_putn(vga_t* self, int64_t num, radix_t rad);