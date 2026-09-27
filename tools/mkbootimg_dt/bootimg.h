/* SPDX-License-Identifier: Apache-2.0 */
/* Android boot image header v0, the wire format hboot 3.19's QCDT loader
 * parses on this device: a fixed 2048-byte (BOARD_KERNEL_PAGESIZE) header,
 * kernel, ramdisk, second stage and device-tree blob, each padded to a page
 * boundary. dt_size at byte offset 40 is the field this device's hboot and
 * every boot/recovery image it has run agree on.
 */
#ifndef _BOOTIMG_H_
#define _BOOTIMG_H_

#include <stdint.h>

#define BOOT_MAGIC "ANDROID!"
#define BOOT_MAGIC_SIZE 8
#define BOOT_NAME_SIZE 16
#define BOOT_ARGS_SIZE 512
#define BOOT_EXTRA_ARGS_SIZE 1024

struct boot_img_hdr {
	uint8_t magic[BOOT_MAGIC_SIZE];

	uint32_t kernel_size;
	uint32_t kernel_addr;

	uint32_t ramdisk_size;
	uint32_t ramdisk_addr;

	uint32_t second_size;
	uint32_t second_addr;

	uint32_t tags_addr;
	uint32_t page_size;
	uint32_t dt_size;
	uint32_t unused;

	uint8_t name[BOOT_NAME_SIZE];
	uint8_t cmdline[BOOT_ARGS_SIZE];

	uint32_t id[8];

	uint8_t extra_cmdline[BOOT_EXTRA_ARGS_SIZE];
} __attribute__((packed));

#endif
