#!/system/bin/sh

# The Android 16 vold bridge mounts metadata-encrypted /data before OrangeFox
# initializes its Android 12 crypto UI. OrangeFox consequently marks the block
# device as decrypted without populating its FBE user list and hides both
# decryption entries. Keep FBE enabled, expose the user-0 action, and select the
# numeric PIN page used by lamu.

theme="/twres/pages/advanced.xml"
[ -f "${theme}" ] || exit 0

sed -i '
/<listitem name="{@decrypt_data_btn}">/,/<\/listitem>/ {
    /<condition var1="tw_is_fbe" op="!=" var2="1"\/>/d
    /<condition var1="tw_is_decrypted" var2="0"\/>/d
    s#tw_crypto_pwtype=%tw_crypto_pwtype_0%#tw_crypto_pwtype=3#
}
' "${theme}"

exit 0
