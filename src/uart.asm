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
;BAUDRATE:   equ 1958400


; UART TX. Write=transmit data, Read=status
PORT_UART_TX:   equ 0x133b

; UART RX. Read data.
PORT_UART_RX:   equ 0x143b


; UART selection.
PORT_UART_CONTROL:   equ 0x153b

; UART Status Bits:
UART_RX_FIFO_EMPTY: equ 0   ; 0=empty, 1=not empty
UART_RX_FIFO_FULL:  equ 2   ; 0=not full, 1=full
UART_TX_READY:      equ 1   ; 0=ready for next byte, 1=byte is being transmitted



;===========================================================================
; Const data. 
;===========================================================================

; Baudrate timing calculation table.
; BAUDRATE must be 230400 at least otherwise a 1 byte table is not sufficient.
baudrate_table:
	defb 28000000/BAUDRATE
    defb 28571429/BAUDRATE
    defb 29464286/BAUDRATE
    defb 30000000/BAUDRATE
    defb 31000000/BAUDRATE
    defb 32000000/BAUDRATE
    defb 33000000/BAUDRATE
    defb 27000000/BAUDRATE



;===========================================================================
; Clears the receive FIFO.
; Changes:
;   A, E, BC
;===========================================================================
drain_rx_buffer:
    ld b,0  ; Check 256x that there is no data
.wait_loop:
    push bc
    call .read_loop
    pop bc
    djnz .wait_loop
    ret

.read_loop:
	ld bc,PORT_UART_TX
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    ret z   ; Return if buffer empty

    ; At least 1 byte received, read it
    inc b	; The low byte stays the same
    in a,(c)
    dec b
    jr .read_loop


;===========================================================================
; Just changes the border color.
;===========================================================================
change_border_color:
    ld a,(slow_border_change)
    or a
    ret z   ; Don't change color if off
    ld a,(border_color)
    inc a
    and 0x07
    ld (border_color),a
    out (BORDER),a
    ret


;===========================================================================
; Waits until an RX byte is available.
; Changes the border color slowly to indicate waiting state (like for tape
; loading).
; Note: This runs when possibly the layer 2 read/write is set. I.e. it is not
; allowed to read/write data.
; I.e. also no CALLs, no PUSH/POP.
; Changes:
;   A, DE, BC
;===========================================================================
wait_for_uart_rx:
    ; Write layer 2 previous value
    ld a,(backup.layer_2_port)
    ld bc,LAYER_2_PORT
    out (c),a
.color_change:
    IF 0
    ; Change border color
    ld a,c
    inc a
    and 0x07
    out (BORDER),a
    ld c,a
    ENDIF
    ; Counter
    ld de,0
    ld b,20
.loop:
    ; Check if byte available.
	ld a,HIGH PORT_UART_TX
	in a,(LOW PORT_UART_TX)	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    jr z,.no_byte   ; Jump if no byte available

    ; Disable layer 2 read/write
    ld a,(backup.layer_2_port)
	and 11111010b	; Disable read/write only
    ld bc,LAYER_2_PORT
    out (c),a 
    ret       ; RET if byte available

.no_byte:   
    ; Decrement counter for changing the color
    dec e
    jr nz,.loop
    dec d
    jr nz,.loop
    djnz .loop
    ; change color
    jr .color_change


;===========================================================================
; Checks if a byte is available at the UART.
; Returns:
;   NZ = Byte available
;   Z = No byte available
; Changes:
;   AF
;===========================================================================
check_uart_byte_available:
	ld a,HIGH PORT_UART_TX
	in a,(LOW PORT_UART_TX)
	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    ret

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
    ; Change border
.flash1:
    ld a,BLUE
    out (BORDER),a
  
    ; Wait on byte
    ld e,0
	ld bc,PORT_UART_TX
.wait_loop:
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    jr nz,.byte_received
    dec e
    jr nz,.wait_loop
    
    ; "Timeout"
    ; Waited for 256*43 T-states=393us
    nop ; LOGPOINT read_uart_byte: ERROR=TIMEOUT
    jp rx_timeout   ; ASSERT

.byte_received:
    ; Change border
.flash2:
    ld a,YELLOW 
    out (BORDER),a
    ; At least 1 byte received, read it
    inc b	; The low byte stays the same
    in a,(c)
    ret


; Called if a UART RX timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
rx_timeout: ; The receive timeout handler
    ld a,ERROR_RX_TIMEOUT
timeout:
    ld (last_error),a
    jp main


; Called if a UART TX timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
tx_timeout: ; The receive timeout handler
    ld a,ERROR_TX_TIMEOUT
    jr timeout



;===========================================================================
; Enables flashing of the border while receiving data.
;===========================================================================
uart_flashing_border.enable:
    ld a,0x3E   ; LD A,n
    ld (read_uart_byte.flash1),a
    ld (read_uart_byte.flash2),a
    ld a,BLUE
    ld (read_uart_byte.flash1+1),a
    ld a,YELLOW
    ld (read_uart_byte.flash2+1),a
    ret    


;===========================================================================
; Disables flashing of the border while receiving data.
;===========================================================================
uart_flashing_border.disable:
    ld a,0x18   ; JR 2
    ld (read_uart_byte.flash1),a
    ld (read_uart_byte.flash2),a
    ld a,2
    ld (read_uart_byte.flash1+1),a
    ld (read_uart_byte.flash2+1),a
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
	push de, af
    ; Wait for TX ready
    call wait_for_uart_tx
    ; Transmit byte
	pop af, de
    out (c),a
    ret


;===========================================================================
; Waits until TX is ready on the UART.
; If it takes too long an error is generated.
; Changes:
;  AF, BC (=PORT_UART_TX), E
;===========================================================================
wait_for_uart_tx:
    ; Send response back
    ld bc,PORT_UART_TX
    ; Check if ready for transmit
    ld e,0
.wait_tx:
    in a,(c)
    bit UART_TX_READY,a
    ret z
    dec e
    jr nz,.wait_tx

    nop ; LOGPOINT write_uart_byte: ERROR=TIMEOUT
    jp tx_timeout   ; ASSERT



;===========================================================================
; Sets the UART baud rate.
; Source code is taken from NDS, https://github.com/Ckirby101/NDS-NextDevSystem.
; See also https://dl.dropboxusercontent.com/s/a4c4k9fsh2aahga/UsingUART2andWIFI.txt?dl=0
; The baudrate timings depend on the video timings in register 0x11.
; They don't depend on video mode being 50 or 60 Hz.
; Returns:
;  -
; Changes:
;  A, BC, DE, HL
;===========================================================================
set_uart_baudrate:
    ; Select UART and clear prescaler MSB
    ld bc,PORT_UART_CONTROL
	ld a,00010000b
	out	(c),a

    ; Get display timing
    ld a,REG_VIDEO_TIMING
    call read_tbblue_reg
	and 0111b			;video timing is in bottom 3 bits, e.g. HDMI=111b

    ; Get baudrate prescale values from table
	ld hl,baudrate_table
	add hl,a
	ld a,(hl)
    ; ignoring the high byte

    ; Write low byte of prescaler
	ld bc,PORT_UART_RX ; Writing=set baudrate
    ld l,a
    and 0x7F
	out	(c),a		;set lower 7 bits

    ; Write 2nd byte of prescaler
    rlc l
    ld a,0x40
    rla 
 	out	(c),a		;set to upper bits

	ret


;===========================================================================
; Sets up the ESP UART at joystick port.
; TX = PIN 7 both joystick ports
; RX = PIN 9 Joystick 2
; These pins are not used on normal Joystick.
; Only for Sega Genesis controller which cannot be used.
; Parameters:
;  uart_joyport_selection:
;     0x0=00b => no joystick port used
;     0x1=01b => joyport 1
;     0x2=10b => joyport 2
; Changed:
;  AF, BC, HL
;===========================================================================
set_uart_joystick:
    ld a,(uart_joyport_selection)
    ld l,a
    ; Read reg 0x05 to preserve the 50/60 Hz setting and scandoubler
    ld a,REG_PERIPHERAL_1
    call read_tbblue_reg    ; Reading the joysticks returns the original joy mode, even if set to UART
    ; Joy 1
    bit 0,l
    jr z,.no_joy1
    or 11001000b
.no_joy1:
    ; Joy 2
    bit 1,l
    jr z,.no_joy2
    or 00110010b
.no_joy2:
    ; Write to reg 0x05
    nextreg REG_PERIPHERAL_1,a

    ; Write to 0x37
    ld a,10010000b  ; Right joystick (Joy 2)
    bit 1,l
    jr nz,.joy_2
    ; Check for joy 1
    bit 0,l
    jr z,.no_joys  ; Neither 1 or 2  
    ; Joy 1
    ld a,10000000b  ; Left joystick (Joy 1)
.joy_2:
    out (KEMPSTON_JOY_2),a
.no_joys:
    ret


;===========================================================================
; Waits for a certain number of scanlines.
; Parameters:
;  H = the number of scanlines to wait.
; Changed:
;  AF, BC, HL
;===========================================================================
 IF 0
wait_scan_lines:
    ld bc,IO_NEXTREG_REG
    ld a,REG_ACTIVE_VIDEO_LINE_L
    out (c),a     
    inc b     
    ; Read first value
    in a,(c)  
    ld l,a
    ; Loop
.loop:
    in a,(c)        ; read the raster line LSB
    cp l    
    jr z,.loop
    ; Line changed
    ld l,a
    dec h
    jr nz,.loop
    ret
 ENDIF
