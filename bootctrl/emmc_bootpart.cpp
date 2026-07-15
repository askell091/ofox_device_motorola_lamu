//
// SPDX-FileCopyrightText: The LineageOS Project
// SPDX-License-Identifier: Apache-2.0
//

#include "emmc_bootpart.h"

#include <android-base/logging.h>
#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <linux/mmc/ioctl.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace lamu::boot {
namespace {

constexpr char kEmmcDevice[] = "/dev/block/mmcblk0";
constexpr uint32_t kMmcSwitch = 6;
constexpr uint32_t kMmcSendExtCsd = 8;
constexpr uint32_t kExtCsdPartConfig = 179;
constexpr uint32_t kMmcRspPresent = 1U << 0;
constexpr uint32_t kMmcRspCrc = 1U << 2;
constexpr uint32_t kMmcRspBusy = 1U << 3;
constexpr uint32_t kMmcRspOpcode = 1U << 4;
constexpr uint32_t kMmcCmdAc = 0U << 5;
constexpr uint32_t kMmcCmdAdtc = 1U << 5;
constexpr uint32_t kMmcRspR1 = kMmcRspPresent | kMmcRspCrc | kMmcRspOpcode;
constexpr uint32_t kMmcRspR1b = kMmcRspR1 | kMmcRspBusy;
constexpr uint32_t kMmcSwitchModeWriteByte = 0x03;
constexpr uint32_t kExtCsdCmdSetNormal = 1U << 0;

constexpr uint32_t MakeSwitchArg(uint8_t access, uint8_t index, uint8_t value,
                                 uint8_t command_set) {
  return (static_cast<uint32_t>(access) << 24) |
         (static_cast<uint32_t>(index) << 16) |
         (static_cast<uint32_t>(value) << 8) | command_set;
}

bool ReadExtCsd(int fd, uint8_t *ext_csd) {
  mmc_ioc_cmd command = {};
  std::memset(ext_csd, 0, 512);
  command.blocks = 1;
  command.blksz = 512;
  command.opcode = kMmcSendExtCsd;
  command.flags = kMmcCmdAdtc | kMmcRspR1;
  mmc_ioc_cmd_set_data(command, ext_csd);
  if (ioctl(fd, MMC_IOC_CMD, &command) < 0) {
    PLOG(ERROR) << "Failed to read eMMC EXT_CSD";
    return false;
  }
  return true;
}

uint8_t GetBootRegion(const uint8_t *ext_csd) {
  return (ext_csd[kExtCsdPartConfig] >> 3) & 0x07;
}

bool SwitchBootRegion(int fd, uint8_t *ext_csd, uint8_t boot_region) {
  const uint8_t value =
      (ext_csd[kExtCsdPartConfig] & ~0x38U) | (boot_region << 3);
  mmc_ioc_cmd command = {};
  command.opcode = kMmcSwitch;
  command.arg = MakeSwitchArg(kMmcSwitchModeWriteByte, kExtCsdPartConfig, value,
                              kExtCsdCmdSetNormal);
  command.flags = kMmcCmdAc | kMmcRspR1b;
  if (ioctl(fd, MMC_IOC_CMD, &command) < 0) {
    PLOG(ERROR) << "Failed to switch eMMC boot region";
    return false;
  }
  return true;
}

} // namespace

bool SetEmmcBootRegion(uint32_t slot) {
  if (slot > 1) {
    LOG(ERROR) << "Invalid lamu slot " << slot;
    return false;
  }

  const uint8_t target_boot_region = slot == 1 ? 2 : 1;
  const int fd = open(kEmmcDevice, O_RDWR | O_CLOEXEC);
  if (fd < 0) {
    PLOG(ERROR) << "Failed to open " << kEmmcDevice;
    return false;
  }

  uint8_t ext_csd[512];
  bool success = ReadExtCsd(fd, ext_csd);
  const uint8_t previous_boot_region = success ? GetBootRegion(ext_csd) : 0;
  if (success && previous_boot_region != target_boot_region) {
    success = SwitchBootRegion(fd, ext_csd, target_boot_region);
    uint8_t verify_ext_csd[512];
    success = success && ReadExtCsd(fd, verify_ext_csd) &&
              GetBootRegion(verify_ext_csd) == target_boot_region;
    if (!success) {
      LOG(ERROR) << "eMMC boot-region verification failed; restoring region "
                 << static_cast<unsigned int>(previous_boot_region);
      uint8_t restore_ext_csd[512];
      const bool restored =
          SwitchBootRegion(fd, ext_csd, previous_boot_region) &&
          ReadExtCsd(fd, restore_ext_csd) &&
          GetBootRegion(restore_ext_csd) == previous_boot_region;
      if (!restored) {
        LOG(ERROR) << "Failed to restore the previous eMMC boot region";
      }
    }
  }
  close(fd);
  return success;
}

} // namespace lamu::boot
