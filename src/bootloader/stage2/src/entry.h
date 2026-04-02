#pragma once

void __attribute__((cdecl)) DEBUG();

void __attribute__((cdecl)) S1_DISK_LBATOCHS(
	uint16_t lba,
	uint16_t* cylinder,
	uint8_t* head,
	uint8_t* sector
);