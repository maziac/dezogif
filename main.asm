;===========================================================================
; main.asm
;===========================================================================

    DEVICE ZXSPECTRUMNEXT


    ORG 0x8000


;===========================================================================
; Include modules
;===========================================================================

    include "uart.asm"
    include "message.asm"

    
;===========================================================================
; Constants
;===========================================================================


; Border (for testing)
BORDER:     equ 0xFE

    

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
    ; Set some baudrate
    ld bc,PORT_UART_RX
    ld a,10
    out (c),a
    out (c),a
  ENDIF

main_loop:
    ; Check if byte available.
    call check_uart_rx
    jr nz,state_receive_message

    jr main_loop


; First byte of message has been detected. Now receive the rest
state_receive_message:
    call receive_message
    ; TODO: Interprete message.

    ; Simply send back for now
    ld hl,receive_buffer
    call send_message

.infinite:
    jr .infinite

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
    SAVENEX OPEN "dbg-uart-if.nex", main, stack_top
    SAVENEX CORE 2, 0, 0        ; Next core 2.0.0 required as minimum
    ;SAVENEX CFG 0               ; black border
    ;SAVENEX BAR 0, 0            ; no load bar
    SAVENEX AUTO
    SAVENEX CLOSE
