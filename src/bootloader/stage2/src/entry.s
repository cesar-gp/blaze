;	---------------- CONSTANTS ----------------
;
;	See:	RBIL (MEMORY.LST, B-M00000400)
;			for BIOS data area. IVT descriptor
;			is placed at its beginning. The two
;			sectors before contain the table.
;
;			RBIL (PORTS.LST, K-P0060006F, "0060  R-")
;			for port KBDDATA (0x0060).
;
;			RBIL (PORTS.LST, K-P0060006F, "0064  RW")
;			for port KBDSTATUS (0x0064).
;
;			RBIL (PORTS.LST, P0020003F, "0021  RW")
;			for port PIC1DATA (0x0021).
;
;			RBIL (PORTS.LST, P00A000AF, "00A1  RW")
;			for port PIC2DATA (0x00A1).
;
;			RBIL (PORTS.LST, K-P0060006F, Table P0401)
;			for keyboard commands.
;
CONST_S2SEG:			equ 0x0000		; stage2 memory segment.
CONST_S2OFF:			equ 0x0500		; stage2 memory offset.
CONST_STACKOFF:			equ 0xFFFF		; Stack memory offset.

CONST_BIOS_IVT:			equ 0x00000400	; BIOS IVT descriptor address.

CONST_MAX_PORTSECONDS:	equ 10			; Max seconds for PORT_WAIT.

CONST_PORT_KBDDATA:		equ 0x0060		; Ports on "See".
CONST_PORT_KBDSTATUS:	equ 0x0064
CONST_PORT_PIC1DATA:	equ 0x0021
CONST_PORT_PIC2DATA:	equ 0x00A1

CONST_CMD_KBDOFF:		equ 0xAD		; Keyboard cmds on "See".
CONST_CMD_KBDREAD:		equ 0xD0
CONST_CMD_KBDWRITE:		equ 0xD1
CONST_CMD_KBDON:		equ 0xAE

CONST_CODE16:			equ 0x0008		; GDT segments.
CONST_DATA16:			equ 0x0010
CONST_CODE32:			equ 0x0018
CONST_DATA32:			equ 0x0020
CONST_STACK:			equ 0x0028

;	------------- NASM DIRECTIVES -------------
;
	global	PROGRAM16					; Exports for 16-bit symbols.
	global	HALT32						; Exports for 32-bit symbols.
	extern	main						; Imports from C.
	extern	vga_puts
	extern	vga_clear
	extern	LD_BSS						; Imports from linker.
	extern	LD_END

;	----------- MODE SWITCHING CODE -----------
;

;	Macro:	Switch to protected mode.
;
;	See:	INTEL64IA32 (p. 3514, V3, 12.9.1)
;			for protected mode switching.
;
%macro		swp 0
	bits	16							; Instructions below are 16-bit.

	push	ax							; Save registers.
	cli									; Disable interrupts.
	lgdt	[GDT.DESCRIPTOR]			; Load the GDT.

	mov		eax, cr0					; Unset PE flag on 'cr0'.
	or		al, 0x01
	mov		cr0, eax				
										; Jump to PMODE32 linear address.
	jmp		CONST_CODE32:.PMODE32
.PMODE32:
	bits	32							; Instructions below are 32-bit.

	mov		ax, CONST_DATA32			; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	mov		ax, 0x0000
	mov		fs, ax
	mov		gs, ax

	; TODO, DEBUG:	Stack segment is unused right now.
	;				May use it on future releases if I
	;				figure it out.

	lidt	[IDT.DESCRIPTOR]			; Load the IDT.
	pop		ax							; Restore registers.

	sti									; Re-enable interrupts.
%endmacro

;	Macro:	switch to real-address mode.
;
;			INTEL64IA32 (p. 3515, V3, 12.9.2)
;			for real-address mode rollback.
;
%macro		swr 0
	bits	32							; Instructions below are 32-bit.

	push	ax							; Save registers.
	cli									; Disable interrupts.
										; Jump to protected 16-bit seg.

	jmp		CONST_CODE16:.PMODE16
.PMODE16:
	bits	16							; Instructions below are 16-bit.

	mov		ax, CONST_DATA16			; Update segments.
	mov		ss, ax
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax

	lidt	[CONST_BIOS_IVT]			; Load BIOS IVT, placed on 0x400.

	mov		eax, cr0					; Unset PE flag in CR0
	and		al, 0xFE
	mov		cr0, eax

	jmp		CONST_S2SEG:.RMODE
.RMODE:
	mov		ax, CONST_S2SEG				; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	mov		fs, ax
	mov		gs, ax

	pop		ax							; Restore registers.

	sti									; Re-enable interrupts.
%endmacro

;	---------- 16-BIT CODE (ENTRY) ------------
;
	bits	16
	section	.entry

;	- - - - - - 16-bit code macros  - - - - - -
;
;	See:	NASM301 (p. 69, 5.5)
;

;	Macro:	Call PORT_WAIT with pre-defined values.
;
%macro		portwd 0
	call	PORT_WAIT					; Wait for response.
	jc		ERR.PORTWAITOUT				; Timeout? Write error message.
%endmacro

;	Macro:	Call 'portwd' defining mask and expected result.
;
;	Input:	%1:	Mask to apply.
;			%2: Expected result
;			(1 for "applies", 0 for "doesn't").
;
%macro		portw 2
	mov		cx, %1						; Set mask.
	mov		si, %2						; Set expected result.
	portwd
%endmacro

;	Macro:	convert linear address to real address
;			and save result on 'es:si'.
;
;	Input:	%1:	Linear memory address.
;
%macro		ltor 1
	mov		si, %1
	shr		si, 8
	shl		si, 4
	mov		es, si

	mov		si, %1
	and		si, 0x00FF
%endmacro

;	- - - - - -  16-bit entry code  - - - - - -
;
;	*pic:	before switching to protected mode,
;			the 8259 PIC is disabled in favor
;			of the local APIC. This prevents
;			misinterpretation of interrupts
;			later in protected mode.
;
;	See:	INTEL64IA32 (p. 3555, V3, 13.4)
;			for local APIC documentation.
;
;			https://wiki.osdev.org/8259_PIC
;			for information about 8259 PIC.
;
PROGRAM16:
	mov		sp, CONST_STACKOFF			; Set stack address.
	mov		bp, sp

	mov		al, 0xFF					; Disable 8259 PIC (*pic).
	out		CONST_PORT_PIC1DATA, al
	out		CONST_PORT_PIC2DATA, al

	cli									; Disable interrupts.
	mov		bx, CONST_MAX_PORTSECONDS	; Set max timeout for port wait.
	mov		dx, CONST_PORT_KBDSTATUS	; Set port to KBDSTATUS.

	portw	0x02, 0						; Wait until KBDSTATUS bit 1 is unset.
	mov		al, CONST_CMD_KBDOFF		; Disable keyboard.
	out		CONST_PORT_KBDSTATUS, al

	portwd								; Wait again.
	mov		al, CONST_CMD_KBDREAD		; Read keyboard state to KBDDATA.
	out		CONST_PORT_KBDSTATUS, al

	portw	0x01, 1						; Wait until KBDSTATUS bit 0 is set.
	in		al, CONST_PORT_KBDDATA		; Save keyboard state to stack.
	push	eax

	portw	0x02, 0						; Wait until KBDSTATUS bit 1 is unset.
	mov		al, CONST_CMD_KBDWRITE		; Open KBDDATA to overwrite state.
	out		CONST_PORT_KBDSTATUS, al

	portwd								; Wait again.
	pop		eax							; Recover keyboard state.
	or		al, 0x02					; Unset bit 1 (A20 line).
	out		CONST_PORT_KBDDATA, al		; Write new state to KBDDATA.

	portwd								; Wait again.
	mov		al, CONST_CMD_KBDON			; Enable keyboard.
	out		CONST_PORT_KBDSTATUS, al

	portwd								; Wait again.
	swp									; Switch to protected mode.
	jmp		PROGRAM32					; Jump to 32-bit entry.
	
	bits	16							; Instructions below are 16-bit.

;	- - - - - - - - Halt system - - - - - - - -
;
HALT16:
	hlt									; Halt system.
	jmp		HALT16						; Revived? Halt again.

;	- - - PRINT 0-terminated ASCII string - - -
;
;	Input:	es:si: Pointer to string.
;
;	See:	RBIL (INTERRUP.LST, V-100E)
;			for INT 10h/AH=0Eh reference.
;
PRINT:
	push	ax							; Save registers.
	push	bx
	push	si

	mov		ah, 0x0E					; Set interrupt ID.
	mov		bh, 0						; Write to page zero.
.REPEAT:
	lodsb								; al = *(ds:si++)
	cmp		al, 0						; '\0'? Stop printing.
	jz		.RETURN

	int		0x10						; Teletype output.

	jmp	.REPEAT							; Read next byte.
.RETURN:
	pop		si							; Restore registers.
	pop		bx
	pop		ax

	ret									; Far return to caller.

;	- - - - -  Sleep for one second - - - - - -
;
;	See:	RBIL (INTERRUP.LST, B-1586)
;			for INT 15h/AH=86h reference.
SLEEP:
	push	ax							; Save registers.
	push	dx
	push	cx

	mov		ah, 0x86					; Set interrupt ID.
	mov		cx, 0x000F					; Set nanoseconds to 0x000F:0x4240.
	mov		dx, 0x4240
	int		0x15						; Wait for 'cx:dx' ns (1 second).

	jc		ERR.SLEEPINT				; CF set? Error.

	pop		cx							; Restore registers.
	pop		dx
	pop		ax
	ret

;	- - - PORT I/O - Check port response  - - -
;
;	Reads data from a port and applies a mask
;	to it. Then, one of these three scenarios
;	will take place:
;
;	-	If 'si' is 0 and the mask doesn't
;		apply, the method returns.
;	-	If 'si' is 1 and the mask applies,
;		the method returns.
;	-	In any other case, it keeps looping
;		until the expected result is received
;		or 'bx' seconds pass.
;
;	Input:	bx: Max seconds to wait.
;			cx: Mask to apply.
;			dx:	Port number.
;			si: Expected result.
;				0 - The mask should NOT apply.
;				1 - The mask should apply.
;
;	Output:	ax: Last response received.
;			di: Seconds passed.
;			CF: Set on timeout.
;
;
PORT_WAIT:
	cmp		si, 1						; Make sure that 'si' is 0 or 1.
	jg		.ERROR

	xor		di, di						; Set second counter to zero.
.REPEAT:
	in		ax, dx						; Read data from port.

	test	ax, cx						; Apply the mask.
	jz		.EVALZ						; Compare with expected result.
	jnz		.EVALNZ
.EVALZ:
	cmp		si, 0						; Shouldn't apply and doesn't? Return.
	je		.RETURN
	jmp		.SLEEP						; Not the case? Sleep and repeat.
.EVALNZ:
	cmp		si, 1						; Should apply and applies? Return.
	je		.RETURN
.SLEEP:
	cmp		di, bx
	je		.ERROR						; Max seconds passed? Timeout. Stop.

	call	SLEEP						; Wait for one second.

	inc		di							; Increment second counter.
	jmp		.REPEAT						; Try again.
.ERROR:
	stc
.RETURN:
	ret

;	- - - - - - - Error handlers  - - - - - - -
;
ERR:
	call	PRINT						; Print message.
	mov		si, STR_ERRSUFFIX			; Print suffix
	call	PRINT
	jmp		HALT16						; Halt the system.
.PREFIX:
	mov		si, STR_ERRPREFIX
	call	PRINT
	ret
.PORTWAITOUT:
	call	.PREFIX
	mov		si, STR_ERRPORTWAITOUT
	jmp		ERR
.SLEEPINT:
	call	.PREFIX
	mov		si, STR_ERRSLEEPINT
	jmp		ERR
.RETURN:
	call	.PREFIX
	mov		si, STR_ERRRETURN
	jmp		ERR

;	--------------- 32 BIT CODE ---------------
;
	bits	32

;	- - - - - -  32-bit code entry  - - - - - -
;
PROGRAM32:
	mov		edi, LD_BSS					; Save pointer to BSS on 'edi'.
	mov		ecx, LD_END					; Save BSS size on 'ecx'.
	sub		ecx, edi
	mov		al, 0x00					; Set 0 as byte to copy.
	cld									; Set direction to "forward" (0).
	rep		stosb						; Overwrite BSS with zeroes.

	call	main						; Jump to C code. Shouldn't return.
	swr									; Returned? Switch to real mode.
	jmp		CONST_S2SEG:ERR.RETURN		; Jump to ERR.RETURN.

	bits	32							; Instructions below are 32-bit.

HALT32:
	swr									; Switch to real-address mode.
	jmp		CONST_S2SEG:HALT16			; Halt the system.
	bits	32							; Instructions below are 32-bit.

EXCEPTION:
	call	vga_clear					; Clear screen.
	push	STR_EXCPREFIX
	call	vga_puts					; Output exception prefix.
	add		esp, 4						; Discard message.
	ret
.DE:
	call	EXCEPTION
	push	STR_IDTDE
	jmp		.SUFFIX
.DB:
	call	EXCEPTION
	push	STR_IDTDB
	jmp		.SUFFIX
.02:
	call	EXCEPTION
	push	STR_IDT02
	jmp		.SUFFIX
.BP:
	call	EXCEPTION
	push	STR_IDTBP
	jmp		.SUFFIX
.OF:
	call	EXCEPTION
	push	STR_IDTOF
	jmp		.SUFFIX
.BR:
	call	EXCEPTION
	push	STR_IDTBR
	jmp		.SUFFIX
.UD:
	call	EXCEPTION
	push	STR_IDTUD
	jmp		.SUFFIX
.NM:
	call	EXCEPTION
	push	STR_IDTNM
	jmp		.SUFFIX
.DF:
	call	EXCEPTION
	push	STR_IDTDF
	jmp		.SUFFIX
.09:
	call	EXCEPTION
	push	STR_IDT09
	jmp		.SUFFIX
.TS:
	call	EXCEPTION
	push	STR_IDTTS
	jmp		.SUFFIX
.NP:
	call	EXCEPTION
	push	STR_IDTNP
	jmp		.SUFFIX
.SS:
	call	EXCEPTION
	push	STR_IDTSS
	jmp		.SUFFIX
.GP:
	call	EXCEPTION
	push	STR_IDTGP
	jmp		.SUFFIX
.PF:
	call	EXCEPTION
	push	STR_IDTPF
	jmp		.SUFFIX
.MF:
	call	EXCEPTION
	push	STR_IDTMF
	jmp		.SUFFIX
.AC:
	call	EXCEPTION
	push	STR_IDTAC
	jmp		.SUFFIX
.MC:
	call	EXCEPTION
	push	STR_IDTMC
	jmp		.SUFFIX
.XM:
	call	EXCEPTION
	push	STR_IDTXM
	jmp		.SUFFIX
.VE:
	call	EXCEPTION
	push	STR_IDTVE
	jmp		.SUFFIX
.CP:
	call	EXCEPTION
	push	STR_IDTCP
	jmp		.SUFFIX
.SUFFIX:
	call	vga_puts					; Output exception mnemonic.
	add		esp, 4						; Discard message.

	push	STR_ERRSUFFIX				; Output exception suffix.
	call	vga_puts
	add		esp, 4						; Discard message.

	jmp		HALT32						; Halt the system.

;	------------- RODATA SECTION --------------
;
	section	.rodata

;	- - - - - - - - Data macros - - - - - - - -
;

;	Macro:	define an interrupt gate for the IDT.
;
;	Input:	%1:	handler address.
;			%2: interrupt/trap gate.
;
%macro	idti 1
	dw		%1							; Handler offset (bits 16-0).
	dw		CONST_CODE32				; Execution segment.
	db		0x00						; Always zero.
	db		10001110b					; Flags: (P, DPL:00, D)
	dw		0x0000						; Handler offset (bits 32-16).
%endmacro

;	Macro:	define a trap gate for the IDT.
;
;	Input:	%1:	handler address.
;			%2: interrupt/trap gate.
;
%macro	idtt 1
	dw		%1							; Handler offset (bits 16-0).
	dw		CONST_CODE32				; Execution segment.
	db		0x00						; Always zero.
	db		10001111b					; Flags: (P, DPL:00, D)
	dw		0x0000						; Handler offset (bits 32-16).
%endmacro

;	- - - - - - - - - Strings - - - - - - - - -
;
STR_ERRPREFIX:
	db		"Error: ", 0
STR_ERRPORTWAITOUT:
	db		"keyboard port response timed out", 0
STR_ERRSLEEPINT:
	db		"unable to wait for keyboard port output", 0
STR_ERRRETURN:
	db		"system returned unexpectedly to bootloader", 0
STR_ERRSUFFIX:
	db		'.', 0x0D, 0x0A, "Please, reboot your PC.", 0x0D, 0x0A, 0
STR_EXCPREFIX:
	db		"Error: the processor issued an exception on system boot - ", 0

;	- - - - - Interrupt display codes - - - - -
;
STR_IDTDE:
	db		"#DE", 0
STR_IDTDB:
	db		"#DB", 0
STR_IDT02:
	db		"#02", 0
STR_IDTBP:
	db		"#BP", 0
STR_IDTOF:
	db		"#OF", 0
STR_IDTBR:
	db		"#BR", 0
STR_IDTUD:
	db		"#UD", 0
STR_IDTNM:
	db		"#NM", 0
STR_IDTDF:
	db		"#DF", 0
STR_IDT09:
	db		"#09", 0
STR_IDTTS:
	db		"#TS", 0
STR_IDTNP:
	db		"#NP", 0
STR_IDTSS:
	db		"#SS", 0
STR_IDTGP:
	db		"#GP", 0
STR_IDTPF:
	db		"#PF", 0
STR_IDTMF:
	db		"#MF", 0
STR_IDTAC:
	db		"#AC", 0
STR_IDTMC:
	db		"#MC", 0
STR_IDTXM:
	db		"#XM", 0
STR_IDTVE:
	db		"#VE", 0
STR_IDTCP:
	db		"#CP", 0

IDT:
	idti	EXCEPTION.DE	; 0x00: #DE (Divide Error).
	idtt	EXCEPTION.DB	; 0x01: #DB (Debug Exception).
	idti	EXCEPTION.02	; 0x02: --- (Non-Maskable interrupt).
	idtt	EXCEPTION.BP	; 0x03: #BP (Breakpoint).
	idtt	EXCEPTION.OF	; 0x04: #OF (Overflow).
	idti	EXCEPTION.BR	; 0x05: #BR (BOUND Range Exceeded).
	idti	EXCEPTION.UD	; 0x06: #UD (Undefined Opcode).
	idti	EXCEPTION.NM	; 0x07: #NM (Device Not Available).
	idti	EXCEPTION.DF	; 0x08: #DF (Double Fault).
	idti	EXCEPTION.09	; 0x09: --- (Coprocessor Segment Overrun).
	idti	EXCEPTION.TS	; 0x0A: #TS (Invalid TSS).
	idti	EXCEPTION.NP	; 0x0B: #NP (Segment Not Present).
	idti	EXCEPTION.SS	; 0x0C: #SS (Stack Segment Fault).
	idti	EXCEPTION.GP	; 0x0D: #GP (General Protection).
	idti	EXCEPTION.PF	; 0x0E: #PF (Page Fault).
	dq		0				; 0x0F: --- (Intel Reserved).
	idti	EXCEPTION.MF	; 0x10: #MF (Floating-Point Error).
	idti	EXCEPTION.AC	; 0x11: #AC (Alignment Check).
	idti	EXCEPTION.MC	; 0x12: #MC (Machine Check).
	idti	EXCEPTION.XM	; 0x13: #XM (SIMD Floating-Point Exception).
	idti	EXCEPTION.VE	; 0x14: #VE (Virtualization Exception).
	idti	EXCEPTION.CP	; 0x15: #CP (Control Protection Exception).

	times 10	dq 0		; 0x16 - 0x1F: Intel reserved.
	times 0xE0	dq 0		; 0x20 - 0x255: User Defined.
.DESCRIPTOR:
	dw	IDT.DESCRIPTOR - IDT - 1
	dd	IDT

;	- - - - - Global Descriptor Table - - - - -
;
;	See:	INTEL64IA32 (p. 3230, V3, 3.4.5)
;			for segment descriptor structure.
;
;			INTEL64IA32 (p. 3235, V3, 3.5.1)
;			for GDT and LDT descriptors.
;
;			https://wiki.osdev.org/Memory_Map_(x86)
;			for available memory regions.
;
GDT:
	dq		0				; First segment is always null.
							; --------- SEGMENT 1 (16bit CODE) ----------
	dw		0xFFFF			; Limit.
	dw		0x0000			; Base bits 15-0.
	db		0x00			; Base bits 23-16.
	db		10011011b		; Flags (P, DPL:00, S, T, c, R, A).
	db		00000000b		; Flags (g, d, l, avl) and limit bits 19-16.
	db		0x00			; Base bits 31-24.
							; --------- SEGMENT 2 (16bit DATA) ----------
	dw		0xFFFF			; Limit.
	dw		0x0000			; Base bits 15-0.
	db		0x00			; Base bits 23-16.
	db		10010011b		; Flags (P, DPL:00, S, t, e, W, A).
	db		00000000b		; Flags (g, b, l, avl) and limit bits 19-16.
	db		0x00			; Base bits 31-24.
							; --------- SEGMENT 3 (32bit CODE) ----------
	dw		0xFFFF			; Limit.
	dw		0x0000			; Base bits 15-0.
	db		0x00			; Base bits 23-16.
	db		10011011b		; Flags (P, DPL:00, S, T, c, R, A).
	db		11001111b		; Flags (G, D, l, avl) and limit bits 19-16.
	db		0x00			; Base bits 31-24.
							; --------- SEGMENT 4 (32bit DATA) ----------
	dw		0xFFFF			; Limit.
	dw		0x0000			; Base bits 15-0.
	db		0x00			; Base bits 23-16.
	db		10010011b		; Flags (P, DPL:00, S, t, e, W, A).
	db		11001111b		; Flags (G, B, l, avl) and limit bits 19-16.
	db		0x00			; Base bits 31-24.
							; ----------- SEGMENT 5 (STACK) -------------
	dw		0x7E00			; Limit.
	dw		CONST_STACKOFF	; Base bits 15-0.
	db		0x00			; Base bits 23-16.
	db		10010111b		; Flags (P, DPL:00, S, t, E, W, A).
	db		01000000b		; Flags (g, B, l, avl) and limit bits 19-16.
	db		0x00			; Base bits 31-24.
.DESCRIPTOR:
	dw		GDT.DESCRIPTOR - GDT - 1
	dd		GDT