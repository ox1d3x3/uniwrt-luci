#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MF="$ROOT/Makefile"

test -f "$MF"
test -d "$ROOT/htdocs/luci-static/cleanx"
test -d "$ROOT/ucode/template/themes/cleanx"
test -x "$ROOT/root/etc/uci-defaults/30_luci-theme-cleanx"

grep -q '^PKG_NAME:=luci-theme-cleanx$' "$MF"
grep -q '^PKG_VERSION:=0.2.4$' "$MF"
grep -q '^LUCI_TITLE:=' "$MF"
grep -q '^LUCI_DEPENDS:=+luci-base$' "$MF"
grep -q 'include $(TOPDIR)/feeds/luci/luci.mk' "$MF"

if grep -q 'include ../../luci.mk' "$MF"; then
	echo "ERROR: do not use relative ../../luci.mk from package/custom. Use $(TOPDIR)/feeds/luci/luci.mk."
	exit 1
fi

echo "CleanX project validation passed."
