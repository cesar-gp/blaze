#pragma once

#include <stdint.h>

inline uint8_t inb(uint16_t port) {
	uint8_t ret;

	__asm__ volatile(
		"inb %w1, %b0"				// Read 'port' to 'ret'.
		: "=a"(ret)					// Output: 'ret' (eax).
		: "Nd"(port)				// Input: 'port' (const).
		: "memory");				// Changes memory state.

	return ret;
}

inline void outb(uint16_t port, uint8_t value) {
	__asm__ volatile (
		"outb %b0, %w1"				// Send 'value' to 'port'.
		: /* No outputs. */
		: "a"(value), "Nd"(port)	// Input: 'value' (eax), 'port' (const).
		: "memory");				// Changes memory state.
}

inline void io_wait() {
	outb(0x80, 0);
}