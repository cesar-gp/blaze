#include <stdint.h>
#include "entry.h"
#include "vga.h"

void __attribute__((cdecl)) main() {
	vga_t* vga = vga_init();
	vga->color = AB_FGG | AB_FGIF;
	vga_puts(vga, "[OK] ");
	vga->color = AB_FGR | AB_FGG | AB_FGB | AB_FGIF;
	vga_puts(vga, "Bootloader executed!\n\r");

	HALT32();
}