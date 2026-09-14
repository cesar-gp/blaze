SECTIONS {
	. = 0x00000500;

	.text	:	{
		LD_ENTRY	= .;	*(.entry)
		LD_TEXT		= .;	*(.text)
	}
	.data	:	{ LD_DATA		= .;	*(.data)	}
	.rodata :	{ LD_RODATA		= .;	*(.rodata)	}
	.bss	:	{ LD_BSS		= .;	*(.bss)		}

	LD_END = .;
}