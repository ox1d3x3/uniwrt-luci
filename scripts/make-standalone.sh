#!/bin/sh
#
# make-standalone.sh <package.ipk> <out.tar.gz> [translation-package.ipk]
#
# Cuts the standalone archive used by `uniwrt-apply.sh` out of a built .ipk,
# so standalone installs get exactly the files the package ships (minified JS,
# cache-busted templates and all). Used by CI; safe to run locally.
#
set -eu

IPK="${1:?usage: $0 <package.ipk> <out.tar.gz> [translation-package.ipk]}"
OUT="${2:?usage: $0 <package.ipk> <out.tar.gz> [translation-package.ipk]}"
I18N_IPK="${3:-}"

case "$IPK" in /*) ;; *) IPK="$(pwd)/$IPK" ;; esac
case "$OUT" in /*) ;; *) OUT="$(pwd)/$OUT" ;; esac
[ -z "$I18N_IPK" ] || case "$I18N_IPK" in /*) ;; *) I18N_IPK="$(pwd)/$I18N_IPK" ;; esac

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/root"

extract_package() {
	package="$1"
	name="$2"
	pkgdir="$WORK/$name"
	mkdir "$pkgdir"

	# An .ipk is either a gzipped tar (current SDKs) or an ar archive (older ones).
	if tar -tzf "$package" >/dev/null 2>&1; then
		tar -xzf "$package" -C "$pkgdir"
	else
		( cd "$pkgdir" && ar x "$package" )
	fi
	[ -f "$pkgdir/data.tar.gz" ] || { echo "error: $package has no data.tar.gz" >&2; exit 1; }
	tar -xzf "$pkgdir/data.tar.gz" -C "$WORK/root"
}

extract_package "$IPK" theme
[ -z "$I18N_IPK" ] || extract_package "$I18N_IPK" i18n

VERSION_FILE="$WORK/root/usr/share/ucode/luci/template/themes/uniwrt/version"
[ -f "$VERSION_FILE" ] || { echo "error: not a luci-theme-uniwrt package" >&2; exit 1; }

# Deterministic archive: sorted, root-owned, fixed mtimes.
( cd "$WORK/root" && find . \( -type f -o -type l \) | LC_ALL=C sort > "$WORK/list" )
tar --owner=0 --group=0 --numeric-owner --mtime='@0' \
	-C "$WORK/root" -czf "$OUT" -T "$WORK/list"

echo "Built $(basename "$OUT") — UniWRT $(tr -d '[:space:]' < "$VERSION_FILE"), $(wc -l < "$WORK/list" | tr -d ' ') files"
