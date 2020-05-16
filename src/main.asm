;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT


    ORG 0x4000


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




    ; Save NEX file
    SAVENEX OPEN BIN_FILE, main, stack_top
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    SAVENEX CLOSE
