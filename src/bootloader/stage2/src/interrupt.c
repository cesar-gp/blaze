#include "vga.h"
#include "entry.h"

static char* ids[] = {
	"#DE",
	"#DB",
	"#02",
	"#BP",
	"#OF",
	"#BR",
	"#UD",
	"#NM",
	"#DF",
	"#MF",
	"#TS",
	"#NP",
	"#SS",
	"#GP",
	"#PF",
	"#MF",
	"#AC",
	"#MC",
	"#XM",
	"#VE",
	"#CP"
};

static char* messages[] = {
	"(Divide Error)",
	"(Debug)",
	"(Non-Maskable Interrupt)",
	"(Breakpoint)",
	"(Overflow)",
	"(BOUND Range Exceeded)",
	"(Invalid Opcode - Undefined Opcode)",
	"(Device Not Available - No Math Coprocessor)",
	"(Double Fault)",
	"(Coprocessor Segment Overrun)",
	"(Invalid TSS)",
	"(Segment Not Present)",
	"(Stack Segment Fault)",
	"(General Protection Fault)",
	"(Page Fault)",
	"(Floating-Point Error - Math Fault)",
	"(Alignment Check)",
	"(Machine Check)",
	"(SIMD Floating Point Exception)",
	"(Virtualization Exception)",
	"(Control Protection Exception)"
};

static void isr(uint8_t exception) {
	vga_t* vga = vga_init();
	vga_clear(*vga);
	vga_move(vga, 0, 0);

	vga->color = AB_FGR | AB_FGIF;
	vga_puts(vga, "Exception: ");

	vga->color = AB_FGR | AB_FGG | AB_FGB | AB_FGIF;
	vga_puts(vga, ids[exception]);
	vga_puts(vga, " ");

	vga->color = AB_FGR | AB_FGG | AB_FGB;
	vga_puts(vga, messages[exception]);

	HALT32();
}

void isr00() { isr(0x00); }
void isr01() { isr(0x01); }
void isr02() { isr(0x02); }
void isr03() { isr(0x03); }
void isr04() { isr(0x04); }
void isr05() { isr(0x05); }
void isr06() { isr(0x06); }
void isr07() { isr(0x07); }
void isr08() { isr(0x08); }
void isr09() { isr(0x09); }
void isr0A() { isr(0x0A); }
void isr0B() { isr(0x0B); }
void isr0C() { isr(0x0C); }
void isr0D() { isr(0x0D); }
void isr0E() { isr(0x0E); }
void isr10() { isr(0x10); }
void isr11() { isr(0x11); }
void isr12() { isr(0x12); }
void isr13() { isr(0x13); }
void isr14() { isr(0x14); }
void isr15() { isr(0x15); }
