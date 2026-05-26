# CleanX LuCI Theme

CleanX is a clean, responsive LuCI theme for OpenWrt.

This project ZIP is rolled as **v0.2.4** and fixes the broken APK/IPK workflow from the previous package.

## Direct verdict

For your OpenWrt 25.x router, use the generated **`.apk`** package.

The `.ipk` output is for OpenWrt 24.10.x/opkg compatibility.

## What was wrong before

The previous workflow failed before build because it had a bad self-check:

```text
ERROR: Do not use luci.mk for this static theme package. Use package.mk only.
```

That check was wrong for this project. Real LuCI themes normally use the LuCI package helper, and your working workflow already prepares feeds before building.

## What changed in v0.2.4

- Uses your working pre-release workflow layout.
- Builds OpenWrt 24.10.6 `.ipk`.
- Builds OpenWrt 25.12.4 `.apk`.
- Builds OpenWrt snapshot `.apk`.
- Publishes packages and logs to a GitHub pre-release.
- Uses the correct LuCI package helper:

```make
include $(TOPDIR)/feeds/luci/luci.mk
```

- Removes the broken validator that failed on its own comment.
- Keeps package name as:

```text
luci-theme-cleanx
```

## How to build

Push the full project to GitHub:

```sh
git add .
git commit -m "CleanX v0.2.4 fix APK IPK prerelease workflow"
git push
```

Then run:

```text
Actions → Build CleanX pre-release packages → Run workflow
```

The workflow will publish a GitHub pre-release with:

- OpenWrt 24.10.6 IPK
- OpenWrt 25.12.4 APK
- OpenWrt snapshot APK
- Build logs
- SHA256SUMS

## Install on OpenWrt 25.x

```sh
scp luci-theme-cleanx-*.apk root@192.168.1.1:/tmp/

ssh root@192.168.1.1
apk add --allow-untrusted /tmp/luci-theme-cleanx-*.apk
rm -f /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache/
/etc/init.d/uhttpd restart
```

If your firmware uses a different LAN IP, replace `192.168.1.1`.

## Install on OpenWrt 24.10.x

```sh
scp luci-theme-cleanx_*.ipk root@192.168.1.1:/tmp/

ssh root@192.168.1.1
opkg install /tmp/luci-theme-cleanx_*.ipk
rm -f /tmp/luci-indexcache.*
rm -rf /tmp/luci-modulecache/
//etc/init.d/uhttpd restart
```

## Notes

The package still registers legacy aliases for:

```text
UniWRT
X1Wrt
```

That helps old selected theme entries avoid breaking immediately after upgrading to CleanX.
