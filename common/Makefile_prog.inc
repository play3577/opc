# Default region to extract from the assembler output into the ROM
ROMSTART    ?= C000
ROMLEN      ?= 4000

INC_FLAGS   ?= -I $(ROOT)/include/$(CPU_NAME) -I $(ROOT)/include

# Default name of assembler program
PROG        ?= $(basename $(notdir $(PROG_SRC)))

$(PROG).hex: $(ROOT)/$(PROG_SRC)
	# run the pre-processor to resolve and ##includes
	filepp $(INC_FLAGS) -D_BASE_=0x$(ROMSTART) -kc '##' $(ROOT)/$(PROG_SRC) > $(PROG).s
	# run the assember
	python $(ROOT)/$(ASM_PATH) $(PROG).s $(PROG).hex
	# clean up
	rm -f $(PROG).s

# This is for use in the FPGA
$(PROG).mem: $(PROG).hex
	xxd -r -p < $(PROG).hex | dd ibs=2 conv=swab skip=$$((16#$(ROMSTART))) count=$$((16#$(ROMLEN))) | od -An -w2 -tx2 -v > $(PROG).mem

# This is for use in PiTubeDirect (this is specific to copro)
$(PROG).c: $(PROG).hex
	echo '#include "$(PROG).h"' > $(PROG).c
	echo 'uint16_t $(PROG)_$(CPU_NAME)[0x800] = {' >> $(PROG).c
	xxd -r -p < $(PROG).hex | dd ibs=2 conv=swab skip=$$((16#F800)) count=$$((16#0800)) | od -An -w2 -tx2 -v | awk '{print "0x" $$1 ","}' >> $(PROG).c
	echo '};' >> $(PROG).c