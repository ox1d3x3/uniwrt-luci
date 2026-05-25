#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu

uci set luci.main.mediaurlbase='/luci-static/bootstrap'
uci commit luci

if command -v apk >/dev/null 2>&1; then
	apk del luci-theme-uniwrt || true
elif command -v opkg >/dev/null 2>&1; then
	opkg remove luci-theme-uniwrt || true
fi

/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
printf '%s\n' 'UniWRT removed and LuCI reverted to Bootstrap.'
