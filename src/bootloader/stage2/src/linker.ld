SECTIONS {
	. = 0x00000500;

	.entry	:	{ LD_ENTRY		= .;	*(.entry)	}
	.text	:	{ LD_TEXT		= .;	*(.text)	}
	.data	:	{ LD_DATA		= .;	*(.data)	}
	.rodata :	{ LD_RODATA		= .;	*(.rodata)	}
	.bss	:	{ LD_BSS		= .;	*(.bss)		}

	LD_END = .;
}