;===========================================================================
; mf_rom.asm
;
; Contains mainly the NMI routine and the code to copy the debugger to bank 7.
;===========================================================================

;MF_ORIGIN_ROM:   equ 0x0000
;MF_DIFF_TO_RAM:  equ MF_ORIGIN_ROM+0x2000-MF.main_prg_copy ; At 0x2000

; For testing:
MF_ORIGIN_ROM:  equ 0x6000  ; For testing another origin is defined
MF_DIFF_TO_RAM:  equ main_end-MAIN_ADDR    ; Just after the debugger program


 IFNDEF UNIT_TEST
    OUTPUT "out/mf_nmi.bin"
 ENDIF

;===========================================================================
; ROM for Multiface.
;===========================================================================
    MODULE MF 

    ORG MF_ORIGIN_ROM

    defs 0x38
    ei
    ret

    defs MF_ORIGIN_ROM+0x66-$
 
;===========================================================================
; NMI: 0x0066
; Is executed if the M1 (yellow) button is pressed for the Multiface.
; The NMI cannot be interrupted by a maskable interrupt and it
; will not be interrupted by another NMI as the M1 button is not re-activated
; before paging out the MF ROM/RAM at the end of the routine.
;===========================================================================   
nmi66h:
    ; Save the SP
    ld (MF.backup_sp),sp
    ; Change SP to be sure that it inside RAM, so change it to MF RAM for now.
    ld sp,MF.stack.top 

    ; Save to MF stack
    push af, bc

    ; Change border
    ld a,(MF.border_color)
    inc a
    and 0x07
    ld (MF.border_color),a
    out (BORDER),a

	; Now backup main slot.
	ld bc,IO_NEXTREG_REG
	ld a,REG_MMU+MAIN_SLOT
	out (c),a
	; Read register
    inc b
	in a,(c)	; A contains the previous bank number for MAIN_SLOT

	; Page in slot 7
	nextreg REG_MMU+MAIN_SLOT,MAIN_BANK
	; Save previous bank
	ld (slot_backup.slot7),a    

    ; Save clock
	ld a,REG_TURBO_MODE
	dec b   ; IO_NEXTREG_REG
	out (c),a
	; Read register
    inc b
	in a,(c)
	ld (backup.speed),a

    ; Switch clock
    nextreg REG_TURBO_MODE,RTM_3MHZ

    ; Check for long or short key press
    ld de,0xFFFF    ; counter (ca. 1.5 sec)
.wait_m1_button_loop:   ; ca. 23us per loop
    ; Decrement counter
    dec de
    ld a,d
    or e
    jr z,init_main_bank ; Init if long press

    ; Check M1 button state
	dec b   ; IO_NEXTREG_REG
	ld a,REG_ANTI_BRICK
	out (c),a
	; Read register
    inc b
	;in a,(c)	; A contains the M1 button status in bit 0
    ;bit RAB_BUTTON_MULTIFACE,a
    ;jr nz,.wait_m1_button_loop ; Wait until key release

    ; TODO: Fake : remove
    ld bc,PORT_KEYB_YUIOP
    in a,(c)
    bit 2,a
    jr z,.wait_m1_button_loop ; Wait until key release

    ; Speed up
    nextreg REG_TURBO_MODE,RTM_28MHZ

	; Compare with magic number
    push hl
	ld a,(main_prg_copy+magic_number_a)
	ld hl,MAIN_ADDR+magic_number_a
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_b)
    inc hl
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_c)
	ld hl,MAIN_ADDR+magic_number_c
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+magic_number_d)
	inc hl
	cp (hl)
	jr nz,init_main_bank
    ; Also check build time
	ld a,(main_prg_copy+build_time_rel)
	ld hl,MAIN_ADDR+build_time_rel
	cp (hl)
	jr nz,init_main_bank
	ld a,(main_prg_copy+build_time_rel+1)
	inc hl
	cp (hl)
	jr nz,init_main_bank

    pop hl, bc

    ; Check if program was already stopped
    ld a,(prgm_state)
    cp PRGM_STOPPED
    jp z,mf_nmi_button_pressed_immediate_return

    ; Restore registers from MF stack
    pop af 

    jp mf_nmi_button_pressed

init_main_bank:   
    di
    ld sp,debug_stack.top

	; Maximize clock speed
	nextreg REG_TURBO_MODE,RTM_28MHZ

    ; Reset layer 2 writing/reading
    ld bc,LAYER_2_PORT
    xor a
    out (c),a

    ; Switch in ROM bank
    nextreg REG_MMU+0,ROM_BANK
    nextreg REG_MMU+1,ROM_BANK

    ; The main program needs to be copied to MAIN_BANK
    ; Copy the code
    nextreg REG_MMU+SWAP_SLOT,MAIN_BANK
    ;MEMCOPY SWAP_ADDR, MAIN_ADDR, 0x2000   
    MEMCOPY SWAP_ADDR, main_prg_copy, MF_ORIGIN_ROM+0x2000-main_prg_copy 

    ; Page in MAIN_BANK
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK

    ; Jump to main bank
    jp main_bank_entry  ; Is executed from MF ROM
    

; Align to 16 bytes.
    ALIGN 16, 0
    
 IFNDEF UNIT_TEST
    OUTEND
 ENDIF


;===========================================================================
; The are here contains a copy of the main debug program.
; It will be copied from here into the MAIN_BANK/MAIN_SLOT.
;===========================================================================   

main_prg_copy:
    ; The actual code is copied in the make file target mf_rom.
    ; ...

 

;===========================================================================
; The MF RAM area.
;===========================================================================   
    defs MF_DIFF_TO_RAM


; The Multiface stack. Used only for a very short timeframe.
stack:  
    defs 2*20
.top:
    
; Used to backup the debugged program's SP.
backup_sp:      defw 0

; Border color: TODO: Remove 
border_color:   defb 0

    ENDMODULE

