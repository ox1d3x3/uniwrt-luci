# Security Policy

## Supported versions

Only the latest release of UniWRT Portal receives security fixes. Please upgrade before reporting.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report privately through GitHub instead:
**[Report a vulnerability](https://github.com/ox1d3x3/uniwrt-luci/security/advisories/new)**

Include, where possible:

- the affected version and OpenWrt release
- the file or page involved
- steps to reproduce, or a proof of concept
- the impact you expect (for example, credential exposure or script injection)

You can expect an acknowledgement within a few days. Once a fix is released, the advisory is published and the reporter is credited unless they prefer otherwise.

## Scope

In scope: anything shipped in the `luci-theme-uniwrt` package — templates, stylesheets, scripts, default configuration and ACLs — and `uniwrt-apply.sh`.

Out of scope: vulnerabilities in OpenWrt, LuCI core or other packages. Please report those to the [OpenWrt project](https://openwrt.org/docs/guide-developer/security).
