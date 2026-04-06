SECTIONS {
	. = 0x00007C00;
	.text	:	{ LD_TEXT		= .;	*(.text)	}
	LD_END = .;
}