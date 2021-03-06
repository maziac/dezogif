# dezogif - ZX Next Interface

For implementing the ZX Next Remote in [DeZog](https://github.com/maziac/DeZog) it is necessary to implement a piece of SW, a counterpart, that is running on the ZX Next and communicates with DeZog.

For debugging there is no specific support on the ZX Next so everything, breakpoints, stepping, etc. is done in SW.

The protocol used is the [DZRP](https://github.com/maziac/DeZog/blob/master/design/DeZogProtocol.md). Not all commands care working on the Next. Especially the commands to readout the sprites data are not available. 
It is also not possible to get any coverage or history information from the Next.

Furthermore one of the main problems is that the dezogif program itself has to be present in the Z80/ZX Spectrum program area. Getting in the way we the debugged program. Therefore dezogif has to be paged in/out when ever necessary.

This document deals with the main problems/solutions and design decisions.


# Communication

The ZX Next has a UART, e.g. to connect to Wifi.
It is available at the WIFI connector CN9.

It is possible to connect a serial/USB adapter cable to it.
The UART can be programmed via port registers 0x133B and 0x143B.
The baudrate is connected to the video timing. This needs to be taken into account when setting the baudrate.
Unfortunately there is **no interrupt connected to the UART**. I.e. it is required to poll it.

It is also possible to put the UART on pins 7 (Tx) and 9 (Rx) of one of the joystick ports. I.e. no need for soldering or even to open the case.

When a joy port is used for UART the problem is the conflict with the joystick.
A game would usually initialize the use for a joystick, i.e. cutting off the communication with the PC.
When this happens the ZX Next transmits endless zeroes to the PC.
Therefore the DZRP protocal was extended by one byte which is sent as first byte of a message (only in direction from ZX Next to PC).
This is the MESSAGE_START_BYTE (0xA5). DeZog will wait on this byte before it recognizes messages coming from the Next.


There are basically 2 states:
- the debugged program is running
- the debugged program is stopped

When the debugged program is running no communication takes place and the joy ports are restored for joystick usage.
When the debugged program is stopped the dezogif takes over and configures the joy port for UART communication.

This implies that it is not possible to stop the debugged program from DeZog.
to stop it you need to press the yellow NMI button.

When the NMI button was pressed dezogif send a DZRP pause notification to DeZog to notify about the state change. Then dezogif will wait for further requests from DeZog, e.g. to read register values etc.

The program is started when DeZog sends a DZRP continue request.



# ZX Next SW - dezogif

The ZX Next requires a program to be executed on the Next to communicate with the PC with DeZog.
The SW has the following main tasks:
- communication with DeZog
- read/write registers
- break the execution
- set SW breakpoints


## SW Breakpoints

When a breakpoint is set the opcode at the breakpoint address is saved and instead a one byte opcode RST is added.

So, at the RST position there is code located which jumps into the ddezogif-program and informs DeZog via UART, then waits on input from DeZog.

This is the easy part.

Then, if DeZog sends a 'continue' command the original breakpoint location is re-stored with the original opcode and the debug-program jumps here.

Now it becomes hairy. Normal program execution would work but what if the program passes the same location again. It should stop there again but instead it does nothing because the breakpoint (the RST opcode) was not restored.

So we need a way to execute the one instruction at the breakpoint location and afterwards restore the breakpoint.

This is done with the help from DeZog.
DeZog analyzes the current instructions and sets one or two temporary breakpoints.
For non-branching instructions one breakpoint right after the instruction would already do.
For the branching (and conditional branching) instruction we need also the branch location and set the 2nd breakpoint to it.

So DeZog sets 2 temporary breakpoints at exch DZRP continue command. One at the breakpoint address + len and one at the branch address.

So, after our original breakpoint was hit the debug-program restores the original opcode and then adds the 2 temporary artificial breakpoints.
The debug-program then jumps to the breakpoint location and after the instruction is executed immediately the next RST is done (because of the temporary breakpoints).
Now dezogif removes the temporary breakpoints and restores the original breakpoints and then continues.

Complicated but working.




## SW Breakpoints - Even More Complex

In order to reduce complexity on the ZX Next SW side many of the breakpoint functionality is moved to DeZog.

This reduces the need especially for memory at the ZX next part.
following functionality is done by DeZog:
- Calculation of the length of the instruction
- Storing of the original opcode
- Taking care of temporary breakpoints
- State management to decide if a breakpoint was hit and if we need to restore the original breakpoint and later restore the breakpoint itself.

No memory for tables or code is required on ZX side to:
- calculate the length of an instruction
- store any breakpoints, i.e. there are about 20000 breakpoints possible (roughly 65536, which is the max size of the message, divided by 3 bytes per breakpoint)

Here is a sequence chart which helps to explain:

~~~puml
hide footbox
title Continue
participant dezog as "DeZog"
participant zxnext as "ZXNext"

== Add breakpoint ==

note over dezog: add breakpoint\nto list
note over zxnext: No communication with ZXNext
'dezog -> zxnext: CMD_READ_MEM(bp_address)
'dezog <-- zxnext
'note over dezog: Store opcode along\nbreakpoint
'dezog -> zxnext: CMD_ADD_BREAKPOINT(bp_address)
'note over zxnext: Overwrite opcode with RST
...

== Continue ==
	note over dezog: Set all breakpoints
	dezog -> zxnext: CMD_SET_BREAKPOINTS(bp_addresses)
	note over zxnext: Set a RST for every address
	dezog <-- zxnext: List of opcodes
	note over dezog: Store the opcodes\nalong with the addresses

	note over dezog: Calculate two bp\naddresses for stepping
	dezog -> zxnext: CMD_CONTINUE(tmp_bp_addr1, tmp_bp_addr2)
	note over zxnext: Exchange the opcodes at\nthe both addresses\nand store them
	dezog <-- zxnext: Response
	note over zxnext: Breakpoint hit:\nRestore the 2 opcodes
	dezog <- zxnext: NTF_PAUSE(address)

	note over dezog: Recall addresses\nand opcodes
	dezog -> zxnext: CMD_RESTORE_MEM(addresses, opcodes)
	note over zxnext: Restores the memory
	dezog <-- zxnext
...

== Stop at breakpoint (generally) ==
dezog <- zxnext: NTF_PAUSE(bp_address)
note over dezog: If BREAK_REASON==HIT then\nset breakedAddress
...

== Continue (from breakpoint) ==

alt oldBreakedAddress != undefined
	note over dezog: Create list of bp addresses\nwithout the breakedAddress
	dezog -> zxnext: CMD_SET_BREAKPOINTS(bp_addresses)
	note over zxnext: Overwrites the\nRST (breakpoint),\ni.e. restores the opcode
	dezog <-- zxnext: List of opcodes

	note over dezog: Calculate two bp\naddresses for stepping
	dezog -> zxnext: CMD_CONTINUE(tmp_bp_addr1, tmp_bp_addr2)
	note over zxnext: Exchange the opcodes at\nthe both addresses\nand store them
	dezog <-- zxnext
	note over zxnext: Breakpoint hit:\nRestore the 2 opcodes
	dezog <- zxnext: NTF_PAUSE(address)

	dezog -> zxnext: CMD_SET_BREAKPOINTS(breakedAddress)
	note over zxnext: Restores the one\nmemory location
end

dezog -> zxnext: CMD_CONTINUE(next_bp_addr1, next_bp_addr2)
dezog <-- zxnext
~~~



## Breakpoint conditions

After a breakpoint is hit it needs to be checked if the condition is true.

Conditions like
```(A > 3) AND (PEEKW(SP) != PC)```
should be allowed.

I don't need to take care inside the dezogif program. DeZog taked care of the conditions without help of the Remote.

I.e. if a breakpoint with a condition is hit for dezogif it is like a normal, unconditional breakpoint. So it pauses.
DeZog will then check the condition. If not true it will simply continue the execution.


## Reverse Debugging

Real reverse debugging, i.e. collecting a trace of instruction on the ZX Next, is not possible because this would run far too slow.

But still the lite history will work in DeZog.


## Code Coverage

Is not possible or would be far to slow in SW.

So code coverage is not available.



## Multiface

[Multiface](https://k1.spdns.de/Vintage/Sinclair/82/Peripherals/Multiface%20I%2C%20128%2C%20and%20%2B3%20(Romantic%20Robot)/) and the NMI interrupt is used for pausing a running program.
On pressing the NMI button the Multiface memory is swapped in and the NMI at 0x0066 is executed.
It can be swapped out with
~~~
IN A,($bf): pages the MF ROM/RAM out
IN A,($3f): pages the MF ROM/RAM back in
OUT ($3f),A : IN A,($bf): The MF is again hidden and can only be paged back by pressing the NMI button.
~~~

MF is not used before the NMI button is used and cannot be accessed otherwise than giving control to MF via the NMI button.
I.e. the Multiface ROM/RAM cannot be written by a program. The code need to be included in the MF file on SD card, so it is read during boot (enNextMf.rom).

The MF M1 button has to be reactivated before the NMI ISR is left by paging out (or hiding) the MF. (I.e. an NMI cannot interrupt an NMI because the button is deactivated.)

So the plan is:
1. Put NMI and all dezog debugger code in enNextMf.rom
2. To activate user has to press NMI button
3. The SW will copy itself from MF ROM to a memory bank
4. The SW is continued in the memory bank and can accept a debugged program through UART
5. From here normal execution
6. If the NMI button is pressed again
6.a If the debugged program is running: the NMI code will branch into the bank memory and send a pause notification.
6.b If the debugged program is not running: the NMI code will return without action.

If the "Symbol Shift" (or CTRL) key is pressed during the user presses the NMI execution continues at step 3.

MF ROM is 0x0000-0x1FFF. MF RAM is 0x2000-0x3FFF.



# Memory Bank Switching - Multiface

The table below shows the bank switching in case a breakpoint is hit:

|Slot/L2| Running | BP hit | Enter  | Enter  | Dbg loop | Dbg exec | Dbg loop | Exit    | Running |
|:------|:--------|:-------|:-------|:-------|:---------|:---------|:---------|:--------|:--------|
| 0     | **XM**  |**MAIN**|**MAIN**|**MAIN**| XM       | XM       | XM       |**XM**   | **XM**  |
| 1     | **X**   | X      | X      | X      | X        | X        | X        | X       | **X**   |
| 2-5   | **X**   | X      | X      | X      | X        | X        | X        | X       | **X**   |
| 6     | **X**   | X      | X      | X      | X        | SWAP     | X        | X       | **X**   |
| 7     | **X**   | X      | X      |**MAIN**|**MAIN**  |**MAIN**  |**MAIN**  |**MAIN** | **X**   |
| L2 RW | 0/1     | 0/1    | 0      | 0      | 0        | 0        | 0        | 0/1     | 0/1     |
| PC    | 0-7     | 0      | 0      | 0->7   | 7        | 7        | 7        | 7->0    | 0-7     |
| M1 enabled | 1  | 1->0   | 0      | 0      | 0        | 0        | 0        | 0->1    | 0-7     |

Slot/Banks/L2:
X = The bank used by the debugged program
XM = The modified (alt) ROM or the (modified) bank of the debugged program for slot 0
MAIN = The main debugger program
SWAP = Temporary swap space for the debugger program. Used e.g. to page in a different bank to read/Write the memory.
L2 RW = Layer 2 read/write enable.
PC = Slot used for program execution. (Also bold)
M1 enabled = 1 if the M1 key is enabled. I.e. the NMI is only allowed during debugged program execution. While the debugger is runnign it is disabled.

States:
Running = The debugged program being run.
BP hit = A breakpoint is hit. The program in M switches bank in slot 0 to MAIN.
Enter = Transition into the debug loop.
Dbg loop = The debugger loop. The debugger waits for commands from DeZog.
Dbg exec = The debugger executes a command from DeZog.
Exit = The debugger is left.

Notes:
- The SP of the debugged program can only be used in the code running in M. The SP might be placed inside M so it is not safe to access it while MAIN is paged in slot 0. It can also not be accessed from MAIN being paged in to slot 7 as SP might be in slot 7.
- The data of MAIN can be accessed from either slot: slot 0 or slot 7. If accessed from slot 0 than the addresses need to be subtracted by 0xE000.
- It's not posisble to directly switch from M into Main/slot 7 because the subroutine would become too large by a few bytes. The code would reach into area 0x0074 which (for the ROM) is occupied by used ROM code.



This table shows the bank switching in case th M1 MF NMI (yellow) button is pressed:

|Slot/L2| Running | NMI/M1   | Enter    | RETN   | Dbg loop | Dbg exec | Dbg loop | Exit    | Running |
|:------|:--------|:---------|:---------|:-------|:---------|:---------|:---------|:--------|:--------|
| 0     | **XM**  |**MF ROM**|**MF ROM**| XM     | XM       | XM       | XM       |**XM**   | **XM**  |
| 1     | **X**   | MF RAM   | MF RAM   | X      | X        | X        | X        | X       | **X**   |
| 2-5   | **X**   | X        | X        | X      | X        | X        | X        | X       | **X**   |
| 6     | **X**   | X        | X        | X      | X        | SWAP     | X        | X       | **X**   |
| 7     | **X**   | X        | **MAIN** |**MAIN**|**MAIN**  |**MAIN**  |**MAIN**  |**MAIN** | **X**   |
| L2 RW | 0/1     | 0/1      | 0        | 0      | 0        | 0        | 0        | 0/1     | 0/1     |
| PC    | 0-7     | 0        | 0->7     | 7      | 7        | 7        | 7        | 7->0    | 0-7     |
| M1 enabled | 1  | 1->0     | 0        | 0      | 0        | 0        | 0        | 0->1    | 0-7     |

The debug loop primarily executes the CMD_PAUSE and then stays in the debug loop until DeZog sends a CMD_CONTINUE.


## SP

When entering the debugger the SP can point to any memory location.
E.g. even slot7 or slot 0.
If the SP points to memory in the same area as the debugger code is running the wrong values could be pushed/popped.

So, to access the debugged programs stack it is necessary to map the memory area around SP into an unused bank and get/set the values there.

Actually 2 banks/slots are required as the stack could reach over 2 slots. Even one SP address could be on the border so that the low byte is in slot X and the high byte is in slot x+1.




# AltROM

See https://gitlab.com/SpectrumNext/ZX_Spectrum_Next_FPGA/-/blob/master/cores/zxnext/nextreg.txt#L777 .

The Alternate ROM is used so I don't need to copy the ROM, modify/copy it to another bank.
I could instead copy/modify the ROM to the AltROM.

The advantage is that the ROM is switched in via bank 0xFF like the normal ROM.



## Setting Breakpoints

The debugger program resides in the ROM area at 0xA000-0xFFFF.
If a breakpoint should be set in this area it would be set in the debugger program.
Setting a breakpoint involves to exchange the opcode at the breakpoint address with RST opcode. I.e. a memory read and write.

To do this the debugged program memory bank need to be paged in another slot (slot 6). Then the memory is read and set. Afterwards the original bank paging is restored.


# Reading/Writing Memory

The problem is the same as for breakpoints. It's a little bit more tricky because whole memory areas are involved that can also overlap the bank boundaries. So the memory reading/writing need to be partitioned.
But the principle is the same.


# Stack

As soon as the dezogif program gets control the maskable interrupts are disabled and restored when the debugged program gets back control.
I.e. the normal (maskable) interrupt cannot change the stack.

This is different for NMI. An NMI can occur anytime and is "non-maskable" from Z80 perspective.

Here is an example what could happen if the NMI wouldn't be disabled:
~~~
	push bc
	inc sp
	inc sp
	do something
	dec sp
	dec sp
	pop bc
~~~
If an NMI occurs during or after increasing the SP the PC is written to the stack, overwriting the previous value:
~~~
	push bc
	inc sp
	inc sp
NMI--> pushes the PC onto the stack
	do something
	dec sp
	dec sp
	pop bc
~~~
In the example above the pushed BC value is lost and exchanged with the PC value.

This is true for the debugged program aswell: If an NMI occurs during stack manipulation the program might malfunction. Here there is nothing that can be done about it in the debugger.

For the debugged program this also applies
- for maskable interrupts if the interrupts are not disabled (but this is a general failure of the program)
- for SW breakpoints

For SW breakpoints a RST is used. I.e. when a breakpoint is "hit" the PC is also placed on the stack.
Thus, if a breakpoint is placed at a location where the SP has been manipulated the stack is corrupted as well.
~~~
		push bc
		inc sp
BP->	inc sp
BP->	do something
BP->	...
BP->	...
BP->	dec sp
BP->	dec sp
	pop bc
~~~
Placing a BP at any of the above locations will destroy the pushed BC value if the BP is hit.

The user has to take care not to place breakpoints at these locations.

