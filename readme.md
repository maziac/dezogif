# Debug Uart Interface

# Introduction

This is a ZXNext assembler program that communicates via the UART with a debugger on a PC.

It is intended to use this with the DeZog, a vscode debug adapter.


# Startup

Use e.g.

~~~
mono CSpect.exe  -sound -w2 -zxnext -nextrom -exit -brk -tv -mmc=. ../../asm/dbg-uart-if/dbg-uart-if.nex
~~~

to start it from the CSpect directory.

