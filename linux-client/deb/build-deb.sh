#!/usr/bin/env bash
# Build the `audio-share-client` .deb (default target: arm64).
#
#   ./deb/build-deb.sh                        # arm64, musl static as-client
#   CC=aarch64-linux-gnu-gcc ./deb/build-deb.sh
#   ARCH=amd64 ./deb/build-deb.sh             # native test package
#
# Requires: dpkg-deb, a C compiler (cross for the target arch), and the GUI/
# icon/unit files sitting next to this script (they are pure Python/SVG, so no
# target toolchain is needed for them).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)        # linux-client/
REPO=$(cd "$ROOT/.." && pwd)        # repo root
PKG=audio-share-client
VER=${VER:-0.1.0}
ARCH=${ARCH:-arm64}
CC=${CC:-$HOME/toolchains/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc}
OUT=${OUT:-$REPO/dist}
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/as-deb.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }

say "compiling as-client with $CC"
"$CC" -O2 -std=c11 -Wall -Wextra -Wno-unused-parameter -static \
	-o "$STAGE/as-client" "$ROOT/as-client.c"
file "$STAGE/as-client" | sed 's/^/    /'

say "staging $PKG $VER ($ARCH)"
D="$STAGE/root"
install -Dm755 "$STAGE/as-client"                              "$D/usr/bin/as-client"
install -Dm755 "$ROOT/gui/audio-share-gui"                     "$D/usr/bin/audio-share-gui"
install -Dm755 "$ROOT/gui/audio-share-client-run"              "$D/usr/bin/audio-share-client-run"
install -Dm644 "$ROOT/gui/audio-share-client.desktop"          "$D/usr/share/applications/audio-share-client.desktop"
install -Dm644 "$ROOT/gui/audio-share-client.svg"              "$D/usr/share/icons/hicolor/scalable/apps/audio-share-client.svg"
install -Dm644 "$HERE/audio-share-client.service"              "$D/usr/lib/systemd/user/audio-share-client.service"
install -Dm644 "$HERE/copyright"                               "$D/usr/share/doc/$PKG/copyright"
install -Dm644 "$ROOT/README.md"                               "$D/usr/share/doc/$PKG/README.md"

mkdir -p "$D/DEBIAN"
SIZE=$(du -sk --exclude=DEBIAN "$D" | cut -f1)
cat > "$D/DEBIAN/control" <<EOF
Package: $PKG
Version: $VER
Architecture: $ARCH
Maintainer: xiaquwan1001 <xiaquwan1001@users.noreply.github.com>
Installed-Size: $SIZE
Depends: python3, python3-gi, gir1.2-gtk-3.0, pipewire-bin | pipewire, systemd
Recommends: pipewire-audio | pulseaudio-utils
Section: sound
Priority: optional
Homepage: https://github.com/xiaquwan1001/audio-share
Description: Audio Share client with a small GUI (receive PC audio over LAN)
 Client side of Audio Share (mkckr0/audio-share): receives the raw PCM
 stream from an Audio Share server (as-cmd on Windows/Linux) and plays it
 through PipeWire on this machine.
 .
 Includes as-client (C, static, no runtime libraries), a GTK3 window
 (server address, output sink, play/stop, throughput, autostart) and a
 systemd user unit for boot-time auto connect.
EOF

cat > "$D/DEBIAN/conffiles" <<'EOF'
EOF
rm -f "$D/DEBIAN/conffiles"

cat > "$D/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
# Refresh the desktop/icon caches so the entry shows up without a re-login.
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$D/DEBIAN/postinst"

mkdir -p "$OUT"
DEB="$OUT/${PKG}_${VER}_${ARCH}.deb"
say "packing $DEB"
dpkg-deb -Zxz --build --root-owner-group "$D" "$DEB" >/dev/null
dpkg-deb -I "$DEB" | sed -n '/Package:/,/Description:/p' | sed 's/^/    /'
say "contents"
dpkg-deb -c "$DEB" | awk '{print "    "$6}' | grep -v '/$' 
echo
say "size: $(du -h "$DEB" | cut -f1)   →  $DEB"
