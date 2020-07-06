;===========================================================================
; functions.asm
;
; Contains the functions that can be called from the debugged program
; through address 0x0000.
;===========================================================================


;===========================================================================
; Constants
;===========================================================================

;===========================================================================
; Called by enter_debugger to execute a user function. 
; I.e. a function that was called by the debugged program.
; When entered (debugged_prgm_stack_copy):
; Stack for a function call from the debugged program
; - [SP+6]:	The return address
; - [SP+4]:	Bit 0-3: Function number, Bit 4-7: Optional parameter
; - [SP+2]: 0x0000, to distinguish from SW breakpoint
; - [SP]:	AF was put on the stack
;===========================================================================
exec_user_function:
	; Get the function number from the stack 
	ld a,(debugged_prgm_stack_copy.function_number)
	; LOGPOINT function number = ${A}
	dec a
	jp z,execute_cmds	; A = 1
	dec a
	jp z,execute_init_slot0_bank	; A = 2 
	; ERROR
	ld a,ERROR_WRONG_FUNC_NUMBER
	ld (last_error),a
	; ASSERT 
	jp main


;===========================================================================
; Initializes the given bank with debugger code.
; 8 bytes at address 0 and 14 bytes at address 66h.
; Stack for a function call from the debugged program if a parameter is used
; - [SP+4]:	The return address
; - [SP+2]:	Bank number to initialize
; - [SP]:	AF
;===========================================================================
execute_init_slot0_bank:
	; Adjust the stack
	call adjust_debugged_program_stack_for_function

    ; Save slot
    call save_swap_slot
	
	; Get bank from high byte
	ld a,(debugged_prgm_stack_copy.parameter)
    ; Switch in the bank at 0xC000
    nextreg REG_MMU+SWAP_SLOT,a
 	call modify_bank

    ; Restore slot
    call restore_swap_slot

	jp restore_registers


;===========================================================================
; Modifies the
; 8 bytes at address 0 and 14 bytes at address 66h
; of the bank at 0xC000.
; Parameters:
;   A = bank number to write into the bank.
; Changes:
;  HL, DE, BC
;===========================================================================
modify_bank:
     ; Overwrite the address 0 and 66h with code
    MEMCOPY SWAP_ADDR, copy_rom_start_0000h_code, copy_rom_start_0000h_code_end-copy_rom_start_0000h_code
    MEMCOPY SWAP_ADDR+copy_rom_start_0066h_code, MAIN_ADDR+copy_rom_start_0066h_code, copy_rom_start_0066h_code_end-copy_rom_start_0066h_code
    ; Save the bank number inside the bank (self modifying code)
    ld (SWAP_ADDR+dbg_enter.bank),a
	ret
