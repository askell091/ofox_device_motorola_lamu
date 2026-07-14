#!/system/bin/sh

# OrangeFox calls this hook synchronously after mounting system and vendor and
# before attempting metadata/FBE decryption. The installed Trustonic services
# are built for Android 16 and therefore need the installed system runtime and
# servicemanager rather than fox_12.1's Android 12 equivalents.

log_tag="lamu-crypto"
runtime_libs="/system_root/system/lib64:/vendor/lib64:/system_root/system/lib64/bootstrap"

log_msg() {
    log -t "${log_tag}" "$*"
}

read_prop() {
    sed -n "s/^$1=//p" "$2" | head -n 1
}

wait_for_prop() {
    prop="$1"
    expected="$2"
    retries="$3"

    while [ "${retries}" -gt 0 ]; do
        [ "$(getprop "${prop}")" = "${expected}" ] && return 0
        retries=$((retries - 1))
        sleep 0.1
    done
    return 1
}

if [ ! -x /system_root/system/bin/bootstrap/linker64 ] || \
   [ ! -x /system_root/system/bin/servicemanager ] || \
   [ ! -x /vendor/bin/mcDriverDaemon ] || \
   [ ! -x /vendor/bin/hw/android.hardware.security.keymint@3.0-service.trustonic ] || \
   [ ! -x /vendor/bin/hw/android.hardware.gatekeeper-service.trustonic ]; then
    log_msg "Android 16 Trustonic runtime is unavailable; leaving stock recovery services active"
    exit 1
fi

slot_suffix="$(getprop ro.boot.slot_suffix)"
odm_block="/dev/block/mapper/odm${slot_suffix}"

# A real ODM mount is required. The empty recovery mountpoint otherwise loops
# through /odm/etc -> /vendor/odm/etc -> /odm/etc and makes libvintf reject the
# device manifest.
if ! grep -q " /odm " /proc/mounts; then
    if [ -b "${odm_block}" ]; then
        mount -t erofs -o ro "${odm_block}" /odm
    else
        log_msg "ODM mapper ${odm_block} is unavailable"
        exit 1
    fi
fi

mkdir -p /mnt/vendor/persist
if ! grep -q " /mnt/vendor/persist " /proc/mounts; then
    mount -t ext4 -o ro,nosuid,nodev,noatime \
        /dev/block/by-name/persist /mnt/vendor/persist
fi

system_release="$(read_prop ro.build.version.release /system_root/system/build.prop)"
system_patch="$(read_prop ro.build.version.security_patch /system_root/system/build.prop)"
vendor_patch="$(read_prop ro.vendor.build.security_patch /vendor/build.prop)"
first_api="$(read_prop ro.product.first_api_level /vendor/build.prop)"

[ -n "${system_release}" ] && resetprop ro.build.version.release "${system_release}"
[ -n "${system_patch}" ] && resetprop ro.build.version.security_patch "${system_patch}"
[ -n "${vendor_patch}" ] && resetprop ro.vendor.build.security_patch "${vendor_patch}"
[ -n "${first_api}" ] && resetprop ro.product.first_api_level "${first_api}"

setprop ctl.start lamu-mobicore
if ! wait_for_prop ro.vendor.trustonic.ready true 80; then
    log_msg "mcDriverDaemon did not report Trustonic readiness"
    exit 1
fi

# Android 16 libbinder requires the matching servicemanager and its readiness
# property. Restart keystore2 afterwards so it reconnects to the new context
# manager and discovers the now-registered HALs.
setprop ctl.stop keystore2
setprop ctl.stop servicemanager
setprop servicemanager.ready false
sleep 0.2
setprop ctl.start lamu-servicemanager16

if ! wait_for_prop servicemanager.ready true 50; then
    log_msg "Android 16 servicemanager did not become ready"
    exit 1
fi

setprop ctl.start lamu-keymint16
setprop ctl.start lamu-gatekeeper16
sleep 1
setprop ctl.start keystore2

setprop lamu.crypto.compat.ready 1
log_msg "Trustonic KeyMint/Gatekeeper compatibility services started (${runtime_libs})"
exit 0
