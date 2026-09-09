# Pausing a running program from the PC

**What makes a program breakable from DeZog's Pause button, what it costs, and
when it will not work.**

**Most programs need no change at all** — the debugger installs what is needed
when a debug session opens. Read "What to add to the program" below only if your
program uses the Copper, or if you want to turn the feature off.

The feature is called "Async-Break" and can be turned on or off in the dezogif's UI.

# What it gives you

Without it, once Continue is pressed there are two ways back into the debugger:
the program reaches a breakpoint, or somebody presses the **M1 button** on the
Next.

With it, **Pause in VS Code stops the program** wherever it is, and breakpoints
and memory can be inspected without touching the machine. For a program that
does not use the Copper this costs nothing but the cable and the port selection
below.


# What to add to the program

**Nothing at all, if your program does not use the Copper.** The debugger
installs the Copper list itself, when a debug session opens. An
ordinary program is breakable from the PC with no source change whatsoever.

That works for one reason, and it is worth knowing because the rest of this page
follows from it: **the Copper has its own instruction memory and keeps executing
after the program that wrote the list has gone.** So the debugger can install it
as a client attaches — before your program has even been pushed to the machine,
let alone run — and it is still running once your program is.


## If the program already uses the Copper

If your program uses the Copper already, add this instructions to your own list. Add `MOVE $02,$08` **to the existing list**, at any raster
position, and leave the rest of it alone. That is all the debugger needs — it
does not care where in the list the two instructions sit or what else the list
does.

```asm
    ; The list, MSB first:
    ;   MOVE $02,$08  -> NR 0x02 bit 3, the Multiface NMI
    nextreg 0x60,0x02
    nextreg 0x60,0x08
```


## Turning it off

Assemble it out for release. It is a contiguous block with no other dependency,
so an `IFDEF DEBUG` around it is enough; nothing else in the program changes.


# What it costs while it is in

## Performance

The handler's decline path — the common case, once a frame, with nothing on the
link — is 223 clock cycles.
At 28MHz this is 223/28Mhz = 8us.
At 3.5MHz it is 223/3.5Mhz = 64us.
At a frame rate of 16ms it is 0.05% for 28MHz and 0.4% for 3.5MHz.

The poll does **not** change the machine's clock speed. It runs at whatever
clock the program is running at.

Anyway, if you want don't want to add this small performance penalty you'd need to turn "Async Break" off.

## Functionality

If "Async Break" is turned on and the UART is used through joystick port 1 or 2 the "normal" joystick functionality will still work, but the MD joystick functionality, e.g. the START button, will not work.

If you need that functionality either use the UART on the CN9 header (soldering required) or turn "Async Break" off. Of course, if you turn "Async Break" off you need to break via the NMI button.



# When it will not work

Some states, in rough order of how likely they are to be met. None of them
damages anything: in each, Pause simply does nothing until the state passes, and
the M1 button always still works.

**1. While the machine is inside an esxDOS / DivMMC call.** Any live DivMMC
automap session blocks **every** Multiface NMI for its whole duration — the poll
and the M1 button alike. Not just the DivMMC NMI menu: any file I/O, any dot
command, any `RST 8` trap window (`zxnext.vhd:2107` against
`device/divmmc.vhd:148-150`). Requests are dropped rather than queued, so each
lost poll simply retries next frame; but a program sitting inside a long esxDOS
call cannot be paused until it comes out.

**2. If the program clears NR `0x06` bit 3.** That gates every Multiface NMI
source. The break then dies **silently** — Pause does nothing and nothing says
why — and the only way back is an M1 press. The poll cannot re-assert the bit,
because the poll is the thing that stops running.

**3. If the program stops or restarts the Copper.** Note this now cuts both
ways: whichever list is live — yours or the debugger's — is the one a write here
affects, and a program that installs its own list without the two instructions
silently replaces a working break with a non-working one.

A write of NR `0x62` that *changes* the mode bits restarts the list from index
0, mode `00` stops it outright, and writing list content through NR `0x60`
overwrites whatever was there. If the list is your own, this is entirely under
your control: restart it, with the two instructions in it, and the break comes
back. If you were relying on the debugger's, the cure is a fresh debug session
or the "A" key off and on again.

**4. While anything is using config mode.** Config mode suppresses every
Multiface NMI while it is active (`zxnext.vhd:2102-2105`). It is normally a
window of milliseconds and it self-recovers.


**5. After a reset, until the next M1 press.** Any reset puts NR `0x0B` back to
disabled (`zxnext.vhd:4939-4941`), so the cable's receive line is disconnected
again and Pause stops working. The debugger re-arms it the next time it takes
control, so one M1 press is the whole cure. The same shape as state 3, and with
the same tell: nothing says why.


# How to tell it is working

Press "Pause" in VSCode. If your debugged program stops it's all working. If something's wrong an error will be displayed instead.

If it is not working stop the debug session and check in the dezogif's UI that "Async-Break" is turned on.

Or, if your program uses the Copper check that you added the two lines, or check with a program that does not use the Copper at all.

