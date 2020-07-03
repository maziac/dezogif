;===========================================================================
; mf_rom.asm
;
; Contains mainly the NMI routine and the code to copy the debugger to bank 7.
;===========================================================================


;===========================================================================
; ROM for Multiface.
;===========================================================================
    MODULE MF 

    OUTPUT "out/enNextMf.rom"
    ORG 0

    defs 0x38
    ei
    ret

    defs 0x66-$
 
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

    ; Check if MAIN_BANK is already paged in
    cp MAIN_BANK
    jp z,mf_nmi_button_pressed_immediate_return

	; Page in slot 7
	nextreg REG_MMU+MAIN_SLOT,MAIN_BANK

	; Check if bank is already initialized
	push af ; save previous bank

	; Compare with magic number
	ld a,(magic_number.a)
	cp MAGIC_NUMBER.A
	jr nz,init_main_bank
	ld a,(magic_number.b)
	cp MAGIC_NUMBER.B
	jr nz,init_main_bank
	ld a,(magic_number.c)
	cp MAGIC_NUMBER.C
	jr nz,init_main_bank
	ld a,(magic_number.d)
	cp MAGIC_NUMBER.D
	jr nz,init_main_bank

	; Right bank already intitialized

	; Now the labels can be used directly (for data access)
	ld (slot_backup.slot7),a

    ; Restore registers from MF stack
    pop bc, af 

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
    MEMCOPY SWAP_ADDR, MAIN_ADDR, 0x2000   

    ; Page in MAIN_BANK
    nextreg REG_MMU+MAIN_SLOT,MAIN_BANK

    ; Jump to main bank
    jp main_bank_entry  ; Is executed from MF ROM

    ; Now add the MAIN_BANK program
    ;incbin "out/main.bin" 

    defs 0x2000-$


;===========================================================================
; The MF RAM area.
;===========================================================================   

; The Multiface stack. Used only for a very short timeframe.
stack:  
    defs 2*20
.top:
    
; Used to backup the debugged program's SP.
backup_sp:      defw 0

; Border color: TODO: Remove 
border_color:   defb 0

    ENDMODULE

    OUTEND
