#!/usr/bin/env bash
#
# Static QA for luci-theme-uniwrt. Runs in CI (and locally) with no network
# and no OpenWrt SDK. Fails fast on any regression.
#
set -uo pipefail

PKG_DIR="luci-theme-uniwrt"
fail=0
note() { printf '  %s\n' "$*"; }
ok()   { printf '\033[32mok\033[0m   %s\n' "$*"; }
bad()  { printf '\033[31mFAIL\033[0m %s\n' "$*"; fail=1; }

NODE="$(command -v node || command -v nodejs || true)"

echo "== JavaScript syntax (node --check) =="
if [ -n "$NODE" ]; then
  while IFS= read -r f; do
    if "$NODE" --check "$f" 2>/tmp/nodeerr; then ok "$f"; else bad "$f"; cat /tmp/nodeerr; fi
  done < <(find "$PKG_DIR" -name '*.js' | sort)
else
  bad "node/nodejs not found"
fi

echo "== JSON validity =="
while IFS= read -r f; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/tmp/jsonerr; then ok "$f"; else bad "$f"; cat /tmp/jsonerr; fi
done < <(find "$PKG_DIR" -name '*.json' | sort)

echo "== Workflow YAML validity =="
for f in .github/workflows/*.yml; do
  [ -e "$f" ] || continue
  if python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$f" 2>/tmp/yamlerr; then ok "$f"; else bad "$f"; cat /tmp/yamlerr; fi
done

echo "== ucode template tag balance =="
for f in "$PKG_DIR"/ucode/template/themes/uniwrt/*.ut; do
  a=$(grep -o '{%' "$f" | wc -l); b=$(grep -o '%}' "$f" | wc -l)
  c=$(grep -o '{{' "$f" | wc -l); d=$(grep -o '}}' "$f" | wc -l)
  e=$(grep -o '{#' "$f" | wc -l); g=$(grep -o '#}' "$f" | wc -l)
  if [ "$a" = "$b" ] && [ "$c" = "$d" ] && [ "$e" = "$g" ]; then
    ok "$(basename "$f")  ({%=$a {{=$c {#=$e)"
  else
    bad "$(basename "$f")  unbalanced: {%=$a %}=$b  {{=$c }}=$d  {#=$e #}=$g"
  fi
done

echo "== CSS brace balance =="
for f in "$PKG_DIR"/htdocs/luci-static/uniwrt/css/*.css; do
  o=$(grep -o '{' "$f" | wc -l); c=$(grep -o '}' "$f" | wc -l)
  if [ "$o" = "$c" ]; then ok "$(basename "$f")  ($o pairs)"; else bad "$(basename "$f")  {=$o }=$c"; fi
done

echo "== Version is apk-valid (major.minor.fixup) =="
VER="$(tr -d '[:space:]' < "$PKG_DIR/ucode/template/themes/uniwrt/version")"
if printf '%s' "$VER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then ok "version $VER"; else bad "version '$VER' is not apk-valid"; fi

echo "== No proprietary trademark strings in shipped files =="
if grep -rinE 'unifi|ubiquiti|ubnt' "$PKG_DIR" >/tmp/tm 2>/dev/null; then bad "trademark strings found:"; cat /tmp/tm; else ok "clean"; fi

echo "== Security: login form must not reflect the request URL (issue #2) =="
if grep -nE 'getenv\(.REQUEST_URI.\)|QUERY_STRING' "$PKG_DIR"/ucode/template/themes/uniwrt/*.ut >/tmp/refl; then
  bad "request data reflected into a template:"; cat /tmp/refl
else ok "no request reflection"; fi
if grep -nE '<form[^>]*\baction=' "$PKG_DIR/ucode/template/themes/uniwrt/sysauth.ut" >/tmp/act; then
  bad "login form has an action attribute (must post back to itself):"; cat /tmp/act
else ok "login form posts back to itself"; fi

echo "== Security: UCI values are validated before reaching <style>/<script> =="
for f in header.ut sysauth.ut; do
  if grep -q 'u_hex' "$PKG_DIR/ucode/template/themes/uniwrt/$f"; then ok "$f validates colours"; else bad "$f writes UCI values unvalidated"; fi
done

echo "== No legacy (pre-v2.0.15) files in the package =="
legacy=0
for p in "$PKG_DIR/luasrc" "$PKG_DIR/htdocs/luci-static/uniwrt/js" \
         "$PKG_DIR/htdocs/luci-static/uniwrt/css/uniwrt.css"; do
  [ -e "$p" ] && { bad "legacy path present: $p"; legacy=1; }
done
for f in "$PKG_DIR"/htdocs/luci-static/uniwrt/*.css "$PKG_DIR"/htdocs/luci-static/uniwrt/*.svg; do
  [ -e "$f" ] && { bad "stray asset outside css/ or img/: $f"; legacy=1; }
done
[ "$legacy" = 0 ] && ok "clean"

echo "== Shell scripts (busybox ash syntax) =="
SH="$(command -v busybox >/dev/null && echo 'busybox sh' || echo sh)"
for f in uniwrt-apply.sh scripts/make-standalone.sh "$PKG_DIR"/root/etc/uci-defaults/*; do
  if $SH -n "$f" 2>/tmp/sherr; then ok "$f"; else bad "$f"; cat /tmp/sherr; fi
done

echo "== Required files present =="
for req in \
  "$PKG_DIR/Makefile" \
  "$PKG_DIR/ucode/template/themes/uniwrt/header.ut" \
  "$PKG_DIR/ucode/template/themes/uniwrt/footer.ut" \
  "$PKG_DIR/ucode/template/themes/uniwrt/sysauth.ut" \
  "$PKG_DIR/root/etc/uci-defaults/30_luci-theme-uniwrt" \
  "$PKG_DIR/root/usr/share/rpcd/acl.d/luci-theme-uniwrt.json" \
  "$PKG_DIR/root/usr/share/luci/menu.d/luci-theme-uniwrt.json"; do
  [ -f "$req" ] && ok "$req" || bad "missing $req"
done

echo
if [ "$fail" = 0 ]; then echo "ALL STATIC QA CHECKS PASSED"; else echo "STATIC QA FAILED"; fi
exit "$fail"
