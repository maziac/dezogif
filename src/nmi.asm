;===========================================================================
; nmi.asm
;
; Routines for handling the NMI.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================
    


;===========================================================================
; Enables the Multiface NMI.
; Changes:
; A, BC, F
; ===========================================================================
mf_nmi_enable:
 ret ; TODO
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	or 00001000b	; Enable MF NMI
	nextreg REG_PERIPHERAL_2,a
	ret 


;===========================================================================
; Disables the Multiface NMI.
; Changes:
; A, BC, F
; ===========================================================================
mf_nmi_disable:
 ret ; TODO
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	and 11110111b	; Disable MF NMI
	nextreg REG_PERIPHERAL_2,a
	; And save value for exiting
	or 00001000b	; Enable M1 button bit
	ld (restore_registers.enable_nmi),a
	ret 



mf_hide:
	out (0x3F),a
	in a,(0xbf)
	ret 

mf_page_out:
	in a,(0xbf)
	ret 

mf_hide_and_return:
 IF 0
	; Not required
    ; Enable MF NMI
	ld a,REG_PERIPHERAL_2
	ld bc,IO_NEXTREG_REG
	out (c),a
	; Read register
	inc b	; IO_NEXTREG_DAT
	in a,(c)
	or 00001000b	; Enable MF NMI
	nextreg REG_PERIPHERAL_2,a
 ENDIF

	; Either hide or page out. Both work to re-enable the M1 button.
	call mf_hide
	;call mf_page_out

    pop bc, af
    retn

