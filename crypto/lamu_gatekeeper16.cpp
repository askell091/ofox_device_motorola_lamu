/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * One-shot Gatekeeper client for lamu's installed Android 16 runtime.
 * The recovery process itself uses Android 12 libbinder and cannot reliably
 * discover services registered after servicemanager is replaced. This helper
 * is launched by Android 16's bootstrap linker after that replacement.
 */

#include <android-base/file.h>
#include <android/service/gatekeeper/IGateKeeperService.h>
#include <binder/IServiceManager.h>
#include <gatekeeper/GateKeeperResponse.h>

#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace {

using ::android::service::gatekeeper::GateKeeperResponse;
using ::android::service::gatekeeper::IGateKeeperService;
using ::android::service::gatekeeper::ResponseCode;

constexpr size_t kHeaderSize = sizeof(int32_t) + sizeof(uint32_t) * 2;
constexpr size_t kMaxHandleSize = 4096;
constexpr size_t kExpectedTokenSize = 64;

template <typename T>
bool ReadScalar(const std::string& input, size_t* offset, T* value) {
    if (*offset > input.size() || input.size() - *offset < sizeof(T)) {
        return false;
    }
    memcpy(value, input.data() + *offset, sizeof(T));
    *offset += sizeof(T);
    return true;
}

}  // namespace

int main(int argc, char** argv) {
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
