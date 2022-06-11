
;----------------------------------------------------------------------
;			includes cc65
;----------------------------------------------------------------------
.feature string_escapes

.include "telestrat.inc"

;----------------------------------------------------------------------
;			includes SDK
;----------------------------------------------------------------------
.include "SDK.mac"

;----------------------------------------------------------------------
;			include application
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				imports
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				exports
;----------------------------------------------------------------------
.export cmnd_help

;----------------------------------------------------------------------
;			Defines / Constantes
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------

;----------------------------------------------------------------------
;			Programme principal
;----------------------------------------------------------------------
.segment "CODE"

;----------------------------------------------------------------------
;
; Entrée:
;	-
; Sortie:
;	AY: 1
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	- print
;----------------------------------------------------------------------
.proc cmnd_help
		print	help_msg
		print	longhelp_msg

		; Exit(1)
		lda	#$01
		ldy	#$00
		rts
.endproc

;----------------------------------------------------------------------
;			Chaines statiques
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"

		help_msg:
			.byte "\r\n"
			.byte "\x1bC                grep\r\n\n"
			.byte " \x1bTSyntax:\x1bP\r\n"
			.byte "    find\x1bB[-nciswh]\x1bAstring filename\r\n"
			.byte "\r\n"
		.byte $00

		longhelp_msg:
			.byte "\r\n"
			.byte " \x1bTOptions:\x1bP\r\n"
			.byte "   \x1bB-n\x1bGShow line numbers\r\n"
			.byte "   \x1bB-c\x1bGCount only the matching lines\r\n"
			.byte "   \x1bB-i\x1bGIgnore case\r\n"
			.byte "   \x1bB-s\x1bGSilent mode\r\n"
			.byte "   \x1bB-w\x1bGstring can use wildcards *, ?, ^        and $\r\n"
			.byte "   \x1bB-h\x1bGdisplay command syntax\r\n"
			.byte "\r\n"
			.byte " \x1bTExamples:\x1bP\r\n"
			.byte "    find error menu.sub\r\n"
			.byte "    find -n \"level 1\" menu.sub\r\n"
			.byte "    find -i ERROR menu.sub\r\n"
			.byte "    find -ni 'level 2' menu.sub\r\n"
			.byte "    find -w '^if' menu.sub\r\n"
			.byte "    find -w 'error$' menu.sub\r\n"
			.byte "    find -w 'if*level ??' menu.sub\r\n"
			.byte "\r\n"
			.byte $00

.popseg
