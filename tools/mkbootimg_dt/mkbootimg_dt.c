/* SPDX-License-Identifier: Apache-2.0 */
/* Boot image packer for BOARD_CUSTOM_MKBOOTIMG (build/make/core/config.mk:686).
 * AOSP's own system/tools/mkbootimg dropped the QCDT --dt flag for the
 * single flattened --dtb (boot header v1+); this device's hboot reads the
 * v0 header's dt_size field (offset 40) and expects the QCDT multi-entry
 * blob there, so the tree supplies its own packer rather than reworking
 * hboot. --output/--kernel/--ramdisk/--dt/--base/--cmdline/--pagesize and
 * the four load-address offsets are BOARD_MKBOOTIMG_ARGS' own vocabulary,
 * unchanged from AOSP's v0 tool.
 */
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "bootimg.h"
#include "sha1.h"

static void *load_file(const char *fn, uint32_t *out_size) {
	FILE *f = fopen(fn, "rb");
	if (!f)
		return NULL;
	if (fseek(f, 0, SEEK_END) != 0) {
		fclose(f);
		return NULL;
	}
	long sz = ftell(f);
	if (sz < 0 || fseek(f, 0, SEEK_SET) != 0) {
		fclose(f);
		return NULL;
	}
	void *data = malloc((size_t)sz);
	if (!data) {
		fclose(f);
		return NULL;
	}
	if (sz > 0 && fread(data, 1, (size_t)sz, f) != (size_t)sz) {
		free(data);
		fclose(f);
		return NULL;
	}
	fclose(f);
	*out_size = (uint32_t)sz;
	return data;
}

static int usage(void) {
	fprintf(stderr,
		"usage: mkbootimg_dt --kernel <file> [--ramdisk <file>] [--second <file>]\n"
		"       [--dt <file>] [--cmdline <text>] [--board <name>] [--base <hex>]\n"
		"       [--kernel_offset <hex>] [--ramdisk_offset <hex>] [--second_offset <hex>]\n"
		"       [--tags_offset <hex>] [--pagesize <n>] -o|--output <file>\n");
	return 1;
}

static int write_all(FILE *f, const void *buf, size_t len) {
	return len == 0 || fwrite(buf, 1, len, f) == len ? 0 : -1;
}

static int write_padding(FILE *f, uint32_t pagesize, uint32_t itemsize) {
	uint32_t mask = pagesize - 1;
	if ((itemsize & mask) == 0)
		return 0;
	uint32_t count = pagesize - (itemsize & mask);
	static const uint8_t zero[65536] = {0};
	while (count > 0) {
		uint32_t chunk = count > sizeof(zero) ? sizeof(zero) : count;
		if (write_all(f, zero, chunk) != 0)
			return -1;
		count -= chunk;
	}
	return 0;
}

int main(int argc, char **argv) {
	struct boot_img_hdr hdr;
	memset(&hdr, 0, sizeof(hdr));

	const char *kernel_fn = NULL, *ramdisk_fn = NULL, *second_fn = NULL, *dt_fn = NULL;
	const char *output_fn = NULL, *cmdline = "", *board = "";
	uint32_t pagesize = 2048;
	uint32_t base = 0, kernel_offset = 0x00008000U, ramdisk_offset = 0x01000000U,
		 second_offset = 0x00f00000U, tags_offset = 0x00000100U;

	argc--;
	argv++;
	while (argc >= 1) {
		const char *arg = argv[0];
		if (!strcmp(arg, "--id")) {
			argc -= 1;
			argv += 1;
			continue;
		}
		if (argc < 2)
			return usage();
		const char *val = argv[1];
		argc -= 2;
		argv += 2;
		if (!strcmp(arg, "--output") || !strcmp(arg, "-o"))
			output_fn = val;
		else if (!strcmp(arg, "--kernel"))
			kernel_fn = val;
		else if (!strcmp(arg, "--ramdisk"))
			ramdisk_fn = val;
		else if (!strcmp(arg, "--second"))
			second_fn = val;
		else if (!strcmp(arg, "--dt"))
			dt_fn = val;
		else if (!strcmp(arg, "--cmdline"))
			cmdline = val;
		else if (!strcmp(arg, "--board"))
			board = val;
		else if (!strcmp(arg, "--base"))
			base = (uint32_t)strtoul(val, NULL, 16);
		else if (!strcmp(arg, "--kernel_offset"))
			kernel_offset = (uint32_t)strtoul(val, NULL, 16);
		else if (!strcmp(arg, "--ramdisk_offset"))
			ramdisk_offset = (uint32_t)strtoul(val, NULL, 16);
		else if (!strcmp(arg, "--second_offset"))
			second_offset = (uint32_t)strtoul(val, NULL, 16);
		else if (!strcmp(arg, "--tags_offset"))
			tags_offset = (uint32_t)strtoul(val, NULL, 16);
		else if (!strcmp(arg, "--pagesize")) {
			pagesize = (uint32_t)strtoul(val, NULL, 10);
			if (pagesize != 2048 && pagesize != 4096 && pagesize != 8192 &&
			    pagesize != 16384 && pagesize != 32768 && pagesize != 65536 &&
			    pagesize != 131072) {
				fprintf(stderr, "error: unsupported page size %u\n", pagesize);
				return 1;
			}
		}
		/* build/make/core/Makefile:1240 appends --os_version/
		 * --os_patch_level to every mkbootimg call regardless of
		 * header version; the v0 header this device's hboot reads
		 * has no field for either, so both are accepted and dropped. */
		else if (!strcmp(arg, "--os_version") || !strcmp(arg, "--os_patch_level"))
			;
		else
			return usage();
	}

	if (!output_fn) {
		fprintf(stderr, "error: no output filename specified\n");
		return usage();
	}
	if (!kernel_fn) {
		fprintf(stderr, "error: no kernel image specified\n");
		return usage();
	}
	if (strlen(board) >= BOOT_NAME_SIZE) {
		fprintf(stderr, "error: board name too large\n");
		return 1;
	}

	memcpy(hdr.magic, BOOT_MAGIC, BOOT_MAGIC_SIZE);
	strcpy((char *)hdr.name, board);
	hdr.page_size = pagesize;
	hdr.kernel_addr = base + kernel_offset;
	hdr.ramdisk_addr = base + ramdisk_offset;
	hdr.second_addr = base + second_offset;
	hdr.tags_addr = base + tags_offset;

	size_t cmdlen = strlen(cmdline);
	if (cmdlen > BOOT_ARGS_SIZE + BOOT_EXTRA_ARGS_SIZE - 2) {
		fprintf(stderr, "error: kernel commandline too large\n");
		return 1;
	}
	memcpy(hdr.cmdline, cmdline, cmdlen < BOOT_ARGS_SIZE - 1 ? cmdlen : BOOT_ARGS_SIZE - 1);
	hdr.cmdline[BOOT_ARGS_SIZE - 1] = '\0';
	if (cmdlen >= BOOT_ARGS_SIZE - 1) {
		const char *extra = cmdline + BOOT_ARGS_SIZE - 1;
		size_t extra_len = strlen(extra);
		if (extra_len > BOOT_EXTRA_ARGS_SIZE)
			extra_len = BOOT_EXTRA_ARGS_SIZE;
		memcpy(hdr.extra_cmdline, extra, extra_len);
	}

	uint32_t kernel_size = 0, ramdisk_size = 0, second_size = 0, dt_size = 0;
	void *kernel_data = load_file(kernel_fn, &kernel_size);
	if (!kernel_data) {
		fprintf(stderr, "error: could not load kernel '%s'\n", kernel_fn);
		return 1;
	}
	void *ramdisk_data = NULL;
	if (ramdisk_fn) {
		ramdisk_data = load_file(ramdisk_fn, &ramdisk_size);
		if (!ramdisk_data) {
			fprintf(stderr, "error: could not load ramdisk '%s'\n", ramdisk_fn);
			return 1;
		}
	}
	void *second_data = NULL;
	if (second_fn) {
		second_data = load_file(second_fn, &second_size);
		if (!second_data) {
			fprintf(stderr, "error: could not load secondstage '%s'\n", second_fn);
			return 1;
		}
	}
	void *dt_data = NULL;
	if (dt_fn) {
		dt_data = load_file(dt_fn, &dt_size);
		if (!dt_data) {
			fprintf(stderr, "error: could not load device tree image '%s'\n", dt_fn);
			return 1;
		}
	}
	hdr.kernel_size = kernel_size;
	hdr.ramdisk_size = ramdisk_size;
	hdr.second_size = second_size;
	hdr.dt_size = dt_size;

	sha1_ctx sha;
	sha1_init(&sha);
	sha1_update(&sha, kernel_data, kernel_size);
	sha1_update(&sha, &kernel_size, sizeof(kernel_size));
	if (ramdisk_data)
		sha1_update(&sha, ramdisk_data, ramdisk_size);
	sha1_update(&sha, &ramdisk_size, sizeof(ramdisk_size));
	if (second_data)
		sha1_update(&sha, second_data, second_size);
	sha1_update(&sha, &second_size, sizeof(second_size));
	if (dt_data) {
		sha1_update(&sha, dt_data, dt_size);
		sha1_update(&sha, &dt_size, sizeof(dt_size));
	}
	uint8_t digest[20];
	sha1_final(&sha, digest);
	memcpy(hdr.id, digest, sizeof(digest));

	FILE *out = fopen(output_fn, "wb");
	if (!out) {
		fprintf(stderr, "error: could not create '%s': %s\n", output_fn, strerror(errno));
		return 1;
	}

	int fail = 0;
	fail |= write_all(out, &hdr, sizeof(hdr));
	fail |= write_padding(out, pagesize, sizeof(hdr));
	fail |= write_all(out, kernel_data, hdr.kernel_size);
	fail |= write_padding(out, pagesize, hdr.kernel_size);
	fail |= write_all(out, ramdisk_data, hdr.ramdisk_size);
	fail |= write_padding(out, pagesize, hdr.ramdisk_size);
	if (second_data) {
		fail |= write_all(out, second_data, hdr.second_size);
		fail |= write_padding(out, pagesize, hdr.second_size);
	}
	if (dt_data) {
		fail |= write_all(out, dt_data, hdr.dt_size);
		fail |= write_padding(out, pagesize, hdr.dt_size);
	}
	fclose(out);

	if (fail) {
		fprintf(stderr, "error: failed writing '%s'\n", output_fn);
		unlink(output_fn);
		return 1;
	}
	return 0;
}
