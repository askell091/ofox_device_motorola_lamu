#!/system/bin/sh

runtime_libs="/system_root/system/lib64:/vendor/lib64:/apex/com.android.i18n/lib64:/system_root/system/lib64/bootstrap"

export LD_LIBRARY_PATH="${runtime_libs}"
exec /system_root/system/bin/bootstrap/linker64 \
    /system_root/system/bin/vold_prepare_subdirs "$@"
