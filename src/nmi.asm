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
; ===========================================================================
mf_nmi_enable:
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	or 00001000b	; Enable MF NMI
	nextreg REG_PERIPHERAL_2,a
	ret 


;===========================================================================
; Disables the Multiface NMI.
; Returns:
; ===========================================================================
mf_nmi_disable:
	ld a,REG_PERIPHERAL_2
	call read_tbblue_reg
	and 11110111b	; Disable MF NMI
	nextreg REG_PERIPHERAL_2,a
	; And save value for exiting
	or 00001000b	; Enable M1 button bit
	ld (exit_code_enable_nmi.value),a
	ret 


;===========================================================================
; Before exiting the NMI is enabled.
; ===========================================================================
exit_code_enable_nmi:
.value:		equ $+3
	nextreg REG_PERIPHERAL_2,0	; self-modifying code
	jp exit_code