
include ../Makefile.inc

.PHONY: default clean

default: helloworld.bin

clean::
	$(RM) helloworld.p helloworld.lst helloworld.bin

helloworld.bin: helloworld.s ../io_regs.s

