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
; Or about 7 million simple instructions per second.
; Baudrate:
; The baudrate maximum is 1958400.
; Good results were achieved with 921600.
; Which is approx. 100 kBytes per second.
; That means download of a 64k Z80 program would take up to 0.5 seconds.
;
;===========================================================================


;===========================================================================
; Constants
;===========================================================================


; UART baudrate
;BAUDRATE:   equ 1958400


; UART TX. Write=transmit data, Read=status
UART_TX:   equ 0x133b

; UART RX. Read data.
UART_RX:   equ 0x143b


; UART selection.
UART_SELECT:   equ 0x153b

; 0x153B is a shared POINTER, not a register the debugger owns. Bit 6 says which
; of the machine's two UARTs every one of 0x133B, 0x143B and 0x163B refers to at
; the instant of the access (serial/uart.vhd:350-376), so "in a,(0x133B)" means
; "the status of whichever channel is selected" where the debugger means "the
; status of mine". Those coincide only while nothing else has moved the pointer,
; and a debugged program legitimately using the OTHER UART must move it - the
; machine has two of them precisely so that two owners can coexist.
;
; Writing these values back has BIT 4 CLEAR, which is what makes the correction
; safe: with bit 4 clear the write changes only the select and leaves both 17-bit
; prescalers alone (serial/uart.vhd:280-286). A write with bit 4 set would take
; bits 2:0 as the selected channel's prescaler MSB.
UART_SELECT_BIT:    equ 01000000b   ; bit 6: the channel, on a read
UART_SELECT_OURS:   equ 01000000b   ; UART1 - see set_uart_baudrate
UART_SELECT_OTHER:  equ 00000000b   ; UART0

/*
0x163B UART Frame
(R/W) (hard reset = 0x18)
bit 7 = 1 to immediately reset the Tx and Rx modules to idle and empty fifos
bit 6 = 1 to assert break on Tx (Tx = 0) when Tx reaches idle
bit 5 = 1 to enable hardware flow control *
bits 4:3 = number of bits in a frame
  11 = 8 bits
  10 = 7 bits
  01 = 6 bits
  00 = 5 bits
bit 2 = 1 to enable parity check
bit 1 = 0 for even parity, 1 for odd parity
bit 0 = 0 for one stop bit, 1 for two stop bits
* The esp ignores hardware flow control
* In joystick i/o mode only cts is available
*/
UART_FRAME:     equ 0x163b



; UART Status Bits:
UART_RX_FIFO_EMPTY: equ 0   ; 0=empty, 1=not empty
UART_RX_FIFO_OVERFLOW:  equ 2   ; 1=overflowed  ; (clears on read)
;UART_RX_FIFO_NEAR_FULL:  equ 3   ; 1=buffer is near full (3/4)
UART_TX_FULL:       equ 1   ; 1=Tx buffer is full
UART_TX_EMPTY:      equ 4   ; 1=Tx buffer is empty



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
; Default is to use a 100ms timeout.
; For return from the breakpoints a faster version is used,
; drain_rx_buffer_with_timeout.
; The timeout is passed via DE. Unit=53/28000=1.9us, i.e. 526 => 1ms.
; Changes:
;   A, BC, DE
;===========================================================================
drain_rx_buffer:
    ld de,53000 ; 100 ms
drain_rx_buffer_with_timeout:
    ld (.read_next_byte+1),de
	ld bc,UART_TX

.read_next_byte:
    ld de,53000 ; 100ms
    ; 53 T-states => 265*53/28000 = 0.5ms
.read_loop:
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    jr nz,.read_byte

    ; Wait
    dec de
    ld a,d
    or e
    jr nz,.read_loop

    ; No byte received since at least 100ms.
    ret

.read_byte:
    ; At least 1 byte received, read it
    inc b	; The low byte stays the same
    in a,(c)    ; read one byte
    dec b
    jr .read_next_byte


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

.loop:
    ; Check if byte available.
	ld a,HIGH UART_TX
	in a,(LOW UART_TX)	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    jr z,.loop   ; Wait until byte available

    ; Disable layer 2 read/write
    ld a,(backup.layer_2_port)
	and 11111010b	; Disable read/write only
    ld bc,LAYER_2_PORT
    out (c),a
    ret       ; RET if byte available


;===========================================================================
; Checks if a byte is available at the UART.
;
; This is also what the NMI poll asks, and it satisfies that on its own: one
; status read, no CALL below it, and it does not pop the RX FIFO - 0x133B is the
; status register where 0x143B is the data one.
;
; It borrows the UART channel select, and that is not defensive programming
; against the debugged program: it is this read being under-specified without
; it. See UART_SELECT_OURS above. The common path does not write - it reads the
; select, compares, and falls straight through - so only a program that has
; actually moved the pointer pays for the correction, and it gets its value back
; before the NMI returns.
;
; The read does clear the sticky RX overflow and framing flags
; (serial/uart.vhd:536-539). That is pre-existing - the idle loop already reads
; this register continuously - and mf_nmi_poll asks its prgm_state question
; first so that this is never touched while the debugger is using the link.
;
; Returns:
;   NZ = Byte available
;   Z = No byte available
; Changes:
;   AF
;===========================================================================
check_uart_byte_available:
    ; Is 0x133B about our channel?
	ld a,HIGH UART_SELECT
	in a,(LOW UART_SELECT)
    and UART_SELECT_BIT
    cp UART_SELECT_OURS
    jr nz,.borrow_select

	ld a,HIGH UART_TX
	in a,(LOW UART_TX)
	; Read status bits
    bit UART_RX_FIFO_EMPTY,a
    ret

.borrow_select:
    ; The debugged program owns the pointer and is still running, so this is a
    ; loan: point the pointer at our channel, read, and hand it straight back.
    push bc
    ld bc,UART_SELECT
    ld a,UART_SELECT_OURS
    out (c),a

	ld a,HIGH UART_TX
	in a,(LOW UART_TX)
    bit UART_RX_FIFO_EMPTY,a

    ; Neither "ld a,n" nor "out (c),a" touches the flags, so the verdict the
    ; caller reads survives the restore with no push/pop of AF. "in a,(n)" does
    ; not either, unlike "in r,(c)" - which is why the read can sit between the
    ; two writes.
    ld a,UART_SELECT_OTHER
    out (c),a
    pop bc
    ret

;===========================================================================
; Waits until an RX byte is available and returns it.
; Waits max. 100ms for the next byte, otherwise a timeout error is thrown.
; Returns:
;   A = the received byte.
; Changes:
;   BC, DE
;===========================================================================
read_uart_byte:
    ; Change border
.flash1:
    ld a,BLUE
    out (BORDER),a

    ; Wait on byte
    ld de,40000 ; => 100ms
	ld bc,UART_TX

    ; 68 T-states => 200*68/27Mhz = 0.5ms
.wait_loop:
	in a,(c)					; Read status bits
    bit UART_RX_FIFO_OVERFLOW,a
    jr nz,.rx_overflow
    bit UART_RX_FIFO_EMPTY,a
    jr nz,.byte_received
    dec de
    ld a,d
    or e
    jr nz,.wait_loop


    ; "Timeout"
.timeout:
    nop ; LOGPOINT read_uart_byte: ERROR=TIMEOUT
    jp rx_timeout   ; ASSERTION

.byte_received:
.flash2:
    ; Change border
    ld a,YELLOW
    out (BORDER),a

    ; At least 1 byte received, read it
    inc b	; The low byte stays the same
    in a,(c)
    ret


; Called if a UART RX buffer overflow occurred.
.rx_overflow: ; The receive timeout handler
    ld a,ERROR_RX_OVERFLOW
    jr rxtx_error


; Called if a UART RX timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
rx_timeout: ; The receive timeout handler
    ld a,ERROR_RX_TIMEOUT
rxtx_error:
    jp drain_main


; Called if a UART TX timeout occurs.
; As this could happen from everywhere the call stack is reset
; and then the cmd_loop is entered again.
tx_timeout: ; The receive timeout handler
    ld a,ERROR_TX_TIMEOUT
    jr rxtx_error



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
; Waits until the next byte can be sent over the UART.
; In Core 03.01.10 the uart tx buffer is 64 byte.
; If it takes too long an error is generated.
; Changes:
;  AF, BC (=PORT_UART_TX), E
;===========================================================================
wait_for_uart_tx:
    ; Send response back
    ld bc,UART_TX
    ; Check if ready for transmit
    ld e,0
.wait_tx:
    in a,(c)
    bit UART_TX_FULL,a
    ret z

    ;bit UART_TX_EMPTY,a
    ;ret nz

    dec e
    jr nz,.wait_tx

    nop ; LOGPOINT wait_for_uart_tx: ERROR=TIMEOUT
    jp tx_timeout   ; ASSERTION


;===========================================================================
; Waits until the UART TX buffer is completely empty.
; Is used to wait until the joy port can be switched.
; Changes:
;  AF, BC (=PORT_UART_TX), E
;===========================================================================
wait_for_uart_tx_empty:
    ; Send response back
    ld bc,UART_TX
    ; Check if ready for transmit
    ld de,64*256    ; max. 64 characters
    ld e,0
.wait_tx:
    in a,(c)
    bit UART_TX_EMPTY,a
    ret nz  ; 1 if empty
    dec de
    ld a,d
    or e
    jr nz,.wait_tx

    nop ; LOGPOINT wait_for_uart_tx_empty: ERROR=TIMEOUT
    jp tx_timeout   ; ASSERTION



;===========================================================================
; Sets the UART baud rate.
; Source code is taken from NDS, https://github.com/Ckirby101/NDS-NextDevSystem.
; See also https://dl.dropboxusercontent.com/s/a4c4k9fsh2aahga/UsingUART2andWIFI.txt?dl=0
; The baudrate timings depend on the video timings in register 0x11.
; They don't depend on video mode being 50 or 60 Hz.
; Sets also 8 bit mode.
;
; UART1 - the "Pi" UART - is used rather than UART0, and that is what makes
; asynchronous break possible over the cable. NR 0x0B bit 0 chooses which UART
; the joystick pin feeds, and with bit 0 CLEAR the same i/o mode holds the
; ESP-01's TX line idle and de-asserts its RTR (zxnext.vhd:3343, :3349). So a
; build that left i/o mode on with bit 0 clear - which is what buys the break -
; would sever the ESP for the whole session. Bit 0 SET leaves both those signals
; alone; what it costs instead is the Raspberry Pi header UART (:3344, :3350),
; which is far rarer on a real Next.
;
; THE SELECT MUST BE WRITTEN BEFORE THE FRAME AND PRESCALER REGISTERS, and that
; order is load bearing. 0x133B, 0x143B and 0x163B all act on whichever channel
; 0x153B bit 6 selects at the instant of the access - they are two independent
; sets of registers, not one (serial/uart.vhd:302-305 for the frame register,
; :350-376 for the read mux). Written the other way round the frame byte lands
; on UART0 and UART1 keeps whatever it had. It would LOOK correct, because
; 0x163B's documented default is 0x18 and that is exactly the value written
; here - but that default is restored only by i_reset_hard, which
; zxnext.vhd:3367 ties to the constant '0' ("hard_reset done by core load"), so
; no reset a program can cause ever puts it back and a program that had
; configured UART1 differently would leave the debugger at its frame settings.
;
; Returns:
;  -
; Changes:
;  A, BC, DE, HL
;===========================================================================
set_uart_baudrate:
    ; Select UART1 (bit 6) and clear prescaler MSB (bit 4 = write these bits).
    ; This comes FIRST: it is what makes the two writes below land on UART1.
    ld bc,UART_SELECT
	ld a,01010000b
	out	(c),a

    ; Set 8 bit
    ld bc,UART_FRAME
	ld a,00011000b   ; 8 bit
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
	ld bc,UART_RX ; Writing=set baudrate
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
;
; BIT 0 IS NOW SET ON BOTH PORTS, and it is what makes asynchronous break
; reachable here. It routes the joystick pin to UART1 instead of UART0
; (zxnext.vhd:3340-3341), which leaves the ESP-01's TX and RTR lines untouched
; (:3343, :3349, both conditioned on bit 0 = 0). That matters twice over: it is
; what lets restore_registers leave i/o mode ON across a resume on joy port 2 -
; see there - and it also means this routine no longer disturbs the ESP at all,
; where before it idled the module's TX line for as long as the debugger held
; the machine, on either port.
;
; Only joy port 2 gets asynchronous break, and the asymmetry is deliberate. The
; enable is global and the mode field names exactly one connector
; (zxnext.vhd:3536, :3538), so the cable and a real joystick cannot share a
; port; keeping port 1's old behaviour is what leaves that connector free for
; the debugged program's own joystick.
;
; Parameters:
;  uart_joyport_selection:
;     0x0=00b => no joystick port used
;     0x1=01b => joyport 1
;     0x2=10b => joyport 2
; Changed:
;  AF, BC, HL
;===========================================================================
set_uart_joystick:
    ; Reclaim the UART channel select before anything uses the link, and without
    ; that the guard in check_uart_byte_available would be half a fix:
    ; set_uart_baudrate points 0x153B at our channel exactly once, when MAIN is
    ; first entered, and nothing has re-established it since. So a program that
    ; moved the pointer and then stopped - at a breakpoint, on the button, or
    ; through the poll's own break-in - would hand the debugger a link whose
    ; every read and write went to the OTHER UART, and the session would be mute
    ; rather than merely unbreakable. This is the right single place: all three
    ; entries into the debugger come through here (main.asm, mf.asm,
    ; breakpoints.asm) and none of them has touched the link yet.
    ;
    ; It does NOT put the debugged program's selection back on resume. That
    ; value belongs with the other break-time captures in backup.*, not here,
    ; because this routine also runs when the debugger is ALREADY executing
    ; (main.asm's path through drain_main and cmd_close) where the value it
    ; would read is its own. A program using the other UART must re-select after
    ; a break.
    ld bc,UART_SELECT
    ld a,UART_SELECT_OURS
    out (c),a

    ; Core 3.01.10
    ld a,(uart_joyport_selection)
    dec a
    jr nz,.joy_port_cont
    ; Joy port 1 selected
    nextreg REG_JOYSTICK_IO_MODE,10100001b  ; Left joy port, UART1
    ret
.joy_port_cont:
    dec a
    jr nz,.joy_port_none
    ; Joy port 2 selected
    nextreg REG_JOYSTICK_IO_MODE,10110001b  ; Right joy port, UART1
    ret
.joy_port_none:
    ; No joy port selected
    nextreg REG_JOYSTICK_IO_MODE,0  ; Disable joy IO mode
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
