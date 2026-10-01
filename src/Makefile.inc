#
# Standard Makefile for assembly with the AS Macroassembler
#

AS	= asl
ASFLAGS	= -cpu 6811
LD	= p2bin
LDFLAGS = 

#

%.p: %.s
	$(AS) $(ASFLAGS) -L -olist $*.lst -o $@ $<

%.bin: %.p
	$(LD) $(LDFLAGS) -o $@ $<

