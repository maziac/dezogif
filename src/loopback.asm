;===========================================================================
; loopback.asm
;
; Used to loopback a byte from the UART RX to it's TX.
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================



;===========================================================================
; Data. 
;===========================================================================


;===========================================================================
; checks if a byte is available at the UART TX.
; If not, returns.
; If yes the byte is sent to the UART TX.
;===========================================================================
uart_loopback:
    ; Check if byte is available
    call check_uart_byte_available
    ret z 	; Retunr if no byte available
    ; Read byte
    call read_uart_byte
    ; Loop back
    jp write_uart_byte

; Timeout occured during reading.
loopb_rx_timeout:
	jr uart_loopback
; The receive timeout handler
RX_TIMEOUT_HANDLER = loopb_rx_timeout

