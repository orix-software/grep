;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"
.include "errno.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import fp

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export fgets
.export buffer_reset

.export linenum

.export fpos_text

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
e1 = $e1
TEXTFILE = 1

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		unsigned short address

.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; Numéro de ligne du fichier
		unsigned char linenum[2]

		unsigned short max_line_size

		.if ::TEXTFILE
			unsigned long fpos_text
		.else
			fpos_text := fpos
		.endif

.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	AY: Adresse du tampon
;	X : Taille du tampon
;
; Sortie:
;	A  : 0 ou code erreur
;	X  : Modifié
;	Y  : 0
;	C=0: Ok
;	C=1: Erreur
;
; Variables:
;       Modifiées:
;               address
;		max_line_size
;       Utilisées:
;               -
; Sous-routines:
;       fgetc
;----------------------------------------------------------------------
.if TEXTFILE
.proc fgets
		sta	address
		sty	address+1
		stx	max_line_size

		; Incrémeente le numéro de ligne
		php
		sed
		clc
		lda	linenum
		adc	#$01
		sta	linenum
		lda	linenum+1
		adc	#$00
		sta	linenum+1
		plp

	loop:
		; fread	(address), #1, 1, fp
		; cmp	#$01
		; bne	eof
		jsr	fgetc
		bcs	eof

		; En principe on ne peut pas avoir de caractère $00 dans un fichier texte
		ldy	#$00
		lda	(address),y
		beq	end

		; <CR>? il faut lire un autre caractère (msdos: <CR><LF>)
		cmp	#$0d
		beq	loop

		; <LF>?
		cmp	#$0a
		beq	end

		dec	max_line_size
		beq	errMemFull

		inc	address
		bne	loop
		inc	address+1
		bne	loop

	errMemFull:
		print	line_too_long_msg
		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte
		crlf
		lda	#e1
		bne	error

	end:
		; Y=0 => place un caractère nul à la place du <CR>
		tya
		sta	(address),y

		; Si ECHO ON
		; print	line
		; crlf

		ldx	max_line_size
		clc
		rts

	eof:
		; print	eof_msg
		lda	#$e4

	error:
		sec
		rts

	line_too_long_msg:
		.asciiz "Line too long "

	;eof_msg:
	;	.asciiz "EOF error\r\n"
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc fgetc
		ldx	buffer_pos
		cpx	buffer_size
		bcc	getc

		jsr	fill_buffer
		cpx	buffer_size
		beq	eof

	getc:
		ldy	#$00
		lda	buffer,x
		sta	(address),y
		inc	buffer_pos

		; Incrémente le pointeur du fichier pour Goto
		inc	fpos_text
		bne	end
		inc	fpos_text+1
		bne	end
		inc	fpos_text+2
		bne	end
		inc	fpos_text+3
		; beq	overFlow
	end:
	eof:
		rts

	fill_buffer:
		; Le ch376 ne peut lire que 254 octets en une seule fois
		fread	buffer, #$fe, 1, fp
		; cmp	#$fe
		; bne	eof

		sta	buffer_size

		ldx	#$00
		stx	buffer_pos

		; clc
		rts

	; eof:
		; rts

	buffer_pos: .byte	$00
	buffer_size: .byte	$00
	buffer: .res	256;0

.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	-
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc buffer_reset
		lda	#$00
		sta	fgetc::buffer_pos
		sta	fgetc::buffer_size
		rts
.endproc

.else

.proc fgets
		sta	address
		sty	address+1

		stx	max_line_size
		lda	#$00
		sta	max_line_size+1

		; Incrémeente le numéro de ligne
		php
		sed
		clc
		lda	linenum
		adc	#$01
		sta	linenum
		lda	linenum+1
		adc	#$00
		sta	linenum+1
		plp

	loop:
		fread	(address), #2, 1, fp
		cmp	#$02
		bne	eof

		ldy	#$01
		lda	(address),y
		cmp	max_line_size+1
		bne	readline
		dey
		lda	(address),y
		cmp	max_line_size

	readline:
		bcs	errMemFull

		; Longueur de la ligne
		ldy	#$00
		lda	(address),y
		sta	max_line_size
		iny
		lda	(address),y
		sta	max_line_size+1

		; Lit la ligne
		fread	(address), (max_line_size), 1, fp
		cmp	max_line_size
		bne	eof
		cpx	max_line_size+1
		bne	eof

	end:
		; Ajoute un caractère nul à la fin de la ligne
		ldy	max_line_size
		lda	#$00
		sta	(address),y

		; Si ECHO ON
		; print	line
		; crlf

		ldx	max_line_size
		clc
		rts

	errMemFull:
		print	line_too_long_msg
		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte
		crlf
		lda	#e1
		bne	error

	eof:
		; print	eof_msg
		lda	#$e4

	error:
		sec
		rts

	line_too_long_msg:
		.asciiz "Line too long "

	;eof_msg:
	;	.asciiz "EOF error\r\n"
.endproc


;----------------------------------------------------------------------
;
; Entrée:
;	-
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc buffer_reset
		; Compatibilité avec mode TEXTE
		rts
.endproc
.endif
