#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MF="$ROOT/Makefile"

test -f "$MF"
test -d "$ROOT/htdocs/luci-static/cleanx"
test -d "$ROOT/ucode/template/themes/cleanx"
test -x "$ROOT/root/etc/uci-defaults/30_luci-theme-cleanx"

grep -q '^PKG_NAME:=luci-theme-cleanx$' "$MF"
grep -q '^PKG_VERSION:=0.2.3$' "$MF"
grep -q '^PKGARCH:=all$' "$MF"

if grep -Eq '^[[:space:]]*DEPENDS[[:space:]]*:=' "$MF"; then
	echo "ERROR: DEPENDS must not be set for this static theme package."
	exit 1
fi

if grep -Eq 'luci\.mk|LUCI_DEPENDS|LUCI_TITLE' "$MF"; then
	echo "ERROR: luci.mk / LUCI_* package style must not be used."
	exit 1
fi

echo "CleanX project validation passed."
