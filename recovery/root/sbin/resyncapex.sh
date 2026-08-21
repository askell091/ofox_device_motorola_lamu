#!/system/bin/sh

# OrangeFox calls this hook synchronously after mounting system and vendor and
# before attempting metadata/FBE decryption. The installed Trustonic services,
# keystore2 and vold are built for Android 16, so the complete crypto path must
# use the installed Android 16 runtime instead of fox_12.1's Android 12 one.

log_tag="lamu-crypto"
runtime_libs="/system_root/system/lib64:/vendor/lib64:/apex/com.android.i18n/lib64:/system_root/system/lib64/bootstrap"
linker16="/system_root/system/bin/bootstrap/linker64"

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

is_mounted() {
    grep -q " $1 " /proc/mounts
}

mount_metadata() {
    is_mounted /metadata && return 0

    metadata_block="/dev/block/by-name/metadata"
    if [ ! -b "${metadata_block}" ]; then
        log_msg "Metadata block device ${metadata_block} is unavailable"
        return 1
    fi

    mkdir -p /metadata
    if ! mount -t f2fs -o rw,nosuid,nodev,noatime,discard \
        "${metadata_block}" /metadata; then
        log_msg "Unable to mount the real metadata partition"
        return 1
    fi

    return 0
}

run16() {
    LD_LIBRARY_PATH="${runtime_libs}" "${linker16}" "$@"
}

service_available() {
    run16 /system_root/system/bin/service check "$1" 2>/dev/null | \
        grep -q ': found'
}

wait_for_service() {
    service="$1"
    retries="$2"

    while [ "${retries}" -gt 0 ]; do
        service_available "${service}" && return 0
        retries=$((retries - 1))
        sleep 0.1
    done
    return 1
}

mount_recovery_vintf() {
    if ! is_mounted /vendor/etc/vintf/manifest; then
        mount -t tmpfs -o ro,nosuid,nodev,noexec tmpfs \
            /vendor/etc/vintf/manifest || return 1
    fi

    if ! is_mounted /vendor/etc/vintf/manifest.xml; then
        mount --bind /sbin/lamu-device-vintf.xml \
            /vendor/etc/vintf/manifest.xml || return 1
    fi

    if ! is_mounted /system/etc/vintf; then
        mount -t tmpfs -o rw,nosuid,nodev,noexec tmpfs \
            /system/etc/vintf || return 1
        cp /sbin/lamu-framework-vintf.xml \
            /system/etc/vintf/manifest.xml || return 1
        chmod 0444 /system/etc/vintf/manifest.xml
        mount -o remount,ro /system/etc/vintf || return 1
    fi
}

mount_i18n_apex() {
    is_mounted /apex/com.android.i18n && return 0

    i18n_apex="/system_root/system/apex/com.android.i18n.apex"
    i18n_image="/tmp/com.android.i18n.img"
    [ -f "${i18n_apex}" ] || return 1

    mkdir -p /apex/com.android.i18n
    unzip -p "${i18n_apex}" apex_payload.img >"${i18n_image}" || return 1
    mount -t ext4 -o loop,ro "${i18n_image}" /apex/com.android.i18n
}

bind_android16_helper() {
    source="$1"
    target="$2"

    is_mounted "${target}" && return 0
    mount --bind "${source}" "${target}"
}

mount_metadata_userdata() {
    run16 /system_root/system/bin/vdc cryptfs mountFstab \
        /dev/block/by-name/userdata /data false ""
}

if [ ! -x "${linker16}" ] || \
   [ ! -x /system_root/system/bin/servicemanager ] || \
   [ ! -x /system_root/system/bin/keystore2 ] || \
   [ ! -x /system_root/system/bin/gatekeeperd ] || \
   [ ! -x /system_root/system/bin/vold ] || \
   [ ! -x /system_root/system/bin/vdc ] || \
   [ ! -x /system_root/system/bin/fsck.f2fs ] || \
   [ ! -x /system_root/system/bin/vold_prepare_subdirs ] || \
   [ ! -x /vendor/bin/mcDriverDaemon ] || \
   [ ! -x /vendor/bin/hw/android.hardware.security.keymint@3.0-service.trustonic ] || \
   [ ! -x /vendor/bin/hw/android.hardware.gatekeeper-service.trustonic ]; then
    log_msg "Android 16 Trustonic runtime is unavailable; leaving stock recovery services active"
    exit 1
fi

# This hook runs synchronously before recovery reaches its normal metadata
# mount. Android 16 vold needs the persistent metadata-encryption files now,
# so mount the real partition here instead of racing recovery's later mount.
if ! mount_metadata; then
    exit 1
fi

metadata_key_dir="/metadata/vold/metadata_encryption/key"
if [ ! -s "${metadata_key_dir}/version" ] || \
   [ ! -s "${metadata_key_dir}/encrypted_key" ] || \
   [ ! -s "${metadata_key_dir}/keymaster_key_blob" ] || \
   [ ! -s "${metadata_key_dir}/secdiscardable" ]; then
    log_msg "Persistent metadata-encryption key files are unavailable"
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
    # Trustonic Gatekeeper updates mcRegistry/failure_records.dat after each
    # verification, including successful ones. A read-only persist mount makes
    # the HAL report a password failure even when the credential is correct.
    mount -t ext4 -o rw,nosuid,nodev,noatime \
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

if ! mount_recovery_vintf; then
    log_msg "Unable to install Android 12-compatible recovery VINTF manifests"
    exit 1
fi

if ! mount_i18n_apex; then
    log_msg "Unable to mount the installed Android 16 i18n APEX"
    exit 1
fi

if ! bind_android16_helper /sbin/fsck.f2fs16.sh /system/bin/fsck.f2fs || \
   ! bind_android16_helper /sbin/vold_prepare_subdirs16.sh \
        /system/bin/vold_prepare_subdirs; then
    log_msg "Unable to install Android 16 vold helper wrappers"
    exit 1
fi

setprop ctl.start lamu-mobicore
if ! wait_for_prop ro.vendor.trustonic.ready true 80; then
    log_msg "mcDriverDaemon did not report Trustonic readiness"
    exit 1
fi

# Android 16 libbinder requires the matching servicemanager and its readiness
# property. Do not clear servicemanager.ready when the compatibility service is
# already running; this hook may run again after restarting the recovery UI.
setprop ctl.stop keystore2
setprop ctl.stop servicemanager
if [ "$(getprop init.svc.lamu-servicemanager16)" != "running" ]; then
    setprop servicemanager.ready false
    setprop ctl.start lamu-servicemanager16

    if ! wait_for_prop servicemanager.ready true 50; then
        log_msg "Android 16 servicemanager did not become ready"
        exit 1
    fi
else
    setprop servicemanager.ready true
fi

setprop ctl.start lamu-keymint16
setprop ctl.start lamu-gatekeeper16
sleep 1

# keystore2 waits for Android's boot-complete property before serving vold.
# Recovery has no framework to publish it, so publish it after the Trustonic
# HALs and the Android 16 servicemanager are ready.
setprop sys.boot_completed 1

mkdir -p /tmp/misc/keystore
if ! service_available android.system.keystore2.IKeystoreService/default; then
    setprop ctl.start lamu-keystore16
    if ! wait_for_service android.system.keystore2.IKeystoreService/default 100; then
        log_msg "Android 16 keystore2 did not register"
        exit 1
    fi
fi

if ! service_available vold; then
    setprop ctl.start lamu-vold16
    if ! wait_for_service vold 100; then
        log_msg "Android 16 vold did not register"
        exit 1
    fi
fi

if ! is_mounted /data; then
    if [ -b /dev/block/mapper/userdata ]; then
        mount -t f2fs -o rw,nosuid,nodev,noatime,discard,inlinecrypt \
            /dev/block/mapper/userdata /data
    else
        mount_metadata_userdata
    fi
fi

# The first mountFstab call can create the metadata dm target before its
# KeyMint-backed key has been reloaded. In that state the mapper reads as
# zeroes and F2FS reports a magic mismatch. A second vold call reloads the
# existing target with the unwrapped key and mounts userdata successfully.
if ! is_mounted /data && [ -b /dev/block/mapper/userdata ]; then
    log_msg "Initial userdata mapper was not mountable; retrying through Android 16 vold"
    sleep 1
    mount_metadata_userdata
fi

if ! is_mounted /data; then
    log_msg "Android 16 vold was unable to mount metadata-encrypted /data"
    exit 1
fi

resetprop ro.crypto.state encrypted
resetprop ro.crypto.type file
resetprop ro.crypto.fs_crypto_blkdev /dev/block/mapper/userdata

if ! run16 /system_root/system/bin/vdc cryptfs enablefilecrypto; then
    log_msg "Android 16 vold could not initialize system-wide FBE keys"
    exit 1
fi

if ! run16 /system_root/system/bin/vdc cryptfs init_user0; then
    log_msg "Android 16 vold could not finish user 0 DE initialization"
    exit 1
fi

if [ ! -d /data/system/users ] || \
   [ ! -d /data/system_de/0 ] || \
   [ ! -d /data/misc_de/0 ] || \
   [ ! -d /data/user_de/0 ]; then
    log_msg "Android 16 vold returned success without installing user 0 DE policies"
    exit 1
fi

if ! service_available android.service.gatekeeper.IGateKeeperService; then
    setprop ctl.start lamu-gatekeeperd16
    if ! wait_for_service android.service.gatekeeper.IGateKeeperService 100; then
        log_msg "Android 16 gatekeeperd did not register"
        exit 1
    fi
fi

setprop lamu.crypto.compat.ready 1
log_msg "Android 16 Trustonic/keystore2/vold compatibility path is ready (${runtime_libs})"
exit 0
