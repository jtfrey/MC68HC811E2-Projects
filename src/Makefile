#
# Do our subprojects:
#

SUBPROJECTS	= helloworld mem_dump

.PHONY: default clean

default::
	@for PROJ in $(SUBPROJECTS); do \
		make -C $$PROJ; \
	done

clean::
	@for PROJ in $(SUBPROJECTS); do \
		make -C $$PROJ clean; \
	done

