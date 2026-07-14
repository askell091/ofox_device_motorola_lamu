# OrangeFox Recovery for Moto G15 (lamu)

Self-contained OrangeFox Recovery device tree for the Moto G15 (`lamu`). It
targets the OrangeFox `fox_12.1` manifest and builds recovery as the recovery
fragment of a header-v4 `vendor_boot` image.

## Sources and credits

- LineageOS device/kernel/vendor work and current prebuilts:
  `moto-mediatek-devs`.
- OrangeFox Recovery Project and TeamWin Recovery Project.

## Encryption compatibility

LineageOS 23.2 uses FBE v2 with metadata encryption and Trustonic KeyMint 3.0.
The vendor HALs target Android 16, while the recovery core targets Android 12.
The tree therefore keeps the installed read-only system/vendor/odm partitions
mounted and runs the complete KeyMint, Gatekeeper, keystore2 and vold path with
the matching Android 16 bootstrap runtime. Recovery-compatible VINTF manifests
and the installed i18n APEX bridge the remaining runtime differences before
OrangeFox attempts to decrypt userdata.

The Android 16 vold bridge opens metadata encryption and installs the existing
device-encrypted user-0 key. The installed Android 16 `gatekeeperd` translates
the recovery's framework Binder request to the device's AIDL Gatekeeper HAL,
allowing OrangeFox to validate the normal Android lock PIN before unlocking
credential-encrypted storage.

The GitHub Actions workflow applies the device-scoped patches in `patches/` to
the synced `bootable/recovery` and `system/vold` trees. They make fox_12.1
consume the DE state prepared by the Android 16 bridge, populate its native FBE
user list once, retain the metadata-encrypted mapper, and use `gatekeeperd` on
lamu while retaining the original HIDL Gatekeeper path for other devices.
