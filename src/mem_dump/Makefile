
include ../Makefile.inc

.PHONY: default clean

default: mem_dump_2k_rom.bin mem_dump_bootstrap.bin

clean::
	$(RM) mem_dump_2k_rom.p mem_dump_2k_rom.lst mem_dump_2k_rom.bin \
	      mem_dump_bootstrap.p mem_dump_bootstrap.lst mem_dump_bootstrap.bin

mem_dump_bootstrap.p: ASFLAGS += -D WRTBYTBASE=0xBF00

mem_dump_2k_rom.p: ASFLAGS += -D WRTBYTBASE=0xF800,WRTBYTEND=0x0000

