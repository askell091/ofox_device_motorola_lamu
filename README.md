# OrangeFox Recovery for Moto G15 (lamu)

Self-contained OrangeFox Recovery device tree for the Moto G15 (`lamu`). It
targets the OrangeFox `fox_12.1` manifest and builds recovery as the recovery
fragment of a header-v4 `vendor_boot` image.

## Sources and credits

- LineageOS device/kernel/vendor work and current prebuilts:
  `moto-mediatek-devs`.
- OrangeFox Recovery Project and TeamWin Recovery Project.

The exact local source paths and hashes used for the prebuilts are documented
in [prebuilts/PROVENANCE.md](prebuilts/PROVENANCE.md).

## Encryption compatibility

LineageOS 23.2 uses FBE v2 with metadata encryption and Trustonic KeyMint 3.0.
The vendor HALs target Android 16, while the recovery core targets Android 12.
The tree therefore keeps the installed read-only system/vendor/odm partitions
mounted and starts KeyMint and Gatekeeper with the matching system bootstrap
runtime before OrangeFox attempts to decrypt userdata.
