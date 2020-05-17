;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT

; The 8k memory bank to store the code to.
USED_BANK:  EQU 95  ; Last 8k bank on unexpanded ZXNext
USED_SLOT:  EQU 1   ; 0x2000

    MMU USED_SLOT, USED_BANK 
    ORG USED_SLOT*0x2000


;===========================================================================
; Include modules
;===========================================================================

    include "zxnext/zxnext_regs.inc"
    include "utilities.asm"
    include "uart.asm"
    include "message.asm"
    include "commands.asm"
    include "backup.asm"

    
;===========================================================================
; Constants
;===========================================================================


    

;===========================================================================
; Data. 
;===========================================================================



;===========================================================================
; main routine - the code execution starts here.
;===========================================================================
main:
    ; Disable interrupts
    di
 
    ; Setup stack
    ld sp,stack_top


    ; Enable interrupts
    ;ei

    ld a,6
    out (BORDER),a

  IF 0
    ; Set baudrate
    call set_uart_baudrate
  ENDIF

    ; Init
    call clear_rx_buffer
    
main_loop:
    ; Check if byte available.
    call dbg_check_for_message

    inc a
    out (BORDER),a

    ; Some code
    ld bc,0xb1c1
    ld de,0xd1e1

    jr main_loop



;===========================================================================
; Stack. 
;===========================================================================

; Stack: this area is reserved for the stack
STACK_SIZE: equ 100    ; in words


; Reserve stack space
    defw 0  ; WPMEM, 2
stack_bottom:
    defs    STACK_SIZE*2, 0
stack_top:  
    defw 0  ; WPMEM, 2





;===========================================================================
; After loading the program starts here. Moves the bank to the destination 
; slot and jumps there.
;===========================================================================
    ORG 0xC000 
start_entry_point:
    ; At startup this program is mapped at 0xC000
    ; Now move the bank to 0x4000
    nextreg REG_MMU+USED_SLOT,USED_BANK
    ; Now the right bank is mapped into the slot, jump to the slot and continue
    jp main


    ; Save NEX file
    SAVENEX OPEN BIN_FILE, start_entry_point, stack_top
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    ;SAVENEX BANK 20
    SAVENEX CLOSE
