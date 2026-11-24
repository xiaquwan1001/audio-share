# Build the Audio Share Linux client.
#
#   make                          native build (./as-client)
#   make CROSS=aarch64-linux-musl-            ARM64, musl (static, drops into any ARM rootfs)
#   make CROSS=arm-linux-gnueabihf-           ARM32 hard-float
#   make LDFLAGS=-static          fully static
#
# The client itself has no library dependencies (pthread/libc only at build
# time via -std=c11); playback is delegated to `pw-cat` at runtime, so the
# target needs the `pipewire-bin` package (or any pw-cat equivalent).

CC      ?= cc
CROSS   ?=
CFLAGS  ?= -O2 -g -std=c11 -Wall -Wextra -Wno-unused-parameter
PREFIX  ?= /usr/local
BIN      = as-client

all: $(BIN)

$(BIN): as-client.c
	$(CROSS)$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $<

install: $(BIN)
	install -Dm755 $(BIN) $(DESTDIR)$(PREFIX)/bin/$(BIN)

clean:
	rm -f $(BIN)

.PHONY: all install clean
