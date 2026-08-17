# Hybris, native.
#
# The game boots from ordinary files: hybris.exe is hunk-loaded and every data
# load the original loader makes is intercepted and served from original/hybris
# by the $EED8 hook.  No disk image is read at runtime and no WHDLoad slave is
# involved.

MUSASHI_DIR ?= third_party/musashi
MUSASHI = $(MUSASHI_DIR)/m68kcpu.c $(MUSASHI_DIR)/m68kops.c \
	$(MUSASHI_DIR)/m68kdasm.c $(MUSASHI_DIR)/softfloat/softfloat.c
CFLAGS_NATIVE = -DM68K_INSTRUCTION_HOOK=M68K_OPT_SPECIFY_HANDLER \
	-O2 -std=c11 -Wall -Wextra -include src/host/amiga.h \
	-I$(MUSASHI_DIR) -Isrc/host
RAYLIB_FLAGS = -I$(HOME)/.local/include $(HOME)/.local/lib/libraylib.a \
	-lm -lpthread -ldl -lGL -lX11

HOST_CORE = src/host/amiga.c src/host/whdload.c src/host/hunk.c \
	src/host/exeboot.c src/host/hybris_files.c src/host/hybris_loader.c
HOST_HEADERS = src/host/amiga.h src/host/whdload.h src/host/hunk.h \
	src/host/exeboot.h src/host/hybris_files.h src/host/hybris_loader.h

all: build/hybris build/hybris_play

# Headless: renders frames, dumps audio, and is how everything gets measured.
build/hybris: src/host/hybris_run.c $(HOST_CORE) $(HOST_HEADERS) $(MUSASHI)
	mkdir -p build
	$(CC) $(CFLAGS_NATIVE) -o $@ src/host/hybris_run.c $(HOST_CORE) \
		$(MUSASHI) -lm

# Playable window.
build/hybris_play: src/host/hybris_play.c src/host/pad.c src/host/pad.h \
		$(HOST_CORE) $(HOST_HEADERS) $(MUSASHI)
	mkdir -p build
	$(CC) $(CFLAGS_NATIVE) -I$(HOME)/.local/include -o $@ \
		src/host/hybris_play.c src/host/pad.c $(HOST_CORE) $(MUSASHI) \
		$(RAYLIB_FLAGS)

play: build/hybris_play
	./build/hybris_play

# The file server on its own: the disk map, track-to-file resolution and the
# tail clamp, with no 68000 and no disk image in the loop.
build/test_hybris_files: tests/test_hybris_files.c src/host/hybris_files.c \
		src/host/hybris_files.h
	mkdir -p build
	$(CC) -O2 -std=c11 -Wall -Wextra -Isrc/host -o $@ \
		tests/test_hybris_files.c src/host/hybris_files.c

test: build/test_hybris_files
	./build/test_hybris_files original/hybris

# Re-extract the files from a disk image.  Only needed if you supply your own.
extract:
	python3 tools/extract_hybris_adf.py original/hybris/hybris.adf

clean:
	rm -rf build

.PHONY: all play test extract clean
