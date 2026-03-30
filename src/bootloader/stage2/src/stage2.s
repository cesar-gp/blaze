;	---------------- CONSTANTS ----------------
;
CONST_S1SEG:			equ 0			; stage1 memory segment.
CONST_S2SEG:			equ 0x50		; stage2 memory segment.
CONST_S2OFF:			equ 0x500		; stage2 memory offset.

CONST_BPB_RESERVEDSECS:	equ 0x7C0E		; Pointers to stage1 symbols.
CONST_EBPB_DRIVEID:		equ 0x7C24

CONST_DISK_LBATOCHS:	equ 0x7C45		; Pointers to stage1 functions.
CONST_DISK_READ:		equ 0x7C49
CONST_FAT_FATNEXT:		equ 0x7C4D
CONST_FAT_CLUSTERTOLBA:	equ 0x7C51
CONST_FAT_FILEREAD:		equ 0x7C55

;	------------- NASM DIRECTIVES -------------
;
	bits	16
	global	PROGRAM

;	-------------- ENTRY SECTION --------------
;
	section	.entry

PROGRAM:
	mov		sp, CONST_S2OFF

	mov		si, STR_OK
	push	CONST_S2SEG
	call	PRINT

	call	HALT

	; EJEMPLOS DE FUNCIONES IMPORTADAS.
	; --

	; Leer el archivo que empieza en
	; el cluster 2 en 0x0050:0x5000.
	;
	; ; Conseguir el LBA de la FAT.
	; push		ds
	; mov		ax, CONST_S1SEG
	; mov		ds, ax
	; mov		ax, [CONST_BPB_RESERVEDSECS]
	; pop		ds
	; 
	; ; Leer la FAT a 0x0050:0x1500
	; mov		bl, 1
	; mov		dl, 0
	; mov		si, 0x1500
	; call	CONST_S1SEG:CONST_DISK_READ
	; 
	; ; Leer el archivo en el cluster 2 a 0x0050:0x5000
	; mov		ax, 2
	; mov		dl, 0
	; mov		di, 0x1500
	; mov		si, 0x5000
	; 
	; call	CONST_S1SEG:CONST_FAT_FILEREAD

	; ; Leer el boot sector a 0x0050:0x1500.
	;
	; mov		ax, 0
	; mov		bl, 1
	; mov		dl, 0
	; mov		si, 0x1500
	; 
	; call		CONST_S1SEG:CONST_DISK_READ

	; Leer la FAT y conseguir el cluster
	; al que apunta el índice nº 3.
	; 
	; ; Conseguir el LBA de la FAT.
	; push		ds
	; mov		ax, CONST_S1SEG
	; mov		ds, ax
	; mov		ax, [CONST_BPB_RESERVEDSECS]
	; pop		ds
	; 
	; ; Leer la FAT a 0x0050:0x1500
	; mov		bl, 1
	; mov		dl, 0
	; mov		si, 0x1500
	; call		CONST_S1SEG:CONST_DISK_READ
	; 
	; ; Leer su índice nº 3.
	; mov		ax, 3
	; mov		si, 0x1500
	; call		CONST_S1SEG:CONST_FAT_FATNEXT

	; Convertir un nº de cluster a LBA.
	;
	; mov		ax, 0
	; call	CONST_S1SEG:CONST_FAT_CLUSTERTOLBA

	; Leer el archivo en el cluster 2.
	;
	; ; Conseguir el LBA de la FAT.
	; push	ds
	; mov		ax, CONST_S1SEG
	; mov		ds, ax
	; mov		ax, [CONST_BPB_RESERVEDSECS]
	; pop		ds
	; 
	; ; Leer la FAT a 0x0050:0x1500
	; mov		bl, 1
	; mov		dl, 0
	; mov		si, 0x1500
	; call	CONST_S1SEG:CONST_DISK_READ
	; 
	; ; Leer el archivo en el cluster 2 a 0x500:0x5000
	; mov		ax, 2
	; mov		dl, 0
	; mov		di, 0x1500
	; mov		si, 0x5000
	; 
	; call	CONST_S1SEG:CONST_FAT_FILEREAD

;	-------------- TEXT SECTION ---------------
;
	section	.text

;	--------------- HALT SYSTEM ---------------
;
HALT:
	hlt
	jmp		HALT

;	----- PRINT 0-terminated ASCII string -----
;
;	@in		es:si: Pointer to string.
;
PRINT:
	push	ax						; Save registers.
	push	bx
	push	si

	mov		ah, 0x0E				; Set interrupt ID.
	mov		bh, 0					; Write to page zero.
PRINT_LOOP:
	lodsb							; al = *(ds:si++)
	cmp		al, 0					; '\0'? Stop printing.
	jz		PRINT_RET

	int		0x10					; INT 0x10/AH=0x0E (print char).
									; https://ctyme.com/intr/rb-0106.htm

	jmp	PRINT_LOOP					; Read next byte.
PRINT_RET:
	pop		si						; Restore registers.
	pop		bx
	pop		ax

	retf							; Far return to caller.

;	-------------- DATA SECTION ---------------
;
	section	.data

;	------------- RODATA SECTION --------------
;
	section	.rodata

STR_OK:
	db		"System booted correctly!", 0x0D, 0x0A, 0

;	--------------- BSS SECTION ---------------
;
	section	.bss