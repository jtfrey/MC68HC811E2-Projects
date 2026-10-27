# MC68HC811E2 - A serendipitous foray into ancient tech

While on vacation in the summer of 2026, I happened upon a documentary of the founding of MOS and the release of their 6502 processor.  In this content was mentioned the MOS founders' original employment at Motorola and their participation in the production of that company's 6800 microcontroller.

Naturally, I wondered to what extent this ancestor to the 6502 — the processor on which I first wrote assembly code — would resemble its descendent (and other late 1970's hardware with which I'm familiar).

A few weeks later while going through some tech "trash" I was surprised to find a completed protoboard sporting a PLCC52 MC68HC811E2 chip and a MAX233 serial transceiver.  After a bit of work (correcting an inverted layout of the power regulator that delivered no power to the circuits, mapping-out the design of the board) and a boneheaded self-imposed roadblock (using a TTL-to-USB adapter on an RS-232 connection) the MC happily went into bootstrap mode, accepted my first 256-byte program in its RAM, and executed it.

Producing an infinitely-looped write of `Hello, world.` back to the serial console.  That program can be found in [helloworld.s](src/helloworld/helloworld.s).


## Is anyone there?

With the basics of serial i/o present in that helloworld program, the next step was exploring what else was already present in the 64 KiB address space.  From the data sheet I knew that the bootstrap ROM is present at `$BF00` when that mode is selected, and by default the 2 KiB of EEPROM can be found at `$F800`.

I opted for dumping bytes as hexadecimal text:  16 bytes per line with a leading address displayed:

```
$F800:FF FF FF FF FF FF FF FF  FF FF FF FF FF FF FF FF
$F810:FF FF FF FF FF FF FF FF  FF FF FF FF FF FF FF FF
  :
$FFF0:FF FF FF FF FF FF FF FF  FF FF FF FF FF FF FF FF
```

Indeed, the EEPROM range looked like just that:  it was completely empty, perhaps whoever built the board never got beyond the inverted regulator outputs!  That `RESET` vector of `$FFFF` would make for an interesting bootup in normal mode:  a jump to `$FFFF` would present the opcode `$FF`, which is a three-byte `STX $HHLL`.  The operand would come from `$0000`, then execution would proceed from `$0002` with whatever bytes are present in unitialized RAM.  Assuming at power-on the RAM is `$00` this would be:

```
    STX     $0000
    TEST
    TEST
      :
```

Since `TEST` is a privileged instruction, in normal mode it would be an illegal instruction and would cause an interrupt and jump to the vector at `$FFF8`.  Which, being `$FFFF`, would loop right back where we started.  But as an interrupt it would push the processor state to the stack before jumping, and eventually the stack (starting from top of RAM) would begin writing to RAM at `$0000`…`$00FF` with the program counter, status bits, etc.  It could be an interesting project to simulate the sequence and determine if the MC would end up writing any functional code by means of the repeated illegal instruction stack pushes.

## Programs

All programs written can be found in the [src](src/) directory.  The I/O registers are reused across all subprojects, so they are defined in a [src/io_regs.s](src/io_regs.s).

Makefiles are used to guide the build of 257-byte binary files that can be uploaded to the MC68HC811E2 in bootstrap mode.  The [AS Macroassembler](http://john.ccac.rwth-aachen.de:8000/as/) is used to assemble the 6811 assembly code.

## Making a PCB

With the chip sitting on an unstable perfboard, my attention turned to what I could do to make this "toy" a bit more stable.  The [official datasheet for the MC68HC11 series](https://www.nxp.com/docs/en/data-sheet/M68HC11E.pdf) was loaded with information:  how to use the built-in EEPROM programming facilities (to program the upper 2 KiB of address space) and how to add RAM to the system using some of the i/o ports as address and data lines (to fill the other ca. 61 KiB of open address space).

Over the course of about 6 months I read the docs, learned to use KiCad, and iterated through a schematic and a PCB layout for a board for that MC68HC811E2 MCU.  Header pins are present for a memory expansion bus (with demuxing of the shared address/data lines), the remaining analog and digital i/o ports, as well as the SPI and serial pins from the MCU.  A four-pin header (serial Rx/Tx, ground, +5V) are its iterface to the user:  a TTL UART serial-to-USB adapter provides the board's power and communications with my MacBook.

After all those months of study and work, the completed v1.0.0 PCB was fabricated and I soldered the parts salvaged from the trash to it.  I connected the USB adapter and opened a terminal emulator.

And it worked!  I mounted it inside an iPhone 13 box (perfect size).

The KiCad design is in the [PCB](PCB/) directory, along with photos of the [printed boards](PCB/Finished-Boards.jpg) and the [final product](PCB/Final-Product.jpg).
