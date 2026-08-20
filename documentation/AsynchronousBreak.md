# Pausing a running program from the PC

**What makes a program breakable from DeZog's Pause button, what it costs, and
when it will not work.**

**Most programs need no change at all** — the debugger installs what is needed
when a debug session opens. Read "What to add to the program" below only if your
program uses the Copper, or if you want to turn the feature off.


## What it gives you

Without it, once Continue is pressed there are two ways back into the debugger:
the program reaches a breakpoint, or somebody presses the **M1 button** on the
Next.

With it, **Pause in VS Code stops the program** wherever it is, and breakpoints
and memory can be inspected without touching the machine. For a program that
does not use the Copper this costs nothing but the cable and the port selection
below.

The debugger's half needs the serial cable on **joy port 2**. The stub's own
screen says which you have, on the line under the port selection: `Async break:
ready` or `Async break: needs Joy 2`.


## What to add to the program

**Nothing at all, if your program does not use the Copper.** The debugger
installs the two-instruction Copper list itself, when a debug session opens. An
ordinary program is breakable from the PC with no source change whatsoever.

That works for one reason, and it is worth knowing because the rest of this page
follows from it: **the Copper has its own instruction memory and keeps executing
after the program that wrote the list has gone.** So the debugger can install it
as a client attaches — before your program has even been pushed to the machine,
let alone run — and it is still running once your program is.

**If your program uses the Copper, add the two instructions to your own list.**
The debugger cannot merge them into a list it cannot read: the Copper's
instruction list is **write-only** — the instruction RAMs discard their CPU-side
read output and NR `0x60`/`0x63` have no read decode — so nothing can save what
was there, or add to it. Your program installs its own list when it runs, which
overwrites the debugger's; carrying the two instructions is what keeps the break
working across that.

The **"A" key** on the debugger's own screen turns the whole thing off, for a
program that wants the frame back or would rather the debugger left the Copper
alone. The screen's row 14 says which it is: `A = Async break on` or `off`.

### The two instructions

**Forty-four bytes, once, at the start.** Two Copper instructions raise the
Multiface NMI once per frame; the debugger's handler polls the debug link on
each one and returns immediately unless the PC has sent something.

```asm
; --- asynchronous break: let the PC stop this program -------------------
; Two Copper instructions raise the Multiface NMI once per frame. The
; debugger's handler polls the debug link and returns immediately unless
; the PC has said something. Remove it (or assemble it out) for a release
; build.

BREAK_LINE:     equ 100         ; any raster line; see "choosing a line"

    ; NR 0x06 bit 3 gates EVERY Multiface NMI source, and its power-on
    ; value is 0. NextZXOS leaves it set, so these seven bytes are
    ; insurance against what the firmware happened to leave behind.
    ld bc,0x243B
    ld a,0x06
    out (c),a
    ld bc,0x253B
    in a,(c)
    or 0x08
    out (c),a

    ; Stop the Copper and put its write pointer at index 0.
    nextreg 0x62,0              ; control: stopped
    nextreg 0x61,0              ; address LSB = 0

    ; The list, MSB first:
    ;   WAIT line,0   = 0x8000 | (hpos<<9) | line
    ;   MOVE $02,$08  -> NR 0x02 bit 3, the Multiface NMI
    nextreg 0x60,(0x8000 + BREAK_LINE) >> 8
    nextreg 0x60,(0x8000 + BREAK_LINE) & 0xFF
    nextreg 0x60,0x02
    nextreg 0x60,0x08

    ; Run it from index 0, looping.
    nextreg 0x62,01000000b
; ------------------------------------------------------------------------
```

**Twenty-eight bytes** without the NR `0x06` block. NextZXOS leaves that bit
set, so the block is only needed by a program that writes NR `0x06` itself.

The encoding is from the FPGA source (`device/copper.vhd:91-104`): `WAIT` is
bit 15 = 1, bits 14:9 = hpos, bits 8:0 = line, and it fires when
`vcount = line` and `hcount >= hpos*8 + 12`; `MOVE` is bit 15 = 0, bits 14:8 =
the NextREG number, bits 7:0 = the value.

### If the program already uses the Copper

Add `WAIT <line>,0` and `MOVE $02,$08` **to the existing list**, at any raster
position, and leave the rest of it alone. That is all the debugger needs — it
does not care where in the list the two instructions sit or what else the list
does.

### Choosing a line

Any line works. `100` is mid-screen and well clear of the border. The NMI
arrives at that raster position every frame, so a program with raster-timed
effects should put the break somewhere it does not care about: the interruption
is short, but it is not free and it is always in the same place.

### Turning it off

Assemble it out for release. It is a contiguous block with no other dependency,
so an `IFDEF DEBUG` around it is enough; nothing else in the program changes.


## What it costs while it is in

The handler's decline path — the common case, once a frame, with nothing on the
link — is roughly **1300 T-states**: about **0.23%** of a frame at 28MHz and
about **1.8%** of one at 3.5MHz, which is what a contended-memory, tape or
beeper program pays.

That figure was measured in an emulator, against the equivalent code in a fork
of this project, with a fixed-length counting loop and two builds one assembler
constant apart. Read it as an order of magnitude rather than as a specification
for this branch, and note what it does **not** include: the fixture brought no
debugger up, so the handler declined at its magic-number check and never reached
the link poll at all. A real session pays that plus the `prgm_state` test and
the status read, of the order of another hundred T-states by instruction timing.
Nothing has measured any of it on real hardware.

Plus the 44 bytes, plus the Copper list, plus the raster line.

The poll does **not** change the machine's clock speed. It runs at whatever
clock the program is running at.


## If your program uses the other UART

It may, and the break still works. One thing to know:

**The debugger selects its own UART channel whenever it takes control, and does
not give your selection back.** So after any break — a breakpoint, the M1
button, or a Pause — port `0x153B` points at the debugger's channel, and your
program's next UART access goes to the wrong one unless it selects again.
**Select your channel where you use it rather than once at start-up** and the
question does not arise.

While your program is *running* the pointer is yours: the poll borrows it for a
single status read and restores it before the interrupt returns, so a program
that never breaks never notices.


## When it will not work

Seven states, in rough order of how likely they are to be met. None of them
damages anything: in each, Pause simply does nothing until the state passes, and
the M1 button always still works.

**2. While the machine is inside an esxDOS / DivMMC call.** Any live DivMMC
automap session blocks **every** Multiface NMI for its whole duration — the poll
and the M1 button alike. Not just the DivMMC NMI menu: any file I/O, any dot
command, any `RST 8` trap window (`zxnext.vhd:2107` against
`device/divmmc.vhd:148-150`). Requests are dropped rather than queued, so each
lost poll simply retries next frame; but a program sitting inside a long esxDOS
call cannot be paused until it comes out.

**3. If the program clears NR `0x06` bit 3.** That gates every Multiface NMI
source. The break then dies **silently** — Pause does nothing and nothing says
why — and the only way back is an M1 press. The poll cannot re-assert the bit,
because the poll is the thing that stops running.

**4. If the program stops or restarts the Copper.** Note this now cuts both
ways: whichever list is live — yours or the debugger's — is the one a write here
affects, and a program that installs its own list without the two instructions
silently replaces a working break with a non-working one.

A write of NR `0x62` that *changes* the mode bits restarts the list from index
0, mode `00` stops it outright, and writing list content through NR `0x60`
overwrites whatever was there. If the list is your own, this is entirely under
your control: restart it, with the two instructions in it, and the break comes
back. If you were relying on the debugger's, the cure is a fresh debug session
or the "A" key off and on again.

**5. While anything is using config mode.** Config mode suppresses every
Multiface NMI while it is active (`zxnext.vhd:2102-2105`). It is normally a
window of milliseconds and it self-recovers.


**7. After a reset, until the next M1 press.** Any reset puts NR `0x0B` back to
disabled (`zxnext.vhd:4939-4941`), so the cable's receive line is disconnected
again and Pause stops working. The debugger re-arms it the next time it takes
control, so one M1 press is the whole cure. The same shape as state 3, and with
the same tell: nothing says why.


## How to tell it is working

Press Pause and look at the PC, not at the Next — there is deliberately nothing
to see on the machine:

- **The Next's screen does not change when a break happens.** A poll break goes
  to the debugger's command loop, which does not repaint.
- What *does* change: **the border resumes cycling** (the debugger is executing
  again), and DeZog shows the program stopped, with registers and a call stack.
- DeZog reports the stop as **`Manual break`**, the same reason an M1 press
  gives. DZRP has no break reason meaning "the PC asked".

If Pause does nothing: check the stub's screen reads `Async break: on` rather
than `Async break: off`. Then check the two instructions really are in
the list, and that NR `0x06` bit 3 has not been cleared. Then press
M1, which always works.
