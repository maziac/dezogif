# DeZog ZX Next Uart Interface

# Introduction

This is a ZXNext assembler program named 'dezogif' that communicates via the UART with a debugger on a PC.

It is intended to use this with the DeZog, a vscode debug adapter.


# Design

There are basically 2 states:
- the debugged program is running
- the debugged program is stopped

When the debugged program is running no communication takes place and the joy ports are restored for joystick usage.
When the debugged program is stopped the dezogif takes over and configures the joy port for UART communication.

This implies that it is not possible to stop the debugged program from DeZog.
To stop it you need to press the yellow NMI button.

When the NMI button was pressed dezogif sends a DZRP pause notification to DeZog to notify about the state change. Then dezogif will wait for further requests from DeZog, e.g. to read register values etc.

The program is started when DeZog sends a DZRP continue request.

See [Design.md](documentation/Design.md) for more info.


# Build

~~~
make main
~~~

will create the enNextMf.rom binary.


# Deployment

The enNextMf.rom binary needs to be copied to the ZX Next SD card under machines/next/enNextMf.rom.

There exists already one, so you need to backup the original.

The program (dezogif/enNextMf.rom) is started after NextOS has been started by pressing the yellow NMI button.

To re-initialize later you need to hold down the "Symbol Shift" (or CTRL) key while hitting the NMI button.

Note: the SW (enNextMf.rom) is known to work with ZXNext core 03.01.10 and core 03.02.00. It will not work on older cores.


# Copper, Async Break

When started, as a default, dezogif supports "Async Break". I.e. as you would expect you can interrupt (break) a running program from DeZog by pressing the "Pause" button.

Implementation wise this depends on the Copper (ZX Next internal HW) being tun and creating an MF (Multiface) interrupt.

More information can be found here [AsynchronousBreak.md](documentation/AsynchronousBreak.md) and especially if your program uses the Copper you should read it.
[documentation/AsynchronousBreak.md]

# License

This program is licensed under the [MIT license](https://github.com/maziac/dezogif/blob/master/LICENSE.txt).

The source code is available on [github](https://github.com/maziac/dezogif).


# Acknowledgements

- Many thanks to Chris Kirby. I have used his [NDS code](https://github.com/Ckirby101/NDS-NextDevSystem) as starting point and used e.g. his routine to set the baudrate.

- A lot of thanks also to [jorgegv](https://github.com/jorgegv). He did a great work with his fork [dezogif_ng](https://github.com/jorgegv/dezogif_ng) which allows to connect the ZXNext with DeZog through a wifi interface. And he contributed the copper code for asynchronous break and a lot of other fixes. Please also have a look at his [JNext ZX Next emulator](https://github.com/jorgegv/jnext).

