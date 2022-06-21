
;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes
.feature loose_char_term

.include "telestrat.inc"
.include "fcntl.inc"

XMAINARGS = $2C
XGETARGV = $2E

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"
.include "types.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------
.ifndef SDK_VERSION
	.include "macros/SDK-ext.mac"
.else
	.out "\tYou can remove macros/SDK-ext.mac from your project"
.endif

.include "include/grep.inc"

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------
.import fgets, linenum
.import sopt1
	sopt := sopt1
.importzp opt, cbp

.import cmnd_help, cmnd_version, cmnd_grep

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export _main
.export fp
.export line_count, pattern

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------
MAX_SEARCH_SIZE = 40
MAX_CMDLINE_SIZE = 128


;----------------------------------------------------------------------
;				 Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.segment "DATA"
		; Sauvegarde ligne de commande
		unsigned char cmdline[MAX_CMDLINE_SIZE]

		unsigned char retvalue

		unsigned char stop_char

		unsigned short filename
		unsigned short fp

		unsigned char pattern[MAX_SEARCH_SIZE]

		unsigned short line_count
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
;	- sopt
;	- cmnd_help
;	- cmnd_find
; 	- cmnd_version
;	- print
;	- prints
;	- fopen
;	- crlf
;----------------------------------------------------------------------
.proc _main
		; Code de retour par défaut: 1
		lda	#$01
		sta	retvalue

		; Initialise le numero de ligne
		lda	#$00
		sta	linenum
		sta	linenum+1
		sta	linenum+2

		; Initilaise le nombre de ligne trouvées
		sta	line_count
		sta	line_count+1

		; Sauvegarde la ligne de commande
		lda	#<BUFEDT
		ldy	#>BUFEDT
		sta	RES
		sty	RES+1

		ldy	#$00
	init:
		lda	(RES),y
		sta	cmdline,y
		beq	skip
		iny
		cpy	#MAX_CMDLINE_SIZE
		bcc	init
		bcs	oom_error

		; Saute le nom de la commande au début de la ligne
	skip:
		ldy	#$ff
	skip_loop:
		iny
		lda	cmdline,y
		beq	no_arg
		cmp	#' '
		bne	skip_loop

		; Recherche des options
		; YA: Offset caractère suivant le nom de la commande
		clc
		tya
		adc	#<cmdline
		tay
		lda	#>cmdline
		adc	#$00

		; -n: display line number ($80)
		; -i: case insensitive ($40)
		; -c: count ($20)
		; -s: silent mode ($10)
		; -w: wildcards ($08)
		; -h: help ($04)
		jsr	sopt
		.asciiz	"NICSWH"
		bcc	get_args

		; Récupère le paramètre inconnu
		txa
		tay
		lda	(cbp),y
		pha

		prints	"Unknown option: -"

		; Affiche le paramètre inconnu
		pla
		cputc
		crlf

		; Exit(2)
	exit2:
		lda	#$02
		ldy	#$00
		rts

	no_arg:
		jsr	cmnd_version
		prints	"Missing arguments\r\n"
		jmp	exit2

	oom_error:
		; Dépassement de la longueur maximale pour la ligne de commande
		prints	"Out of memory error\r\n"
		jmp	exit2

		; Récupérations des paramètres string et filename
	get_args:
		lda	opt
		and	#OPT_H
		beq	get_string_delim
		jmp	cmnd_help

	get_string_delim:
		; X:0 pour get_pattern
		ldx	#$00

		; YA: Adresse premier paramètre (cbp)
		lda	#' '
		sta	stop_char
		ldy	#$00
		lda	(cbp),y
		cmp	#'"'
		beq	change_stop
		cmp	#"'"
		bne	get_string_1
	change_stop:
		sta stop_char
		iny


	get_string_1:
		; -w?, non -> get_strinf
		lda	opt
		and	#OPT_W
		beq	get_string

		; Premier caractère de la chaîne == '^'?
		lda	(cbp),y
		cmp	#'^'
		beq	@skip
		; Oui, on place un '*' au début de la chaine de recherche
		lda	#'*'
		sta	pattern,x
		inx
		; Annule de iny suivant
		dey

	@skip:
		iny

	get_string:
		lda	(cbp),y
		beq	no_arg
		cmp	stop_char
		beq	get_filename
		sta	pattern,x
		inx
		iny
		cpy	#MAX_SEARCH_SIZE
		bcc	get_string
		bcs	oom_error

	get_filename:
		; -w?, non -> add_null
		lda	opt
		and	#OPT_W
		beq	@add_null

		; Dernier caractère de la chaine =='$'?
		dex
		lda	pattern,x
		cmp	#'$'
		beq	@add_null
		; Non, on ajoute '*'
		lda	#'*'
		inx
		sta	pattern,x
		inx

	@add_null:
		; Ajoute un $00 à la fin de pattern
		lda	#$00
		sta	pattern,x

		; Saute les éventuels ' ' entre les deux paramètres
	spaces:
		iny
		lda	(cbp),y
		beq	no_arg
		cmp	#' '
		beq	spaces

		; Adresse de filename
		clc
		tya
		adc	cbp
		sta	filename
		lda	cbp+1
		adc	#$00
		sta	filename+1

		; Ouverture du fichier
		fopen	(filename), O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		bne	go

	open_error:
		prints	"No such file or directory: "
		print	(filename)
		crlf
		jmp	exit2
		; Exit(2)
		;lda	#$02
		;ldy	#$00
		;rts

	go:
		jsr	cmnd_grep
		sta	retvalue
		bcs	exit_ret

	end:
		; -c?
		lda	opt
		and	#OPT_C
		beq	exit_ret

		; print	count_msg
		lda	line_count
		ldy	line_count+1
		ldx	#$03
		.byte	$00, XDECIM
		crlf

	exit_ret:
		fclose	(fp)

		; Exit(retvalue)
		lda	retvalue
		ldy	#$00
		rts

.endproc


;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
