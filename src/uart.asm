;===========================================================================
; uart.asm
;
; Routines for the lowel handling of the UART.
; I.e.
; - Check the port for received byte.
; - Get received byte.
; - Send one byte.
;
; Speed:
; The routine runs at 28MHz. I.e. 7MHz for 4 T-States.
; Or 7 million simple instructions per second.
; Baudrate:
; The baudrate maximum is 1958400. Which is approx. 200kBytes per second.
; That means download of a 64k Z80 program would take up to 0.25 seconds.
; 
; The minimum required time for reading 1 byte at max. clock speed is
; about 3us. Transmission time is 5us.
; Timeout is set to 393us.
;
; 
;
;===========================================================================

    
;===========================================================================
; Constants
;===========================================================================


; UART baudrate
BAUDRATE:   equ 1958400


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

; Baudrate timing calculation table
baudrate_table:
	defw 28000000/BAUDRATE
    defw 28571429/BAUDRATE
    defw 29464286/BAUDRATE
    defw 30000000/BAUDRATE
    defw 31000000/BAUDRATE
    defw 32000000/BAUDRATE
    defw 33000000/BAUDRATE
    defw 27000000/BAUDRATE



; Color is changed after each received message.
border_color:	defb BLACK


;===========================================================================
; Waits until an RX byte is available.
; Changes the border color slowly to indicate waiting state (like for tape
; loading).
; Changes:
;   A
;===========================================================================
wait_for_uart_rx:
.color_change:
    ; Change border color
    ld a,(border_color)
	inc a
    and 0x07
	ld (border_color),a
	out (BORDER),a
    ; Counter
    ld de,0
    ld b,20
.loop:
    ; Check if byte available.
	ld a,PORT_UART_TX>>8
	in a,(PORT_UART_TX&0xFF)	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    ret nz      ; RET if byte available
    
    ; Decrement counter for changing the color
    dec e
    jr nz,.loop
    dec d
    jr nz,.loop
    djnz .loop
    ; change color
    jr .color_change


;===========================================================================
; Waits until an RX byte is available and returns it.
; Returns:
;   A = the received byte.
; Changes:
;   BC, E
; Duration:
;   66 T-states minimum
;   2.4us at 28MHz
;===========================================================================
read_uart_byte:
    ld e,0
	ld bc,PORT_UART_TX
.wait_loop:
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_EMPTY,a
;    ld a,e
;    out (BORDER),a
    jr nz,.byte_received
    dec e
    jr nz,.wait_loop
    
    ; "Timeout"
    ; Waited for 256*43 T-states=393us
    jp timeout

.byte_received:
    ; At least 1 byte received, read it
    inc b	; The low byte stays the same
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



;===========================================================================
; Sets the UART baud rate.
; Source code is taken from NDS, https://github.com/Ckirby101/NDS-NextDevSystem.
; See also https://dl.dropboxusercontent.com/s/a4c4k9fsh2aahga/UsingUART2andWIFI.txt?dl=0
; Returns:
;  -
; Changes:
;  A, BC, DE, HL
;===========================================================================
set_uart_baudrate:
    ; Get display timing
    ld a,REG_VIDEO_TIMING
    call read_tbblue_reg
	and 3			;video timing is in bottom 4 bits!

    ; Get baudrate presace lavues from table
	ld hl,baudrate_table
	add hl,a
	ld e,(hl)
	inc hl
	ld d,(hl)

    ; Write 1rst byte of prescaler
	ld	bc,PORT_UART_RX ; Writing=set baudrate
	ld a,e
	and 0b01111111
	out	(c),a		;set lower 7 bits

    ; Write 2nd byte of prescaler
	ld a,e
	sla a
	ld a,d
	rla
	or 0b10000000
	out	(c),a		;set to upper bits

	ret
