;===========================================================================
; backup.asm
;
; Stores the registers of the debugged program for later use
; and for restoration.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================



;===========================================================================
; Save all registers.
; ===========================================================================
save_registers:
	ld (backup.sp),sp

	; Use new stack
	ld sp,backup.af+2

	; Save registers
	push af, bc, de, hl, ix, iy		; Note: AF and BC need to be corrected later. A and BC is wrong, flags contain the interrupt state

	; Switch registers
	exx
	ex af,af'

	push af, bc, de, hl

	; I and R register
	ld a,r
	ld l,a
	ld a,i
	ld h,a
	push hl

	; Save IM, note: IM cannot be saved
	ld hl,0xFF	; 0xFF = undefined
	push hl

	; Switch back registers
	ex af,af'
	exx
	; End of register saving through pushing

.ret_jump:
	jp 0x0000	; Self-modified


;===========================================================================
; Restore all registers and jump to the stored PC.
; Parameters:
;   -
; ===========================================================================
restore_registers:
    ; Wait for TX ready. (This is to make sure everything is transmitted before the joyport configuration is changed.)
    call uart.wait_for_tx_empty

	; Disable joy port IO mode to enable the joysticks
    ld a,(copper_break_enabled)
    or a
    jr nz,.dont_enable_md_joysticks
	; Enable (MD) joysticks (if no copper, no async break)
	nextreg REG_JOYSTICK_IO_MODE,0
.dont_enable_md_joysticks:

	; Skip IM
	ld sp,backup.r

	; I and R register
	pop hl
	ld a,l
	ld r,a
	ld a,h
	ld i,a

	; Switch registers
	exx
	ex af,af'

	pop hl
	pop de
	pop bc
	pop af

	; Switch back registers
	ex af,af'
	exx

	pop iy
	pop ix
	pop hl		; Will be loaded later again
	pop de
	pop bc

	; Restore clock speed
	ld a,(backup.speed)
	nextreg REG_TURBO_MODE,a

	; Restore AF
	pop hl	; AF
	ld (debugged_prgm_stack_copy.af),hl

	; Load SP, so that it is possible to call subroutines.
	ld sp,debug_stack.top

	; Correct PC on stack (might have been changed by DeZog)
	ld hl,(backup.pc)
	ld (debugged_prgm_stack_copy.return1),hl

	; Correct the debugged program stack, i.e. put AF and return address on the stack
	ld hl,(backup.sp)	; Destination
	add hl,-4	; "PUSH" 2 values
	ld (backup.sp),hl
	ld de,4
	ld bc,debugged_prgm_stack_copy.af
	call write_debugged_prgm_mem

	; Restore the memory mapping of slots 0-6
	call restore_slots

	; Restore layer 2 reading/writing
	call restore_layer2_rw
	; It's still possible to read/write in slot 7

	; Restore IO_NEXTREG_REG
	ld bc,IO_NEXTREG_REG
	ld a,(backup.io_next_reg)
	out (c),a

	; Restore DE value
	ld de,(backup.de)
	; Restore BC value
	ld bc,(backup.bc)
	; Load correct value of HL
	ld hl,(backup.hl)
	; Get debugged program stack
	ld sp,(backup.sp)

	; Check interrupt state
	ld a,(backup.interrupt_state)
	bit 2,a
	; NZ if interrupts enabled

	; Change main state
	ld a,PRGM_RUNNING
	ld (prgm_state),a

	; Set bank to restore for slot 7
	ld a,(slot_backup.slot7)

.ret_jump1:	; Label for unit tests
	jp nz,exit_code_ei
.ret_jump2:	; Label for unit tests
	jp exit_code_di



;===========================================================================
; Adjusts the stack of the debugged program by 4 bytes.
; Before (debugged_prgm_stack_copy):
; - [SP+6]:	The return address
; - [SP+4]:	AF was put on the stack
; - [SP+2]:	    AF (Interrupt flags) was put on the stack
; - [SP]:	    BC
; ===========================================================================
adjust_debugged_program_stack_for_bp:
	ld de,(debugged_prgm_stack_copy.return1)
	dec de
	ld (backup.pc),de

	; Adjust debugged program SP
	ld hl,(backup.sp)
	add hl,4*2	; Skip complete stack
	ld (backup.sp),hl

.af:
	; Backup AF
	ld hl,(debugged_prgm_stack_copy.af)
	ld (backup.af),hl
	ret


;===========================================================================
; Adjusts the stack of the debugged program by 2 bytes.
; I.e. skips the return address.
; Before (debugged_prgm_stack_copy):
; - [SP]:	The return address
; ===========================================================================
adjust_debugged_program_stack_for_nmi:
	; Adjust debugged program SP
	ld hl,(backup.sp)
	inc hl : inc hl	; Skip complete stack
	ld (backup.sp),hl
	ret


;===========================================================================
; Saves layer 2 reading/writing.
; Why? The debugger accesses 0x0000-0xBFFF (memory commands, breakpoints,
; debugged stack, ULA screen) while the MF is paged out; Layer 2 r/w mapping
; would redirect these accesses.
; Changes:
;   A, BC
; ===========================================================================
save_layer2_rw:
	; Save layer 2 reading/writing
    ld bc,LAYER_2_PORT
    in a,(c)
	push af
	; Turn off layer 2 reading/writing
	and 11111010b	; Disable read/write only
	out (c),a
	; Store
	pop af
	ld (backup.layer_2_port),a
	ret


;===========================================================================
; Restores layer 2 reading/writing.
; Changes:
;   A, BC
; ===========================================================================
restore_layer2_rw:
	; Restore layer 2 reading/writing
	ld a,(backup.layer_2_port)
	ld bc,LAYER_2_PORT
	out (c),a
	ret


;===========================================================================
; Saves the banks of slots 0-6 (MMU registers) to slot_backup.
; Slot 7 is handled separately by the entry code.
; Changes:
;   AF, BC, D, HL
; ===========================================================================
save_slots:
	ld hl,slot_backup.slot0
	ld d,REG_MMU
	jr .loop

; Same, but starts with slot 1. Used on a SW breakpoint, where slot 0 has
; already been saved and MAIN_BANK is currently paged in there.
.from_slot1:
	ld hl,slot_backup.slot1
	ld d,REG_MMU+1
.loop:
	ld a,d
	call read_tbblue_reg
	ldi (hl),a
	inc d
	ld a,d
	cp REG_MMU+MAIN_SLOT
	jr nz,.loop
	ret


;===========================================================================
; Restores the banks of slots 0-6 (MMU registers) from slot_backup.
; Slot 7 is handled separately by the exit code.
; Changes:
;   AF, B, HL
; ===========================================================================
restore_slots:
	; Loop backwards from slot 6 to slot 0
	ld hl,slot_backup.slot6
	ld b,MAIN_SLOT
.loop:
	; MMU register for slot B-1
	ld a,b
	add REG_MMU-1
	ld (.nextreg_register+2),a	; Modify opcode
	; Get bank
	ld a,(hl)
	dec hl
.nextreg_register:
	nextreg 0x00,a	; Self-modifying code
	djnz .loop
	ret


;===========================================================================
; Returns the bank of the debugged program for an address.
; Parameters:
;   H = high byte of the address
; Returns:
;   A = bank (from slot_backup)
; Changes:
;   AF
; ===========================================================================
get_slot_bank:
	push hl
	; Get slot
	ld a,h
	rlca : rlca : rlca
	and 0x07
	; Get bank
	ld hl,slot_backup
	add hl,a
	ld a,(hl)
	pop hl
	ret


;===========================================================================
; Pages the bank of the debugged program for an address in (see page_in_bank)
; and converts the address accordingly.
; Parameters:
;   HL = address of the debugged program
; Returns:
;   HL = the address where the memory can be accessed
; Changes:
;   AF, HL
; ===========================================================================
page_in_debugged_prgm_bank:
	call get_slot_bank
	; Flow through

;===========================================================================
; Pages a bank in and converts the address accordingly.
; - RAM bank: The bank is paged into SWAP_SLOT. Only the offset inside
;   the 8k bank is used from the address.
; - ROM (0xFF): The ROM can only be paged into slot 0 and 1. Therefore
;   the ROM is paged into both slots and the address is masked with 0x3FFF,
;   i.e. address 0x2000-0x3FFF accesses the upper half of the ROM.
; Parameters:
;   A = bank
;   HL = address
; Returns:
;   HL = the address where the memory can be accessed
; Changes:
;   AF, HL
; ===========================================================================
page_in_bank:
	cp ROM_BANK
	jr z,.rom
	; RAM bank
	nextreg REG_MMU+SWAP_SLOT,a
	ld a,h
	and 0x1F
	or HIGH SWAP_ADDR
	ld h,a
	ret

.rom:
	nextreg REG_MMU,a
	nextreg REG_MMU+1,a
	ld a,h
	and 0x3F
	ld h,a
	ret


;===========================================================================
; Read data from the memory (e.g. stack) of the debugged program.
; Parameters:
;	HL = the data to get
;   DE = the count
;   BC = the destination (in slot 7)
; Returns:
;   The data copied to BC...
; Changes:
;
; ===========================================================================
read_debugged_prgm_mem:
	push bc
	ld bc,.read_write
	ld (memory_loop.inner_call+1),bc	; function pointer
	pop bc
	jp memory_loop.inner

; Inner call for 'loop_memory'
.read_write:
	; Get byte
	ld a,(hl)
	; Write byte
	ldi (bc),a
	ret


;===========================================================================
; Write data to the memory (e.g. the stack) of the debugged program.
; Parameters:
;	HL = the pointer to write to
;   DE = the count
;   BC = the source (in slot 7)
; Returns:
;   The data copied to HL...
; Changes:
;
; ===========================================================================
write_debugged_prgm_mem:
	push bc
	ld bc,.read_write
	ld (memory_loop.inner_call+1),bc	; function pointer
	pop bc
	jp memory_loop.inner

; Inner call for 'loop_memory'
.read_write:
	; Get byte
	ldi a,(bc)
	; Write byte
	ld (hl),a
	ret


; ===========================================================================
; Helper for cmd_read/write_bank_mem.
; Loops over the memory of one bank (see page_in_bank).
; - RAM bank: The address is masked with 0x1FFF, i.e. it wraps around
;   inside the 8k bank.
; - ROM (0xFF): The address is masked with 0x3FFF, i.e. both halves of the
;   ROM are accessible. It wraps around inside the 16k ROM.
; Parameters:
;   A = bank
;   HL = start address
;   DE = size
;   BC = contains a function pointer to the inner call. When called (HL)
;        contains the memory at the location. DE and HL should not be changed.
; ===========================================================================
bank_mem_loop:
	ld (memory_loop.inner_call+1),bc	; function pointer
	ld (.bank+1),a
.loop:
	; Page in bank, also wraps the address around
.bank:
	ld a,0	; Self-modifying code
	call page_in_bank
	call memory_loop.inner_loop
	jr nz,.loop	; End of 8k area reached
	ret


; ===========================================================================
; Helper class for cmd_read/write_mem and read/write_debugged_prgm_mem.
; Loops over the debugged program's memory. For each 8k slot the bank
; from slot_backup is paged in (see page_in_bank). After 0xFFFF the loop
; continues at 0x0000.
; Parameters:
;   HL = memory to read
;   DE = size
;   BC = contains a function pointer to the inner call. When called (HL)
;        contains the memory at the location. DE and HL should not be changed.
; ===========================================================================
memory_loop:
	ld (.inner_call+1),bc	; function pointer
.inner:	; Beginning from here BC is not touched anymore
	; Get slot
	ld a,h
	rlca : rlca : rlca
	and 0x07
	ld (.slot+1),a
	; Page in bank of the slot
	call page_in_debugged_prgm_bank

.slot_loop:
	call .inner_loop
	ret z	; Return if DE was 0

	; Next slot
.slot:
	ld a,0	; Self-modifying code
	inc a
	and 0x07
	ld (.slot+1),a
	; Start address of the slot
	rrca : rrca : rrca
	ld h,a
	ld l,0
	; Page in bank of the slot
	call page_in_debugged_prgm_bank
	jr .slot_loop


	; On a return DE contains the rest of the bytes to copy.
	; Returns with Z if DE is zero, otherwise NZ.
.inner_loop:
	; Check counter
	ld a,e
	or d
	ret z

.inner_call:
	call 0x0000	; Self-modifying code

	; Decrement counter
	dec de
	; Increment pointer
	inc l
	jr nz,.inner_loop
	inc h
	ld a,h
	and 0x1F	; Check for end of the 8k slot memory area (SWAP_SLOT or ROM)
	jr nz,.inner_loop

	; End of bank reached
	; Check DE once again
	ld a,e
	or d
	ret
