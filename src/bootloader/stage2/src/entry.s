;	---------------- CONSTANTS ----------------
;
;	See:	RBIL (PORTS.LST, K-P0060006F, "0060  4R-")
;			for port KBDDATA (0x0060).
;
;			RBIL (PORTS.LST, K-P0060006F, "0064  RW")
;			for port KBDSTATUS (0x0064).
;
;			RBIL (PORTS.LST, K-P0060006F, Table P0401)
;			for keyboard commands.
;
CONST_S1SEG:			equ 0			; stage1 memory segment.
CONST_S2SEG:			equ 0x50		; stage2 memory segment.
CONST_S2OFF:			equ 0x500		; stage2 memory offset.

CONST_BPB_RESERVEDSECS:	equ 0x7C0E		; Pointers to stage1 symbols.
CONST_EBPB_DRIVEID:		equ 0x7C24

CONST_MAX_PORTSECONDS:	equ 10			; Max seconds for PORT_WAIT.

CONST_PORT_KBDDATA:		equ 0x0060		; Ports on "See".
CONST_PORT_KBDSTATUS:	equ 0x0064

CONST_CMD_KBDOFF:		equ 0xAD		; Keyboard cmds on "See".
CONST_CMD_KBDREAD:		equ 0xD0
CONST_CMD_KBDWRITE:		equ 0xD1
CONST_CMD_KBDON:		equ 0xAE

CONST_CODE16:			equ 0x0008		; GDT segments.
CONST_DATA16:			equ 0x0010
CONST_CODE32:			equ 0x0018
CONST_DATA32:			equ 0x0020	

;	------------- NASM DIRECTIVES -------------
;
	extern	main						; Import C functions.
	extern	LD_BSS						; Import linker symbols.
	extern	LD_END

;	----------- MODE SWITCHING CODE -----------
;
;	See:	INTEL64IA32 (p. 3514, 12.9.1)
;			for protected mode switching.
;
;			INTEL64IA32 (p. 3515, V3, 12.9.2)
;			for real-address mode rollback.
;

;	Macro:	Switch to protected mode and call/jump to symbol.
;
;	Input:	%1: destination symbol.
;			%2:	0 to jump, greater to call.
;
%macro		swp 2
	bits	16							; Instructions below are 16-bit.

	push	ax							; Save registers.
	cli									; Disable interrupts.
	lgdt	[GDT_DESCRIPTOR] 			; Load Global Descriptor Table.

	mov		eax, cr0					; Unset PE flag on 'cr0'.
	or		al, 0x01
	mov		cr0, eax				
										; Jump to PMODE32 linear address.
	jmp		CONST_CODE32:.PMODE32 + CONST_S2SEG * 0x10
.PMODE32:
	bits	32							; Instructions below are 32-bit.

	mov		ax, CONST_DATA32			; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	mov		ax, 0x0000
	mov		fs, ax
	mov		gs, ax

	sti									; Re-enable interrupts.

	mov		ax, %2						; Check for CALL or JMP.
	cmp		ax, 0
	jg		.PMODE32_CALL
	jmp		%1							; Zero? Jump to symbol.
.PMODE32_CALL:
	pop		ax							; Restore registers.
	call	%1							; Greater? Call symbol.
%endmacro

;	Macro:	switch to protected mode from 16-bit code section.
;
;	The macro includes a 'bits 16' directive at its end
;	that prevents the code below from compiling as 32-bit.
;
;	Input:	Same as 'swp'.
;
%macro		swpb 2
	swp		%1, %2						; Real-jump or call.
	bits	16							; Instructions below are 16-bit.
%endmacro

;	Macro:	switch to real-address mode and call/jump to symbol.
;
;	Input:	%1:	destination segment.
;			%2: destination offset.
;			%3:	0 to jump, greater to call.
;
%macro		swr 3
	bits	32							; Instructions below are 32-bit.
	push	eax							; Save registers.
	cli									; Disable interrupts.
										; Jump to protected 16-bit seg.
	jmp		CONST_CODE16:.PMODE16 + CONST_S2SEG * 0x10
.PMODE16:
	bits	16							; Instructions below are 16-bit.

	mov		ax, CONST_DATA16			; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	mov		ax, 0x0000
	mov		fs, ax
	mov		gs, ax

	mov		eax, cr0					; Unset PE flag in CR0
	and		al, 0xFE
	mov		cr0, eax

	jmp		CONST_S2SEG:.RMODE
.RMODE:
	mov		ax, CONST_S2SEG				; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ax, 0x0000
	mov		ss, ax
	mov		fs, ax
	mov		gs, ax

	sti									; Re-enable interrupts.

	mov		ax, %3						; Check for CALL or JMP.
	cmp		ax, 0
	jg		.RMODE_CALL

	jmp		%1:%2						; Zero? Jump to symbol.
.RMODE_CALL:
	pop		eax							; Restore registers.
	call	%1:%2						; Greater? Call symbol.
%endmacro

;	Macro:	switch to real mode from 32-bit code section.
;
;	The macro includes a 'bits 32' directive at its end
;	that prevents the code below from compiling as 16-bit.
;
;	Input:	Same as 'swr'.
;
%macro		swrb 3
	swr		%1, %2, %3					; Real-jump or call.
	bits	32							; Instructions below are 32-bit.
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
	jc		ERR_PORTWAITOUT				; Timeout? Write error message.
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

;	Macro:	convert linear address to real-mode address
;			and save result on 'es:si'.
;
;	Input:	%1:	Linear memory address.
;
%macro		ltor 1
	mov		si, %1
	and		si, 0xFF00
	shr		si, 4
	mov		es, si

	mov		si, %1
	and		si, 0x00FF
%endmacro

;	- - - - - -  16-bit entry code  - - - - - -
;
	global	PROGRAM16					; Export PROGRAM16 to the linker.

PROGRAM16:
	mov		sp, CONST_S2OFF				; Stack from 0x0a00 downwards.

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
	swpb	PROGRAM32, 0				; Jump to PROGRAM32 in prot. mode.

;	- - - - - - - - Halt system - - - - - - - -
;
HALT:
	hlt									; Halt system.
	jmp		HALT						; Revived? Halt again.

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
PRINT_LOOP:
	lodsb								; al = *(ds:si++)
	cmp		al, 0						; '\0'? Stop printing.
	jz		PRINT_RET

	int		0x10						; Teletype output.

	jmp	PRINT_LOOP						; Read next byte.
PRINT_RET:
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

	jc		ERR_SLEEPINT				; CF set? Error.

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
	jg		PORT_WAITOUT

	xor		di, di						; Set second counter to zero.
PORT_WAITLOOP:
	in		ax, dx						; Read data from port.

	test	ax, cx						; Apply the mask.
	jz		PORT_WAITEVALZ				; Compare with expected result.
	jnz		PORT_WAITEVALNZ
PORT_WAITEVALZ:
	cmp		si, 0						; Shouldn't apply and doesn't? Return.
	je		PORT_WAITRET
	jmp		PORT_WAITKEEP				; Not the case? Keep looping.
PORT_WAITEVALNZ:
	cmp		si, 1						; Should apply and applies? Return.
	je		PORT_WAITRET
PORT_WAITKEEP:
	cmp		di, bx
	je		PORT_WAITOUT				; Max seconds passed? Timeout. Stop.

	call	SLEEP						; Wait for one second.

	inc		di							; Increment second counter.
	jmp		PORT_WAITLOOP				; Try again.
PORT_WAITOUT:
	stc
PORT_WAITRET:
	ret

;	- - - - - - - Error handlers  - - - - - - -
;
ERR:
	call	PRINT						; Print message.
	mov		si, STR_ERRSUFFIX			; Print suffix
	call	PRINT
	jmp		HALT						; Halt the system.
ERR_PORTWAITOUT:
	mov		si, STR_ERRPORTWAITOUT
	jmp		ERR
ERR_SLEEPINT:
	mov		si, STR_ERRSLEEPINT
	jmp		ERR
ERR_RETURN:
	mov		si, STR_ERRRETURN
	jmp		ERR

;	--------------- 32 BIT CODE ---------------
;
	bits	32

;	- - - - - -  32-bit code entry  - - - - - -
;
PROGRAM32:
	add		sp, CONST_S2SEG * 0x10		; Update stack to linear address.

	mov		edi, LD_BSS					; Save pointer to BSS on 'edi'.
	mov		ecx, LD_END					; Save BSS size on 'ecx'.
	sub		ecx, edi
	mov		al, 0x00					; Set 0 as byte to copy.
	cld									; Set direction to "forward" (0).
	rep		stosb						; Overwrite BSS with zeroes.

	call	main						; Jump to C code.
	swrb	CONST_S2SEG, ERR_RETURN, 0	; Back? Real-jump to ERR_RETURN.

;	------------- RODATA SECTION --------------
;
	section	.rodata

;	- - - - - - - - - Strings - - - - - - - - -
;
STR_OK:
	db		"System booted correctly!", 0x0D, 0x0A, 0
STR_ERRPORTWAITOUT:
	db		"Error: timeout while waiting for keyboard port output.", 0x0D, 0x0A, 0
STR_ERRSLEEPINT:
	db		"Error: unable to wait for keyboard port output.", 0x0D, 0x0A, 0
STR_ERRRETURN:
	db		"Error: system code returned unexpectedly to bootloader.", 0x0D, 0x0A, 0
STR_ERRSUFFIX:
	db		"Please, reboot your PC.", 0x0D, 0x0A, 0

;	- - - - - Global Descriptor Table - - - - -
;
;	See:	INTEL64IA32 (p. 3230, 3.4.5)
;			for segment descriptor structure.
;
;			INTEL64IA32 (p. 3235, 3.5.1)
;			for GDT and LDT descriptors.
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
GDT_DESCRIPTOR:
	dw		GDT_DESCRIPTOR - GDT - 1
	dd		CONST_S2SEG * 0x10 + GDT