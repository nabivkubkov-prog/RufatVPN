# RufatVPN

Simple VPN client for iOS 12+ on the sing-box core (VLESS, VLESS Reality, Hysteria2).

Status: test build. Paste a `vless://` or `hysteria2://` link and press Start.

## Install (jailbroken device)

1. Install AppSync Unified from Cydia/Sileo.
2. Download the IPA from Releases and install it with Filza.

The IPA is fake-signed with `ldid` and carries the NetworkExtension
entitlement, so it only runs on devices with AppSync.

## License

GPLv3. The tunnel platform glue is adapted from
[SagerNet/sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple);
the core is [sing-box](https://github.com/SagerNet/sing-box).
