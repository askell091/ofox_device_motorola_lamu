package android.os;

/** Minimal Android 16 vold client surface used by the lamu recovery helper. */
interface IVold {
    void unlockCeStorage(int userId, in byte[] secret) = 45;
    void prepareUserStorage(@nullable @utf8InCpp String uuid,
                            int userId, int storageFlags) = 47;
}
