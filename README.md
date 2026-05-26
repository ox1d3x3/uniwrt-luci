# CleanX LuCI Theme

CleanX is a clean, responsive LuCI theme for OpenWrt.

This full project ZIP is rolled as **v0.2.3** and fixes the package build problem from the previous attempt.

## Direct verdict

For your OpenWrt 25.x router, use the generated **`.apk`** package.

The `.ipk` output is only for OpenWrt 24.10.x/opkg compatibility.

## What this fixes

The previous build failed because the project/workflow was treating the theme like a LuCI feed package and/or pulling the LuCI runtime build chain into the SDK.

That caused errors like:

- `ucode/module.h: No such file or directory`
- `lua.h: No such file or directory`
- `netlink/msg.h: No such file or directory`
- `No rule to make target package/feeds/luci/luci-theme-.../compile`

CleanX is a static theme package, so it does **not** need to compile `luci-base`, `lucihttp`, `ucode-mod-html`, `rpcd-mod-luci`, or feed packages.

## Correct build outputs

The GitHub workflow builds:

- OpenWrt `24.10.6` mediatek/mt7622 SDK → `.ipk`
- OpenWrt `25.12.4` mediatek/mt7622 SDK → `.apk`

## How to use this ZIP

Extract this ZIP and push the whole project to your GitHub repo:

```sh
git add .
git commit -m "CleanX v0.2.3 full project package build fix"
git push
```

Then run:

```text
Actions → Build CleanX OpenWrt packages → Run workflow
```

Download the APK artifact for OpenWrt 25.x.

## Install on OpenWrt 25.x

```sh
scp luci-theme-cleanx-*.apk root@192.168.1.1:/tmp/

ssh root@192.168.1.1
apk add --allow-untrusted /tmp/luci-theme-cleanx-*.apk
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## Install on OpenWrt 24.10.x

```sh
scp luci-theme-cleanx_*.ipk root@192.168.1.1:/tmp/

ssh root@192.168.1.1
opkg install /tmp/luci-theme-cleanx_*.ipk
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

## Package naming

This project now uses the proper future name:

```text
luci-theme-cleanx
```

The install script still registers legacy aliases for:

```text
UniWRT
X1Wrt
```

That prevents old selected theme entries from breaking LuCI immediately after upgrade.
