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
; I.e. a function that was called by teh debugged program.
; When entered:
; Stack for a function call from the debugged program
; - [SP+6]:	The return address
; - [SP+4]:	Function number
; - [SP+2]: 0x0000, to distinguish from SW breakpoint
; - [SP]:	AF was put on the stack
; Stack for a function call from the debugged program if a parameter is used
; - [SP+8]:	The return address
; - [SP+6]:	Parameter
; - [SP+4]:	Function number
; - [SP+2]: 0x0000, to distinguish from SW breakpoint
; - [SP]:	AF was put on the stack
;===========================================================================
exec_user_function:
	; Get the function number from the stack 
	inc sp : inc sp : inc sp : inc sp	; Now points to function number
	pop af ; A=Function number
	ld (tmp_data),a	; Save value
	dec sp : dec sp
	dec sp : dec sp
	dec sp : dec sp

	; Move AF up by 2 positions
	pop af 	; Get AF
	; Skip 0x0000
	inc sp : inc sp : inc sp : inc sp
	push af
	; The stack is now:
	; - return address
	; - AF
	ld a,(tmp_data)	; Restore function number
	dec a
	jp z,execute_cmd	; A = 1
	dec a
	jp z,execute_init_slot0_bank	; A = 2 
	; ERROR ; TODO: Do error handling, e.g. print error on screen
	; ASSERT 
	jr $


;===========================================================================
; Initializes the given bank with debugger code.
; 8 bytes at address 0 and 14 bytes at address 66h.
; Parameters:
;   A = bank to initialize.
; When entered:
; Stack:
; - [SP+4]:	The return address
; - [SP+2]:	Parameter
; - [SP]:	AF was put on the stack
;===========================================================================
execute_init_slot0_bank:
	; Get bank/change stack
	inc sp : inc sp
	pop af  	; Get bank in high byte
	ld (tmp_data),a	; Save value
	dec sp : dec sp
	dec sp : dec sp

	; Move AF up by 1 position
	pop af 	; Get AF
	; Skip parameter
	inc sp : inc sp
	push af

	; Save registers
	call save_registers

    ; Save slot
    call save_swap_slot0

	; Copy
	ld a,(tmp_data)	; Get bank
 	call .inner

    ; Restore slot
    call restore_swap_slot0
	
	; Restore registers
	jp restore_registers

	; A contains the bank.
.inner:
    ; Switch in the bank at 0xC000
    nextreg REG_MMU+SWAP_SLOT,a
     ; Overwrite the address 0 and 66h with code
    MEMCOPY SWAP_SLOT*0x2000, copy_rom_start_0000h_code, copy_rom_start_0000h_code_end-copy_rom_start_0000h_code
    MEMCOPY SWAP_SLOT*0x2000+copy_rom_start_0066h_code-copy_rom_start_0000h_code, copy_rom_start_0066h_code, copy_rom_start_0066h_code_end-copy_rom_start_0066h_code
    ; Save the bank number inside the bank (self modifying code)
    ld (SWAP_SLOT*0x2000+dbg_enter.bank-copy_rom_start_0000h_code),a
	ret
