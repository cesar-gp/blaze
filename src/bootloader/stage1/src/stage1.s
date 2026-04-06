;	---------------- CONSTANTS ----------------
;
;	The boot sector is preceeded by 29,75 KiB
;	of usable memory, starting at 0x0500. The
;	stage2 is loaded at the beginning of that
;	region.
;
;	See:	NASM301 (p. 38, 3.2.4)
;			for "equ" pseudo-instruction.
;
;			https://wiki.osdev.org/Memory_Map_(x86)
;			for memory segments documentation.
;
CONST_S1OFF:		equ 0x7C00		; stage1 memory offset.
CONST_S2SEG:		equ 0x0000		; Segment to load stage2 in.
CONST_S2OFF:		equ 0x0500		; Offset to load stage2 in.
CONST_ENTRYSIZE:	equ 32			; Directory entry size.

;	------------- NASM DIRECTIVES -------------
;
;	See:	NASM301 (p. 101, 8)
;			for NASM directives.
;
	bits	16						; 16-bit code.

;	--------------- BOOT SECTOR ---------------
;
;	IBM-compatible x86 Boot Sector.
;
;	See:	FAT32 (p. 9, "Boot sector and BPB")
;			for Boot Sector documentation.
;
BOOT_JMP:
	jmp		short PROGRAM			; 0x00: First jump (DOS 2.0).
	nop
BOOT_OEM:
	db		"MSWIN4.1"				; 0x03: OEM name (DOS 2.0).

;	- - - - -  BIOS Parameter Block - - - - - -
;
;	DOS 3.31 BIOS Parameter Block.
;
;	See:	FAT32 01 (p. 11, "Boot sector and BPB").
;			for BPB documentation.
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

;	- - -  Extended BIOS Parameter Block  - - -
;
;	DOS 4.0 Extended BIOS Parameter Block.
;
;	See:	FAT32 01 (p. 13, "Boot sector and BPB")
;			for EBPB documentation.
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

;	- - - - - - - - Blaze data  - - - - - - - -
;
;	See:	NASM301 (p. 37, 3.2.2)
;			for "resw" pseudo-instruction.
;
DAT_ROOTLBA:
	dw		0						; 0x41: Root directory LBA.
DAT_ROOTSIZE:
	dw		0						; 0x43: Root directory sectors.

;	- - - - - - - - - Strings - - - - - - - - -
;
;	See:	NASM301 (p. 40, 3.4.2).
;			for character string reference.
;
STR_STAGE2:
	db		"STAGE2  BIN"			; Stage 2 file name.

;	- - - - - - -  Program code - - - - - - - -
;
;	See:	RBIL (INTERRUP.LST, B-1308)
;			for INT 13h/AH=08h reference.
;
PROGRAM:
	xor		ax, ax					; Clear all segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax
	
	mov		sp, CONST_S1OFF			; Stack downwards from stage1.

	jmp		0x0000:.MAIN			; Set code segment to zero.
.MAIN:
	push	es						; Save segments.

	mov		ah, 0x08				; Set interrupt ID.
	mov		dl, [EBPB_DRIVEID]		; Select boot drive.
	xor		di, di					; Zero 'di' to avoid BIOS bugs.
	int		0x13					; Get drive parameters.

	jc		ERR.DRIVEACCESS			; Carry set? Error.

	cmp		dl, [EBPB_DRIVEID]
	jl		ERR.DRIVEID				; Nº of drives < Drive ID? Error.

	pop		es						; Restore segments.

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

	xor		bx, bx					; Set entry counter to zero.
.SEARCH:
	mov		di, STR_STAGE2			; Point 'di' to stage2 filename.
	mov		cx, 11					; Set counter to name length.
	
	push	si						; Compare filename with stage2's.
	repe	cmpsb					; memcmp(es:di, ds:si, cx)
	pop		si

	je		.FOUND					; Same? Found. Stop searching.

	add		si, CONST_ENTRYSIZE		; Point to next entry.
	inc		bx						; Increment entry counter.

	cmp		bx, [BPB_ROOTENTRIES]
	je		ERR.NOSTAGE2			; Nº entry == Entries? Error.

	jmp		.SEARCH					; Read next entry.
.FOUND:
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
	
	mov		ax, CONST_S2SEG			; Update segments.
	mov		ds, ax
	mov		es, ax
	mov		ss, ax

	jmp		CONST_S2SEG:CONST_S2OFF	; Jump to stage2.
	jmp		HALT					; Didn't jump? Halt system.

;	- - - - - - - - Halt system - - - - - - - -
;
;	See:	INTEL64IA32 (p. 1139, V2, 1.3, HLT)
;			for "hlt" instruction reference.
;
HALT:
	hlt
	jmp		HALT

;	- - -  DISK routines - Read sectors - - - -
;
;	Input:	ax: LBA.
;			bl: Sectors to read.
;			dl: Drive ID.
;			es:si: Buffer to write to.
;
;	See:	RBIL (INTERRUP.LST, B-1300)
;			for INT 13h/00h reference.
;
;			RBIL (INTERRUP.LST, B-1302)
;			for INT 13h/02h reference.
;
DISK_READ:
	pusha							; Save registers.

	push	dx						; Save 'dl' (drive ID).

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

	pop		ax						; Restore 'dl' (drive ID).
	mov		dl, al

	mov		ah, 0x02				; Set interrupt ID.
	mov		al, bl					; Read 'bl' sectors.
	mov		bx, si					; Write to buffer.

	xor		di, di					; Set counter to zero.
.REPEAT:
	cmp		di, 3
	je		ERR.READFAIL			; 3rd attempt finished? Error.

	inc		di						; Increment counter.
	int		0x13					; Read sector(s) into memory.

	jnc		.RETURN					; No carry set? Success. Stop reading.

	pusha							; Save registers.
	mov		ah, 0x00				; Set interrupt ID.
	int		0x13					; Reset disk system.

	jc		ERR.RESET				; Carry set? Reset error.
	popa							; Restore registers.

	jmp		.REPEAT
.RETURN:
	popa							; Restore registers.

	ret								; Return to caller

;	- - - - FAT12 - Get value from FAT  - - - -
;
;	Input:	ax: FAT index (cluster).
;			ds:di: Buffer with FAT loaded.
;
;	Output:	ax: Value at that FAT index.
;
;	See:	FAT32 (p. 17, "FAT Data Structure")
;			for a detailed explanation.
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
	jz		.EVEN					; Split even and odd indexes.

	xor		ah, ah					; Clear 'ah'.
	mov		al, [di + 2]			; Save 3rd byte on 'ah'.
	shl		ax, 4					; Make space for nibble 0.
	mov		bl, [di + 1]			; Save 2nd byte on 'bl'.
	shr		bl, 4					; Isolate nibble 1 and shift it.
	or		al, bl					; Save that as 3rd nibble on 'al'.
	jmp		.RETURN
.EVEN:
	mov		al, [di]				; Save 1st byte on 'al'
	mov		ah, [di + 1]			; Save 2nd byte on 'ah'.
	and		ah, 0x0F				; Isolate 2st nibble of 'ch'.
.RETURN:
	pop		di						; Restore registers.
	pop		dx
	pop		cx
	pop		bx

	ret								; Return to caller.

;	- - - -  FAT - Read file to buffer  - - - -
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
;	See:	FAT32 (p. 17, "FAT Data Structure")
;			for a detailed explanation.
;
FAT_FILEREAD:
	pusha							; Save registers.
	mov		bl, 1					; Set sectors to read.
.REPEAT:
	push	ax						; Save file cluster.
	sub		ax, 2					; Convert cluster to LBA.
	add		ax, [DAT_ROOTLBA]		; rootlba + rootsize + (cluster - 2).
	add		ax, [DAT_ROOTSIZE]
	call	DISK_READ				; Write sector in buffer.
	pop		ax						; Restore file cluster.

	call	FAT_FATNEXT				; Save next cluster on 'ax'.

	cmp		ax, 0x0FF8				; EOC? Stop reading.
	jge		.RETURN

	add		si, 0x0200				; Advance writing pointer.
	jmp		.REPEAT					; Read next sector.
.RETURN:
	popa							; Restore registers.
	ret								; Return to caller.

;	- - - - - - - Error handlers  - - - - - - -
;
;	Output a different character depending on
;	the entry point that the caller chooses and
;	then halts the system.
;
;	These are the error codes:
;
;	-	'A'	(ERR.DRIVEACCESS)
;			Drive parameters are inaccessible.
;
;	-	'I'	(ERR.DRIVEID)
;			Drive ID is greater than the number
;			of available disks.
;
;	-	'R' (ERR.RESET)
;			The disk couldn not be reset.
;
;	-	'F' (ERR.READFAIL)
;			Attempted to read a sector of the
;			disk and failed three times.
;
;	-	'N' (ERR.NOSTAGE2)
;			Stage2.bin file could not be found
;			on the disk.
;
;	See:	RBIL (INTERRUP.LST, V-100E)
;			for INT 10h/AH=0Eh documentation.
;
ERR:
	mov		ah, 0x0E				; Set interrupt ID.
	mov		bh, 0					; Write on page zero.
	int		0x10					; Teletype output.

	jmp		HALT					; Halt system.
.DRIVEACCESS:
	mov		al, 'A'	
	jmp		ERR
.DRIVEID:
	mov		al, 'I'
	jmp		ERR
.RESET:
	mov		al, 'R'
	jmp		ERR
.READFAIL:
	mov		al, 'F'
	jmp		ERR
.NOSTAGE2:
	mov		al, 'N'
	jmp		ERR

;	- - - - - Padding until 510 bytes - - - - -
;
	times	0x1FE - ($ - $$) db 0	; Zero bytes until 0x7DFE.

;	------------- BOOT SIGNATURE --------------
;
;	See:	UEFI211 (p. 112, 5.2.1)
;			for MBR partition table and boot
;			sector documentation.
;
	dw		0xAA55					; Boot signature.

;	--------- BUFFER FOR DISK SECTORS ---------
;
;	The boot sector is followed by 480,5 KiB of
;	usable memory. This program makes use of a
;	maximum of 15 sectors (7680 B) from that
;	region to:
;
;	-	Load the root directory and search for
;		the stage2 binary ("STAGE2  BIN").
;
;	-	Load the FAT to search for clusters of
;		the stage2 binary.
;
;	By default, the root directory takes up 15
;	sectors, and the FAT takes up 9. After the
;	execution, this memory region can be used
;	by any other program without risks.
;
;	See:	https://wiki.osdev.org/Memory_Map_(x86)
;			for memory segment documentation.
;
BUFFER: