;===========================================================================
; uart.asm
;
; Routines for the lowel handling of the UART.
; I.e.
; - Check the port for received byte.
; - Get received byte.
; - Send one byte.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================

; UART TX. Write=transmit data, Read=status
PORT_UART_TX:   equ 0x133b

; UART RX. Read data.
PORT_UART_RX:   equ 0x143b

; UART Status Bits:
UART_RX_FIFO_EMPTY: equ 0   ; 0=empty, 1=not empty
UART_RX_FIFO_FULL:  equ 2   ; 0=not full, 1=full
UART_TX_READY:      equ 1   ; 0=ready for next byte, 1=byte is being transmitted



;===========================================================================
; Data. 
;===========================================================================


;===========================================================================
; Checks if an RX byte is available.
; Returns:
;   NZ = byte available
;   Z  = no byte available
; Changes:
;   A
;===========================================================================
check_uart_rx:
    ; Check if byte available.
	ld a,PORT_UART_TX>>8
	in a,(PORT_UART_TX&0xFF)	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
	ret 


;===========================================================================
; Waits until an RX byte is available and returns it.
; Returns:
;   A = the received byte.
; Changes:
;   BC
;===========================================================================
read_uart_byte:
	ld bc,PORT_UART_TX
.wait_loop:
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    jr z,.wait_loop

    ; At least 1 byte received, read it
    ld b,PORT_UART_RX>>8	; The low byte stays the same
    in a,(c)
	ret 


;===========================================================================
; Waits until TX is ready on the UART and writes one byte to the UART.
; Parameter:
;  A = the byte to write.
; Returns:
;  -
; Changes:
;  BC
;===========================================================================
write_uart_byte: 
	push af
    ; Send response back
    ld bc,PORT_UART_TX
    ; Check if ready for transmit
.wait_tx:
    in a,(c)
    bit UART_TX_READY,a
    jr nz,.wait_tx
    
    ; Transmit byte
	pop af
    out (c),a
	ret
