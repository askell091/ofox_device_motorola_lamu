/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * One-shot Gatekeeper and Keystore2 client for lamu's Android 16 runtime.
 * The recovery process itself uses Android 12 libbinder and cannot reliably
 * discover services registered after servicemanager is replaced. This helper
 * is launched by Android 16's bootstrap linker after that replacement.
 */

#include <android-base/file.h>
#include <android/binder_manager.h>
#include <aidl/android/system/keystore2/CreateOperationResponse.h>
#include <aidl/android/system/keystore2/Domain.h>
#include <aidl/android/system/keystore2/IKeystoreService.h>
#include <aidl/android/system/keystore2/KeyDescriptor.h>
#include <aidl/android/system/keystore2/KeyEntryResponse.h>
#include <android/service/gatekeeper/IGateKeeperService.h>
#include <android/os/IVold.h>
#include <binder/IServiceManager.h>
#include <gatekeeper/GateKeeperResponse.h>
#include <keymint_support/authorization_set.h>

#include <cstdint>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

namespace {

using ::android::service::gatekeeper::GateKeeperResponse;
using ::android::service::gatekeeper::IGateKeeperService;
using ::android::service::gatekeeper::ResponseCode;

constexpr size_t kHeaderSize = sizeof(int32_t) + sizeof(uint32_t) * 2;
constexpr size_t kMaxHandleSize = 4096;
constexpr size_t kExpectedTokenSize = 64;
constexpr uint32_t kKeystoreIvSize = 12;
constexpr uint32_t kMaxAliasSize = 4096;
constexpr uint32_t kMaxCiphertextSize = 64 * 1024;
constexpr int64_t kLockSettingsNamespace = 103;
constexpr int32_t kStorageFlagCe = 2;

template <typename T>
bool ReadScalar(const std::string& input, size_t* offset, T* value) {
    if (*offset > input.size() || input.size() - *offset < sizeof(T)) {
        return false;
    }
    memcpy(value, input.data() + *offset, sizeof(T));
    *offset += sizeof(T);
    return true;
}

int UnwrapWithKeystore2(const std::string& request_path,
                        const std::string& response_path) {
    namespace keymint = ::aidl::android::hardware::security::keymint;
    namespace ks2 = ::aidl::android::system::keystore2;

    std::string request;
    if (!android::base::ReadFileToString(request_path, &request)) {
        return 20;
    }

    size_t offset = 0;
    uint32_t alias_size = 0;
    uint32_t iv_size = 0;
    uint32_t ciphertext_size = 0;
    if (!ReadScalar(request, &offset, &alias_size) ||
        !ReadScalar(request, &offset, &iv_size) ||
        !ReadScalar(request, &offset, &ciphertext_size) ||
        alias_size == 0 || alias_size > kMaxAliasSize ||
        iv_size != kKeystoreIvSize ||
        ciphertext_size == 0 || ciphertext_size > kMaxCiphertextSize ||
        offset > request.size() ||
        request.size() - offset !=
            static_cast<size_t>(alias_size) + iv_size + ciphertext_size) {
        return 21;
    }

    std::string alias(request.data() + offset, alias_size);
    offset += alias_size;
    std::vector<uint8_t> iv(request.begin() + offset,
                            request.begin() + offset + iv_size);
    offset += iv_size;
    std::vector<uint8_t> ciphertext(request.begin() + offset, request.end());

    ::ndk::SpAIBinder binder(AServiceManager_checkService(
        "android.system.keystore2.IKeystoreService/default"));
    if (binder.get() == nullptr) {
        return 22;
    }
    auto keystore = ks2::IKeystoreService::fromBinder(binder);
    if (keystore == nullptr) {
        return 23;
    }

    ks2::KeyDescriptor descriptor{
        .domain = ks2::Domain::SELINUX,
        .nspace = kLockSettingsNamespace,
        .alias = alias,
        .blob = {},
    };
    ks2::KeyEntryResponse key_entry;
    auto status = keystore->getKeyEntry(descriptor, &key_entry);
    if (!status.isOk() || key_entry.iSecurityLevel == nullptr) {
        return 24;
    }

    auto params = keymint::AuthorizationSetBuilder()
        .Authorization(keymint::TAG_ALGORITHM, keymint::Algorithm::AES)
        .Authorization(keymint::TAG_BLOCK_MODE, keymint::BlockMode::GCM)
        .Padding(keymint::PaddingMode::NONE)
        .Authorization(keymint::TAG_PURPOSE, keymint::KeyPurpose::DECRYPT)
        .Authorization(keymint::TAG_NONCE, iv)
        .Authorization(keymint::TAG_MAC_LENGTH, 128);

    ks2::CreateOperationResponse operation_response;
    status = key_entry.iSecurityLevel->createOperation(
        key_entry.metadata.key, params.vector_data(), true,
        &operation_response);
    if (!status.isOk() || operation_response.iOperation == nullptr) {
        return 25;
    }

    std::optional<std::vector<uint8_t>> plaintext;
    status = operation_response.iOperation->finish(ciphertext, {}, &plaintext);
    if (!status.isOk() || !plaintext.has_value() || plaintext->size() < 12) {
        return 26;
    }
    std::string output(reinterpret_cast<const char*>(plaintext->data()),
                       plaintext->size());
    if (!android::base::WriteStringToFile(output, response_path)) {
        return 27;
    }
    return 0;
}

int UnlockWithVold(const std::string& request_path,
                   const std::string& response_path) {
    std::string request;
    if (!android::base::ReadFileToString(request_path, &request)) {
        return 30;
    }

    size_t offset = 0;
    int32_t user_id = 0;
    uint32_t secret_hex_size = 0;
    if (!ReadScalar(request, &offset, &user_id) ||
        !ReadScalar(request, &offset, &secret_hex_size) ||
        user_id < 0 || secret_hex_size == 0 || secret_hex_size > 256 ||
        (secret_hex_size & 1) != 0 || offset > request.size() ||
        request.size() - offset != secret_hex_size) {
        return 31;
    }

    auto HexNibble = [](char value) -> int {
        if (value >= '0' && value <= '9') return value - '0';
        if (value >= 'a' && value <= 'f') return value - 'a' + 10;
        if (value >= 'A' && value <= 'F') return value - 'A' + 10;
        return -1;
    };
    std::vector<uint8_t> secret(secret_hex_size / 2);
    for (size_t i = 0; i < secret.size(); ++i) {
        int high = HexNibble(request[offset + i * 2]);
        int low = HexNibble(request[offset + i * 2 + 1]);
        if (high < 0 || low < 0) return 32;
        secret[i] = static_cast<uint8_t>((high << 4) | low);
    }

    auto binder = android::defaultServiceManager()->checkService(
        android::String16("vold"));
    auto vold = android::interface_cast<android::os::IVold>(binder);
    if (vold == nullptr) {
        return 33;
    }
    auto status = vold->unlockCeStorage(user_id, secret);
    if (!status.isOk()) {
        return 34;
    }
    status = vold->prepareUserStorage(std::nullopt, user_id, kStorageFlagCe);
    if (!status.isOk()) {
        return 35;
    }
    if (!android::base::WriteStringToFile("1", response_path)) {
        return 36;
    }
    return 0;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc == 4 && strcmp(argv[1], "unlock") == 0) {
        return UnlockWithVold(argv[2], argv[3]);
    }
    if (argc == 4 && strcmp(argv[1], "unwrap") == 0) {
        return UnwrapWithKeystore2(argv[2], argv[3]);
    }
    if (argc != 3) {
        return 2;
    }

    std::string request;
    if (!android::base::ReadFileToString(argv[1], &request) ||
        request.size() < kHeaderSize) {
        return 3;
    }

    size_t offset = 0;
    int32_t user_id = 0;
    uint32_t handle_size = 0;
    uint32_t token_size = 0;
    if (!ReadScalar(request, &offset, &user_id) ||
        !ReadScalar(request, &offset, &handle_size) ||
        !ReadScalar(request, &offset, &token_size) ||
        handle_size == 0 || handle_size > kMaxHandleSize ||
        token_size != kExpectedTokenSize ||
        offset > request.size() ||
        request.size() - offset !=
            static_cast<size_t>(handle_size) + token_size) {
        return 4;
    }

    std::vector<uint8_t> password_handle(
        request.begin() + offset, request.begin() + offset + handle_size);
    offset += handle_size;
    std::vector<uint8_t> password_token(
        request.begin() + offset, request.end());

    auto binder = android::defaultServiceManager()->checkService(
        android::String16("android.service.gatekeeper.IGateKeeperService"));
    auto gatekeeper = android::interface_cast<IGateKeeperService>(binder);
    if (gatekeeper == nullptr) {
        return 5;
    }

    GateKeeperResponse response = GateKeeperResponse::error();
    auto status = gatekeeper->verifyChallenge(
        user_id, 0 /* challenge */, password_handle, password_token, &response);
    if (!status.isOk() || response.response_code() != ResponseCode::OK ||
        response.payload().empty()) {
        return 6;
    }

    std::string payload(
        reinterpret_cast<const char*>(response.payload().data()),
        response.payload().size());
    if (!android::base::WriteStringToFile(payload, argv[2])) {
        return 7;
    }

    return 0;
}
