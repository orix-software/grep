
;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.include "macros/SDK-ext.mac"
.include "include/grep.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import StopOrCont

.importzp opt

.import line_count, pattern

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_grep

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
MATCH1	= '?'		; Matches exactly 1 character
MATCHN	= '*'		; Matches any string (including "")

MAX_LINE_SIZE = $80

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.pushseg
	.segment "ZEROPAGE"
		; Pointer to string to match
		unsigned short str
.popseg

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		unsigned char line[MAX_LINE_SIZE]
		unsigned char retvalue

		unsigned char save_pos

.popseg

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- fgets
;	- find
;	- (pattern_match)
;	- StopOrCont
;	- PrintHexByte
;	- print
;	- cputc
;	- crlf
;----------------------------------------------------------------------
.proc cmnd_grep
		lda	#<line
		sta	str
		lda	#>line
		sta	str+1

		; Code de retour par défaut: 1
		lda	#$01
		sta	retvalue

	loop1:
		jsr	StopOrCont
		bcc	cont

		cputc	'^'
		cputc	'C'
		crlf

		; Exit(2)
		sec
		lda	#$02
		ldy	#$00
		rts

	cont:
		lda	str
		ldy	str+1
		ldx	#MAX_LINE_SIZE
		jsr	fgets
		bcs	end

		; Ligne vide? -> ligne suivante
		;lda	line
		;beq	loop1
		;
		; Ou si on autorise la recherche de lignes vides
		; Ligne vide et pattern non nul -> ligne suivante
		; Ligne vide et pattern nul -> affiche la ligne
		;
		lda	line
		bne	_find
		lda	pattern
		bne	loop1
		beq	found
	_find:

		lda	opt
		and	#OPT_W
		beq	find_string

		jsr	pattern_match
		bcc	loop1
		bcs	found

	find_string:
		ldy	#$00
		jsr	find
		bcc	loop1

	found:
		; Valeur de sortie: 0
		lsr	retvalue
		; Incrémente le nombre de lignes trouvées
		inc	line_count
		bne	test_opt
		inc	line_count+1

	test_opt:
		; -cs?
		lda	opt
		and	#(OPT_C | OPT_S)
		bne	loop1

		; -c ?
		;lda	opt
		;and	#OPT_C
		;bne	loop1

		; -n?
		lda	opt
		bpl	disp_line

		lda	linenum+1
		jsr	PrintHexByte
		lda	linenum
		jsr	PrintHexByte
		cputc	':'

	disp_line:
		print	line
		crlf
		jmp	loop1

	end:
		clc
		lda	retvalue
		ldy	#$00
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		- str
;		- pattern
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc pattern_match
		; Récupère l'option -i dans V
		; Aucune instruction ADC ni SBC, donc V ne sera pas modifié
		; (en principe)
		bit	opt

		; http://6502.org/source/strings/patmatch.htm
		; By Paul Guertin (pg@sff.net), 30 August 2000.
		; Input:  A NUL-terminated, <255-length pattern at address pattern.
		;	 A NUL-terminated, <255-length string pointed to by str.
		;
		; Output: Carry bit = 1 if the string matches the pattern, = 0 if not.
		;
		; Notes:  Clobbers A, X, Y. Each * in the pattern uses 4 bytes of stack.
		;

		ldx	#$00	; X is an index in the pattern
		ldy	#$FF	; Y is an index in the string
	next:
		lda	pattern,x	; Look at next pattern character
		cmp	#MATCHN	; Is it a star?
		beq	star	; Yes, do the complicated stuff
		iny		; No, let's look at the string
		cmp	#MATCH1	; Is the pattern caracter a ques?
		bne	reg	; No, it's a regular character
		lda	(str),y	; Yes, so it will match anything
		beq	fail	;  except the end of string
	reg:

		; Comparaison case sensitive
		;cmp	(str),y	; Are both characters the same?
		;bne	fail	; No, so no match
		; Comparaison case insensitive
		; /!\ ATTENTION on peut avoir des faux positifs: @ et (c) par exemple
		eor	(str),y
		beq	keep_going
		bvc	fail
		cmp	#$20
		bne	fail
	keep_going:
		lda	(str),y


		inx		; Yes, keep checking
		cmp	#0		; Are we at end of string?
		bne	next	; Not yet, loop
	found:
		rts		; Success, return with C=1

	star:

		inx		; Skip star in pattern
		cmp	pattern,x	; String of stars equals one star
		beq	star	;  so skip them also
	stloop:
		txa		; We first try to match with * = ""
		pha		;  and grow it by 1 character every
		tya		;  time we loop
		pha		; Save X and Y on stack
		jsr	next	; Recursive call
		pla		; Restore X and Y
		tay
		pla
		tax
		bcs	found		 ; We found a match, return with C=1
		iny		; No match yet, try to grow * string
		lda	(str),y	; Are we at the end of string?
		bne	stloop		; Not yet, add a character
	fail:
		clc		; Yes, no match found, return with C=0
		rts
.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	Y: Position de début de recherche dans la chaine
; Sortie:
;	C: 1-> Ok
;	X: offset premier caractère
;	Y: offset caractère suivant dans la chaine
;
; Variables:
;	Modifiées:
;		- save_pos
;	Utilisées:
;		- opt
;		- pattern
;		- str
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc find
		lda	pattern
		beq	empty_pattern

		; Récupère l'option -i dans V
		; Aucune instruction ADC ni SBC, donc V ne sera pas modifié
		; (en principe)
		bit	opt

		; ldy	#$00
		dey

	start:
		ldx	#$00
	loop:
		iny
		lda	(str),y
		beq	failed

		; Comparaison case sensitive
;		cmp	pattern,x
;		bne	loop
		; Comparaison case insensitive
		; /!\ ATTENTION on peut avoir des faux positifs: @ et (c) par exemple
		eor	pattern,x
		beq	suivant
		bvc	loop
		cmp	#$20
		bne	loop

	suivant:
		sty	save_pos

	loop1:
		inx
		iny
		lda	pattern,x
		cmp	#$00
		beq	found

		; Comparaison case sensitive
;		cmp	(str),y
;		beq	loop1
		; Comparaison case insensitive
		; /!\ ATTENTION on peut avoir des faux positifs en dehors de la
		;     plage A-Z, a-z: @ et (c) par exemple
		eor	(str),y
		beq	loop1
		bvc	restart
		cmp	#$20
		beq	loop1

	restart:
		lda	(str),y
		beq	failed

		ldy	save_pos
		iny
		lda	(str),y
		bne	start

	failed:
		clc
		rts

	found:
		ldx	save_pos
		sec
		rts

	empty_pattern:
		clc
		rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
