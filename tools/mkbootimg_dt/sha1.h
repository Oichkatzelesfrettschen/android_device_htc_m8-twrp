/* SPDX-License-Identifier: Apache-2.0 */
/* RFC 3174 SHA-1, sized only for the boot header's id field: a 20-byte
 * digest over kernel, ramdisk, second stage and device-tree payloads plus
 * their length fields, matching the digest AOSP's own mkbootimg computes
 * for the same header layout. hboot's QCDT loader does not verify this
 * field on this device; it exists so a repack of identical inputs produces
 * a byte-identical header, the same property AOSP's own tool provides. */
#ifndef _SHA1_H_
#define _SHA1_H_

#include <stdint.h>
#include <string.h>

typedef struct {
	uint32_t state[5];
	uint64_t count;
	uint8_t buffer[64];
	size_t buffer_len;
} sha1_ctx;

static inline uint32_t sha1_rol(uint32_t v, int s) { return (v << s) | (v >> (32 - s)); }

static inline void sha1_block(sha1_ctx *ctx, const uint8_t *p) {
	uint32_t w[80];
	int i;
	for (i = 0; i < 16; i++)
		w[i] = ((uint32_t)p[i * 4] << 24) | ((uint32_t)p[i * 4 + 1] << 16) |
		       ((uint32_t)p[i * 4 + 2] << 8) | (uint32_t)p[i * 4 + 3];
	for (i = 16; i < 80; i++)
		w[i] = sha1_rol(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);

	uint32_t a = ctx->state[0], b = ctx->state[1], c = ctx->state[2],
		 d = ctx->state[3], e = ctx->state[4];

	for (i = 0; i < 80; i++) {
		uint32_t f, k;
		if (i < 20) {
			f = (b & c) | ((~b) & d);
			k = 0x5A827999U;
		} else if (i < 40) {
			f = b ^ c ^ d;
			k = 0x6ED9EBA1U;
		} else if (i < 60) {
			f = (b & c) | (b & d) | (c & d);
			k = 0x8F1BBCDCU;
		} else {
			f = b ^ c ^ d;
			k = 0xCA62C1D6U;
		}
		uint32_t t = sha1_rol(a, 5) + f + e + k + w[i];
		e = d;
		d = c;
		c = sha1_rol(b, 30);
		b = a;
		a = t;
	}

	ctx->state[0] += a;
	ctx->state[1] += b;
	ctx->state[2] += c;
	ctx->state[3] += d;
	ctx->state[4] += e;
}

static inline void sha1_init(sha1_ctx *ctx) {
	ctx->state[0] = 0x67452301U;
	ctx->state[1] = 0xEFCDAB89U;
	ctx->state[2] = 0x98BADCFEU;
	ctx->state[3] = 0x10325476U;
	ctx->state[4] = 0xC3D2E1F0U;
	ctx->count = 0;
	ctx->buffer_len = 0;
}

static inline void sha1_update(sha1_ctx *ctx, const void *data, size_t len) {
	const uint8_t *p = (const uint8_t *)data;
	ctx->count += len;
	while (len > 0) {
		size_t take = 64 - ctx->buffer_len;
		if (take > len)
			take = len;
		memcpy(ctx->buffer + ctx->buffer_len, p, take);
		ctx->buffer_len += take;
		p += take;
		len -= take;
		if (ctx->buffer_len == 64) {
			sha1_block(ctx, ctx->buffer);
			ctx->buffer_len = 0;
		}
	}
}

static inline void sha1_final(sha1_ctx *ctx, uint8_t out[20]) {
	uint64_t bit_len = ctx->count * 8;
	uint8_t pad = 0x80;
	sha1_update(ctx, &pad, 1);
	uint8_t zero = 0;
	while (ctx->buffer_len != 56)
		sha1_update(ctx, &zero, 1);
	uint8_t len_be[8];
	for (int i = 0; i < 8; i++)
		len_be[i] = (uint8_t)(bit_len >> (56 - 8 * i));
	/* direct block append: buffer_len is exactly 56 here */
	memcpy(ctx->buffer + 56, len_be, 8);
	sha1_block(ctx, ctx->buffer);
	for (int i = 0; i < 5; i++) {
		out[i * 4] = (uint8_t)(ctx->state[i] >> 24);
		out[i * 4 + 1] = (uint8_t)(ctx->state[i] >> 16);
		out[i * 4 + 2] = (uint8_t)(ctx->state[i] >> 8);
		out[i * 4 + 3] = (uint8_t)(ctx->state[i]);
	}
}

#endif
