SDK = /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
C_MODULE_DIR = Sources/NetcutxBPF_C/include
BIN = build/netcutx

.PHONY: all clean

all: $(BIN)

build:
	mkdir -p build

build/netcutx_bpf.o: Sources/NetcutxBPF_C/netcutx_bpf.c $(C_MODULE_DIR)/netcutx_bpf.h | build
	cc -c $< -I$(C_MODULE_DIR) -o $@

$(BIN): Sources/NetcutxBPF/NetcutxBPF.swift Sources/netcutx/*.swift build/netcutx_bpf.o | build
	swiftc Sources/NetcutxBPF/NetcutxBPF.swift Sources/netcutx/*.swift \
		build/netcutx_bpf.o \
		-I$(C_MODULE_DIR) -sdk $(SDK) \
		-o $@

clean:
	rm -rf build
