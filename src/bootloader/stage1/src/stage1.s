;	---------------- CONSTANTS ----------------
;
;	See:	NASM301 (p. 38, 3.2.4)
;
CONST_S1OFF:		equ 0x7C00		; stage1 memory offset.
CONST_S2SEG:		equ 0x50		; Segment to load stage2 in.
CONST_S2OFF:		equ 0x500		; Offset to load stage2 in.
CONST_ENTRYSIZE:	equ 32			; Directory entry size.

;	------------- NASM DIRECTIVES -------------
;
;	See:	NASM301 (p. 101, 8)
;
	bits	16						; 16-bit code.
	org		CONST_S1OFF				; Organize from offset.

;	--------------- BOOT SECTOR ---------------
;
;	IBM-compatible x86 Boot Sector.
;
;	See:	FAT32 (p. 9).
;			NASM301 (p. 36, 3.2.1)
;
BOOT_JMP:
	jmp		short PROGRAM			; 0x00: First jump (DOS 2.0).
	nop
BOOT_OEM:
	db		"MSWIN4.1"				; 0x03: OEM name (DOS 2.0).

;	---------- BIOS PARAMETER BLOCK -----------
;
;	DOS 3.31 BIOS Parameter Block.
;
;	See:	FAT32 01 (p. 11).
;
BPB_BYTESPERSEC:
	dw		512						; 0x0B: Bytes per sector (DOS 2.0).
BPB_SECSPERCLUSTER:
	db		1						; 0x0D: Sectors per cluster (DOS 2.0).
BPB_RESERVEDSECS:
	dw		1						; 0x0E: Sectors before FAT (DOS 2.0).
BPB_FATCOUNT:
	db		2						; 0x10: Number of FATs (DOS 2.0).
BPB_ROOTENTRIES:
	dw		240						; 0x11: Max rootdir entries (DOS 2.0).
BPB_TOTALSECS16:
	dw		2880					; 0x13: Sectors if < 65536 (DOS 2.0).
BPB_MEDIA:
	db		0xF0					; 0x15: 'F0' for floppy (DOS 2.0).
BPB_SECSPERFAT:
	dw		9						; 0x16: Sectors per FAT (DOS 2.0).
BPB_SECSPERTRACK:
	dw		18						; 0x18: Sectors per track (DOS 3.0).
BPB_HEADS:
	dw		2						; 0x1A: Heads of disk (DOS 3.31).
BPB_HIDDENSECS:
	dd		0						; 0x1C: Hidden sectors (DOS 3.31).
BPB_TOTALSECS32:
	dd		0						; 0x20: Sectors if >= 65536 (DOS 3.31).

;	------ EXTENDED BIOS PARAMETER BLOCK ------
;
;	DOS 4.0 Extended BIOS Parameter Block.
;
;	See:	FAT32 01 (p. 13, for FAT12).
;
EBPB_DRIVEID:
	db		0						; 0x24: Zero for 1st media (DOS 4.0).
EBPB_RESERVED:
	db		0						; 0x25: Reserved byte (DOS 4.0).
EBPB_BOOTSIG:
	db		0x29					; 0x26: 0x29 for DOS 4.0 (DOS 4.0).
EBPB_VOLUMEID:
	db		"VCS7"					; 0x27: Serial number (DOS 4.0).
EBPB_VOLUMELABEL:
	db		"BLAZE    OS"			; 0x2B: Partition label (DOS 4.0).
EBPB_FILESYSTEM:
	db		"FAT12      "			; 0x36: File system type (DOS 4.0).

;	--------------- BLAZE DATA ----------------
;
;	See:	NASM301 (p. 37, 3.2.2).
;
DAT_ROOTLBA:
	resw	1						; 0x41: Root directory LBA.
DAT_ROOTSIZE:
	resw	1						; 0x43: Root directory sectors.

;	------------ EXPORTED SYMBOLS -------------
;
;	Redirections to symbols that can be
;	called from other programs.
;
EXP_DISK_LBATOCHS:
	call	DISK_LBATOCHS			; 0x45: Export DISK_LBATOCHS.
	retf
EXP_DISK_READ:
	call	DISK_READ				; 0x49: Export DISK_READ.
	retf
EXP_FAT_FATNEXT:
	call	FAT_FATNEXT				; 0x4D: Export FAT_FATNEXT.
	retf
EXP_FAT_CLUSTERTOLBA:
	call	FAT_CLUSTERTOLBA		; 0x51: Export FAT_CLUSTERTOLBA.
	retf
EXP_FAT_FILEREAD:
	call	FAT_FILEREAD			; 0x55: Export FAT_FILEREAD.
	retf

;	----------------- STRINGS -----------------
;
;	See:	NASM301 (p. 40, 3.4.2).
;
STR_STAGE2:
	db		"STAGE2  BIN"			; Stage 2 file name.

;	-------------- PROGRAM CODE ---------------
;
;	See:	RBIL (INTERRUP.LST, B-1308, INT 13h/AH=08h)
;
PROGRAM:
	xor		ax, ax					; Clear all segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	
	mov		sp, CONST_S1OFF			; Stack downwards from stage1.

	jmp		0x0000:PROGRAM_MAIN		; Set code segment to zero.
PROGRAM_MAIN:
	push	es						; Save segments.

	mov		ah, 0x08				; Set interrupt ID.
	mov		dl, [EBPB_DRIVEID]		; Select boot drive.
	xor		di, di					; Zero 'di' to avoid BIOS bugs.
	int		0x13					; Get drive parameters.

	pop		es						; Restore segments.

	jc		ERR_DRIVEACCESS			; Carry set? Error.

	cmp		dl, [EBPB_DRIVEID]
	jl		ERR_DRIVEID				; Nº of drives < Drive ID? Error.

	mov		dl, dh					; Retrieve max head from 'dh'.
	xor		dh, dh					; Cast to word length.
	mov		[BPB_HEADS], dx			; Save on BPB.
	inc		word [BPB_HEADS]		; +1 = Head count.

	mov		dl, cl					; Retrieve max sector from 'cl'
	and		dl, 0x3F				; Ignore first 2 bits.
	xor		dh, dh					; Cast to word length.
	mov		[BPB_SECSPERTRACK], dx	; Save on BPB.

	mov		ax, [BPB_SECSPERFAT]	; Get root directory LBA.
	mul		[BPB_FATCOUNT]			; X = secsperfat * fats.
	add		ax, [BPB_RESERVEDSECS]	; ax = X + reservedsecs.
	mov		[DAT_ROOTLBA], ax		; Save result.

	mov		bx, [BPB_BYTESPERSEC]	; Get root directory size
	dec		bx						; X = bytespersec - 1.
	mov		ax, [BPB_ROOTENTRIES]
	mov		dx, CONST_ENTRYSIZE
	mul		dx						; Y = entries * entrysize.
	add		ax, bx
	div		word [BPB_BYTESPERSEC]	; ax = (X + Y) / bytespersec.
	mov		[DAT_ROOTSIZE], ax		; Save result.

	mov		ax, [DAT_ROOTLBA]		; Read root directory.
	mov		bl, [DAT_ROOTSIZE]
	mov		dl, [EBPB_DRIVEID]
	mov		si, BUFFER
	call	DISK_READ
PROGRAM_SEARCH:
	xor		bx, bx					; Set entry counter to zero.
PROGRAM_SEARCHLOOP:
	mov		di, STR_STAGE2			; Point 'di' to stage2 filename.
	mov		cx, 11					; Set counter to name length.
	
	push	si						; Compare filename with stage2's.
	repe	cmpsb					; memcmp(es:di, ds:si, cx)
	pop		si

	je		PROGRAM_READ			; Same? Found. Stop searching.

	add		si, CONST_ENTRYSIZE		; Point to next entry.
	inc		bx						; Increment entry counter.

	cmp		bx, [BPB_ROOTENTRIES]
	je		ERR_NOSTAGE2			; Nº entry == Entries? Error.

	jmp		PROGRAM_SEARCHLOOP		; Read next entry.
PROGRAM_READ:
	push	[si+0x1A]				; Save stage2 cluster.

	mov		ax, [BPB_RESERVEDSECS]	; Read FAT.
	mov		bl, [BPB_SECSPERFAT]
	mov		dl, [EBPB_DRIVEID]
	mov		si, BUFFER
	call	DISK_READ

	mov		ax, es					; Save FAT seg:off en 'ds:di'.
	mov		ds, ax
	mov		di, si
	mov		ax, CONST_S2SEG			; Save stage2 seg:off on 'es:si'.
	mov		es, ax
	mov		si, CONST_S2OFF
	pop		ax						; Restore file cluster on 'ax'.
	call	FAT_FILEREAD			; Read stage2.
	
PROGRAM_JUMP:
	mov		ax, CONST_S2SEG			; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax

	jmp		CONST_S2SEG:CONST_S2OFF	; Jump to stage2.
	jmp		HALT					; Didn't jump? Halt system.

;	--------------- HALT SYSTEM ---------------
;
;	See:	INTEL64IA32 (p. 1139, 3-439)
;
HALT:
	hlt
	jmp		HALT

;	------- DISK routines - LBA to CHS --------
;
;	Input:	ax: LBA to convert.
;
;	Output:	ch: Cylinder bits 7-0.
;			cl: [5-0]: sector,
;				[7-6]: cylinder bits 9-8.
;			dh: Head.
;
DISK_LBATOCHS:
	push	ax						; Save registers.
	push	dx
	push	ds

	xor		dx, dx					; Make sure data segment is zero.
	mov		ds, dx

	xor		dx, dx					; Set remainder to zero.
	div		word [BPB_SECSPERTRACK]	; Divide LBA and SECSPERTRACK.
									; ax = lba / sec@track.
									; dx = lba % sec@track.

	mov		cl, dl					; Save remainder in 'cl'.
	inc		cl						; cl = lba % sec@track + 1 (S).

	xor		dx, dx					; Set remainder to zero.
	div		word [BPB_HEADS]		; Save C, H in 'ax', 'dx'.
									; ax = lba / sec@track / heads (C).
									; dx = lba / sec@track % heads (H).

	mov		dh, dl					; Save head in 'dh'.

	mov		ch, al					; Save cyl bits 7-0 in 'ch'.
	shl		ah, 6					; Isolate bits 1-0 of 'ah'.
	or		cl, ah					; Save those 2 bits in 'cl'.

	pop		ds						; Restore registers.
	pop		ax
	mov		dl, al
	pop		ax

	ret								; Return to caller.

;	------ DISK routines - Read sectors -------
;
;	Input:	ax: LBA.
;			bl: Sectors to read.
;			dl: Drive ID.
;			es:si: Buffer to write to.
;
;	See:	RBIL (INTERRUP.LST, B-1300, INT 13h/AH=00h)
;			RBIL (INTERRUP.LST, B-1302, INT 13h/AH=02h)
;
DISK_READ:
	pusha							; Save registers.

	call	DISK_LBATOCHS			; Set CHS values.

	mov		ah, 0x02				; Set interrupt ID.
	mov		al, bl					; Read 'bl' sectors.
	mov		bx, si					; Write to buffer.

	xor		di, di					; Set counter to zero.
DISK_READLOOP:
	cmp		di, 3
	je		ERR_READFAIL			; 3rd attempt finished? Error.

	inc		di						; Increment counter.
	int		0x13					; Read sector(s) into memory.

	jnc		DISK_READRET			; No carry set? Success. Stop reading.

	pusha							; Save registers.
	mov		ah, 0x00				; Set interrupt ID.
	int		0x13					; Reset disk system.

	jc		ERR_RESET				; Carry set? Reset error.
	popa							; Restore registers.

	jmp		DISK_READLOOP
DISK_READRET:
	popa							; Restore registers.

	ret								; Return to caller

;	-------- FAT - Get value from FAT ---------
;
;	Input:	ax: FAT index (cluster).
;			ds:di: Buffer with FAT loaded.
;
;	Output:	ax: Value at that FAT index.
;
FAT_FATNEXT:
	push	bx						; Save registers.
	push	cx
	push	dx
	push	di

	mov		bx, 2					; Save 2 on 'bx'.
	xor		dx, dx					; Clear remainder.
	div		bx						; Divide 'ax' by 2.
	mov		cx, dx					; Save remainder on 'cx'.
	inc		bx						; Save 3 on 'bx'.
	mul		bx						; Multiply 'bx' by 3.
									; ax = byte to load.
									; cx = parity (0 for even).

	add		di, ax					; Point 'di' to desired index.

	cmp		cx, 0
	jz		FAT_FATNEXTEVEN			; Split even and odd indexes.
FAT_FATNEXTODD:
	xor		ah, ah					; Clear 'ah'.
	mov		al, [di + 2]			; Save 3rd byte on 'ah'.
	shl		ax, 4					; Make space for nibble 0.
	mov		bl, [di + 1]			; Save 2nd byte on 'bl'.
	shr		bl, 4					; Isolate nibble 1 and shift it.
	or		al, bl					; Save that as 3rd nibble on 'al'.
	jmp		FAT_FATNEXTRET
FAT_FATNEXTEVEN:
	mov		al, [di]				; Save 1st byte on 'al'
	mov		ah, [di + 1]			; Save 2nd byte on 'ah'.
	and		ah, 0x0F				; Isolate 2st nibble of 'ch'.
FAT_FATNEXTRET:
	pop		di						; Restore registers.
	pop		dx
	pop		cx
	pop		bx

	ret								; Return to caller.

;	---------- FAT - Cluster to LBA -----------
;
;	Input:	ax: Cluster
;
;	Output:	ax: LBA.
;
FAT_CLUSTERTOLBA:
	push	ds						; Save data segment.

	push	bx						; Make sure data segment is zero.
	xor		bx, bx
	mov		ds, bx
	pop		bx

	sub		ax, 2					; Cluster - 2 = LBA in data section.
	add		ax, [DAT_ROOTLBA]		; Add LBA of the data section.
	add		ax, [DAT_ROOTSIZE]		; (rootlba + rootsize).

	pop		ds						; Restore data segment.
	ret								; Return to caller.

;	-------- FAT - Read file to buffer --------
;
;	Input:	ax: Cluster of the file.
;			dl: Drive ID.
;			ds:di: Buffer with FAT loaded.
;			es:si: Buffer to write to.
;
;	Note:	File size is limited to 64KB minus
;			the offset of the buffer in the
;			segment 'ds'.
;
;			For example, if 'es:si' points to
;			0x0100:0x1000, the maximum file
;			size will be 64KB - 0x1000, which
;			is 0xEFFF bytes (59KB).
;
;			If the buffer size is less than
;			64 KB, check the file size first,
;			for memory could be overwritten.
;
FAT_FILEREAD:
	pusha							; Save registers.
	mov		bl, 1					; Set sectors to read.
FAT_FILEREADLOOP:
	push	ax						; Save file cluster.
	call	FAT_CLUSTERTOLBA		; Convert cluster to LBA.
	call	DISK_READ				; Write sector in buffer.
	pop		ax						; Restore file cluster.

	call	FAT_FATNEXT				; Save next cluster on 'ax'.

	cmp		ax, 0x0FF8				; EOC? Stop reading.
	jge		FAT_FILEREADRET

	add		si, 0x0200				; Advance writing pointer.
	jmp		FAT_FILEREADLOOP		; Read next sector.
FAT_FILEREADRET:
	popa							; Restore registers.
	ret								; Return to caller.

;	------------- ERROR HANDLERS --------------
;
;	See:	RBIL (INTERRUP.LST, V-100E, INT 10h/AH=0Eh)
;
ERR:
	mov		ah, 0x0E				; Set interrupt ID.
	mov		bh, 0					; Write on page zero.
	int		0x10					; Teletype output.

	jmp		HALT					; Halt system.
ERR_DRIVEACCESS:
	mov		al, 'A'	
	jmp		ERR
ERR_DRIVEID:
	mov		al, 'I'
	jmp		ERR
ERR_RESET:
	mov		al, 'R'
	jmp		ERR
ERR_READFAIL:
	mov		al, 'F'
	jmp		ERR
ERR_NOSTAGE2:
	mov		al, 'N'
	jmp		ERR

;	------------ SPACE AFTER CODE -------------
;
SPACE_AFTERCODE:
	times	0x1FE - ($ - $$)	db 0	; Zero bytes until 0x7DFE.

;	------------- BOOT SIGNATURE --------------
;
BOOT_SIG:
	dw		0xAA55					; Boot signature.

;	--------- BUFFER FOR DISK SECTORS ---------
;
;	See:	https://wiki.osdev.org/Memory_Map_(x86)
;
BUFFER: