# Thoughts

I collect here some thoughts that may or may not be relevant anymore.
Anyhow I want to keep them somewhere even if they did not make it into the final SW.

E.g. there was also a ROM only and divmmc version available before I switched to Multiface.
I kept the thoughts/ideas here.


## ROM vs. DivMMC

Putting the debug code into the ROM area is straightforward.
The other way is to use DivMMC which can automatically be paged in if e.g. a RST, i.e. address 0x0000 is executed. (Unfortunately delayed after the next instruction!)
If ROM would be used a special code would be required at 0x0000 which switches the banks.
I.e. at address 0x0000 about 20 bytes of code would be unusable for the debugged program.
With DivMMC this area can be used by the debugged program.
Only restrictions (but this is true for ROM as well), the debugged program is not allowed to
- do a RST (this is reserved for breakpoints)
- do a CALL 0x0000 (same reason)

Furthermore using DivMMC has the advantage that no memory bank is used, just the one for DivMMC. Obviously no DivMMC program could be debugged.

I guess I start with a ROM version without banking and later add the DivMMC version.


References:
https://velesoft.speccy.cz/zx/divide/divide-memory.htm
https://velesoft.speccy.cz/zx/divide/doc/pgm_model-en.txt
https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/ports.txt#L370


# ROM


| Range         | Slot | Debugged program | Debugger active                           |
|---------------|------|------------------|-------------------------------------------|
| 0x0000-0x1FFF | 0    | USED_ROM0_BANK*  | USED_MAIN_SLOT  |
| 0x2000-0xBFFF | 1-5  | -                | - |
| 0xC000-0xDFFF | 6 (SWAP_SLOT) | -       | X |
| 0xE000-0xFFFF | 7    | -                | - |

Notes:
- USED_ROM0_BANK:
  - The debugged program uses USED_ROM0_BANK at address 0x0000. USED_ROM0_BANK is modified to work with the debugger.
  - Alternatively the debugged program might page in any other page with similar modifications.
- SWAP_SLOT: This slot is used by the debugger temporarily to page in other banks, normally the bank at slot 0 that is used by the debugged program. E.g. in case a memory read/write to that bank is required.

When the debugger is active in occupies slot 0 with is program code and data.
When the debugger is entered the currently active bank in slot 0 is saved (slot_backup.slot0).
When the debugger is left this slot is restored.
All other slots are the same as the ones of the debugged program.
SWAP_SLOT is only used temporarily, i.e. within a cmd_... after any command is executed the SWAP_SLOT is restored.

Commands that deal with memory will handle range 0x0000-0x1FFF (slot 0) especially. All other memory is directly read/set. But for range 0x0000-0x1FFF the slot (slot_backup.slot0) is instead paged into SWAP_SLOT temporarily.
The commands are:
cmd_read_mem, cmd_write_mem, cmd_set_breakpoints, cmd_restore_mem.

The cmd_write_bank makes use of SWAP_SLOT, too.

cmd_get_slots will read the banks for slots 1-7 from the ZX Next registers. slot 0 is simply read from the slot_backup.slot0.

cmd_set_slot will set the banks for slots 1-7 directly to the ZX Next registers. slot 0 is simply written to slot_backup.slot0.




# DivMMC

See also https://velesoft.speccy.cz/zx/divide/divide-memory.htm .

**Does not work (as of core v3.1.5): The automapping does not work, seems that mapping only works for the NMI button.**
**There is another problem with DivMMC: It is required that no interrupt occurs while the divmmc memory is swapped in. Therefore the interrupt recognition has to take place beforehand. I.e. the automapping should not occur at address 0x0000. Instead at address 0x0000 the interrupt recognition takes place and then a jump to another entrypoint is required. Furthermore the DivMMC requires 2 banks (1 program, 1 data) compared to the ROM solution. So I think I stick to ROM.**

RST is used for breakpoints. With divMMC a trap can be enabled at address 0x0000.
I.e. once a breakpoint is hit the DivMMC memory will be enabled automatically.
Unfortunately this does not happen immediately but only after one instruction fetch from the original memory paged into slot 0 (normally the ROM).
If the debugged program has put in here something else than the ROM the instruction could be everything.
But even with the ROM the first instruction would be "DI", giving me no chance to check the interrupt enable state to restore it later.

I.e. it is necessary to occupy at least a few bytes in the slot 0 area.

The pseudo code would be something like this:
~~~asm
	ORG 0x0000
	Store current interrupt state (e.g. LD A,I)
	DI
	Jump to main
~~~
~~~asm
	ORG 0x000?-0x3FFF (somewhere in the DivMMC or ROM area)
main:
	Store the registers
	Setup stack
.loop:
	Wait on command
	Execute command
	Jump to .loop
~~~

Whenever a CMD_CONTINUE is executed:
~~~asm
cmd_continue:
	Restore registers
	Restore interrupt state
	RET  ; return from RST
~~~

I.e. the debugged program must make sure that a few bytes are occupied in slot 0 at address 0.
E.g.
~~~
	ORG 0x0000
	push af
	ld a,i
    jp pe,go_on     ; IFF was 1 (interrupts enabled)

	; if P/V read "0", try a 2nd time
    ld a,i

go_on:
	di
    push af	; Store P/V flag
	jp main
~~~



Problem:
- The original idea was to use RST for the breakpoints. In the original ROM there is a DI located at 0x0000. Unfortunately I think I need to keep it there because programs may use it as relative backwards jump when using IM2. On the other hand I cannot execute DI first because I need to know the state of the interrupt beforehand.
Also if I would use nextreg 0x22 to disable the interrupts, I cannot leave DI at 0x0000 because I wouldn't know how to restore it.
So either a different RST address or disallow this special interrupt usage.


## Initializing the DivMMC - Memory Map

When paged in the memory area 0x0000-0x1FFF cannot be written.
Only 0x2000-0x3FFF can be written.
DivMMC bank 3 is used for the program. It is first switch with conmem set to area 0x2000-0x3FFF. Then the program is copied there.
Afterwards the memory area is paged in with mapram at address 0x0000-0x1FFF.
As this area is not writable all data needs to located at 0x2000-0x3FFF.


| Range         | Slot | Debugged program | Debugger active                           | NEX file |
|---------------|------|------------------|-------------------------------------------|----------|
| 0x0000-0x1FFF | 0    | USED_ROM0_BANK*  | DivMMC Bank 3 (read-only), debugger code  |
| 0x2000-0x3FFF | 1    | -                | DivMMC Bank 0 (read/write), debugger data |
| 0x4000-0x5FFF | 2    | -                | - |
| 0x6000-0x7FFF | 3    | -                | - |
| 0x8000-0x9FFF | 4    | -                | - |
| 0xA000-0xBFFF | 5    | - | - | Prequel code, i.e. copies the debug program to the right banks/DivMMC memory. |
| 0xC000-0xDFFF | 6 (SWAP_SLOT0) | -  | Used to page in the bank of slot 0 for read/write |
| 0xE000-0xFFFF | 7 (SWAP_SLOT1) | -  | Used to page in the bank of slot 1 for read/write |
Notes:
- The USED_ROM0_BANK is a copy of the ROM at address 0x0000-0x1FFF. The only change is that the memory around address 0x0000 and 0x0066 is modified to cooperate with the code in the DivMMC memory.
- The debugged program may switch in a another bank here if the bank contains the same code (as for the modifications above).


dezogif NEX-file bank usage:
| Bank             | Compiled for  | Description   | Destination   |
|------------------|---------------|---------------|---------------|
| LOADED_BANK (92) | 0x0000-0x1FFF | Debugger code | DivMMC Bank 3 |
| -                | 0x2000-0x3FFF | Debugger data | DivMMC Bank 0 |
| 5 (standard)     | 0xA000-0xBFFF | Prequel code, i.e. copies the debug program to the right banks/DivMMC memory. | Not used after initialization. |


# Memory Bank Switching - DivMMC

The used DivMMC memory is paged in either if the CONMEM bit is set or if CONMEM is off and MAPRAM is set, if automapping occurs.
Automapping is the memory switching if an instruction fetch occurs on certain addresses (e.g. 0x0000 or 0x0066).

So CONMEM is used only during initialization. Afterwards only automapping is used.
Returning from automapping is also not straight forward. It is done by executing an instruction in the so-called **off-area** 0x1FF8-0x1FFF.

I.e. the debugger is entered by jump (RST) to address 0x0000 (or by DRIVE button, jump to 0x0066) and it is left when it jumps to 0x1FF8.

These code areas are existing 2 times: Once in DivMMC bank 3 and once in the bank switched to slot 0.
(Note: at least the first byte of each entry point needs to exist twice.)


Note: As long as automapping is not supported in the ZX Next core the idea is to manual map in the DivMMC memory.
I.e. CONMEM is set once the debugger is entered (at address 0x0000) and is reset when the debugger is left.
As CONMEM maps in EPROM at 0x0000-0x1FFF it is required that in slot 0/0x000 there is a JP 0x2000.
And the actual CONMEM switching takes place at 0x2000-0x3FFF as this is RAM.
Program code and data will reside here.

If using slot/bank paging one memory bank would have to be used but the advantage is that only one slot has to be occupied (i.e. only around 0x0000 instead of 0x0000 and 0x2000).




# Measurements

I did a few measurements through the Joystick UART interface.

Loopback without ZXNext (directly at the USB serial device) and with ZXNext.

Adafruit Part Number 954, Joy 2:

| baud      | packet size | Bytes/ms wo ZXN | Bytes/ms with ZXN |
|-----------|-------------|-----------------|-------------------|
| 230400    | 2000        | 21              | 21                |
| 230400    | 200         | 16.5            | 15.9              |
| 230400    | 20          | 4.79            | 4.68              |
| 230400    | 10          | 2.71            | 2.65              |
| 460800    | 2000        | 40              | 40                |
| 460800    | 200         | 25.4            | 25.2              |
| 460800    | 20          | 5.51            | 5.42              |
| 460800    | 10          | 2.935           | 2.915             |
| 614400    | 2000        | 52              | 51                |
| 614400    | 200         | 30.1            | 29.7              |
| 614400    | 20          | 5.72            | 5.63              |
| 614400    | 10          | 3.025           | 2.955             |
| 921600    | 2000        | 67              | 66                |
| 921600    | 200         | 34.8            | 34.2              |
| 921600    | 20          | 5.9             | 5.81              |
| 921600    | 10          | 3.08            | 3.05              |
| 1228800   | 2000        | 83              | -                 |
| 1228800   | 200         | 38.6            | -                 |
| 1228800   | 20          | 5.87            | -                 |
| 1228800   | 10          | 3.125           | -                 |
| 1958400   | 2000        | 140             | -                 |
| 1958400   | 200         | 48.5            | -                 |
| 1958400   | 20          | 6.26            | -                 |
| 1958400   | 10          | 3.2             | -                 |



FTDI chip, Joy 2:

| baud      | packet size | Bytes/ms wo ZXN | Bytes/ms with ZXN |
|-----------|-------------|-----------------|-------------------|
| 921600    | 2000        | 52.99           | -                 |
| 921600    | 1500        | 45.9            | 38.65             |
| 921600    | 200         | 11              | 10.59             |
| 921600    | 20          | 1.25            | 1.25              |
| 921600    | 10          | 0.625           | 0.63              |
| 2000000   | 2000        | 76.99           | -                 |
| 2000000   | 200         | 11.79           | -                 |
| 2000000   | 20          | 1.25            | -                 |
| 2000000   | 10          | 0.625           | -                 |


## Direct comparison:

Adafruit:
| baud      | packet size | Bytes/ms direct loopback |
|-----------|-------------|-----------------|
| 921600    | 2000        | 67              |
| 921600    | 200         | 34.8            |
| 921600    | 20          | 5.9             |
| 921600    | 10          | 3.08            |

FTDI-Chip:
| baud      | packet size | Bytes/ms direct loopback |
|-----------|-------------|-----------------|
| 921600    | 2000        | 52.99           |
| 921600    | 200         | 11              |
| 921600    | 20          | 1.25            |
| 921600    | 10          | 0.625           |
| 2000000   | 2000        | 76.99           |
| 2000000   | 200         | 11.79           |
| 2000000   | 20          | 1.25            |
| 2000000   | 10          | 0.625           |

FTDI slower for small packet sizes.
