# Vitis passes these in. Keep them parametric.
COMPILER ?= riscv32-xilinx-elf-gcc
ARCHIVER ?= riscv32-xilinx-elf-ar
CP       ?= copy

LIB = libxil.a

RELEASEDIR = ..\..\..\lib
INCLUDEDIR = ..\..\..\include
INCLUDES   = -I. -I$(INCLUDEDIR)

CFILES = $(wildcard *.c)
OFILES = $(CFILES:.c=.o)
HFILES = $(wildcard *.h)

libs: $(OFILES)
	@echo Archiving simpleSum...
	$(ARCHIVER) -r $(RELEASEDIR)\$(LIB) $(OFILES)

%.o: %.c
	@echo Compiling $<
	$(COMPILER) $(COMPILER_FLAGS) $(EXTRA_COMPILER_FLAGS) $(INCLUDES) -c $< -o $@

include:
	-$(CP) $(HFILES) $(INCLUDEDIR)

clean:
	-del /q $(OFILES) 2>nul