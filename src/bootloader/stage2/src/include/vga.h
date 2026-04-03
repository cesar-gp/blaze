#pragma once

#define VGA_COLS 80
#define VGA_ROWS 25

#define VGA_DEFCOLOR 0x0F

void __attribute__((cdecl)) VGA_CURMOVE(uint8_t x, uint8_t y);

inline void vga_move(uint8_t x, uint8_t y);
inline void vga_puts(char* str);
inline void vga_clear();

void _vga_advance(uint16_t deltax);