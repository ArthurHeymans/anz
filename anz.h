/* SPDX-License-Identifier: MIT */
#ifndef ANZ_H
#define ANZ_H

#include <stddef.h>
#include <stdint.h>

/* Bytes of 16-byte aligned work memory anz_decode() needs for its models. */
#define ANZ_WORK_SIZE (83 * 1024)

/*
 * Decompress the ANZ stream src[0..n) into dst[0..cap). Returns the
 * decompressed size, or 0 if the header is invalid or the output does not
 * fit. The decoder trusts the stream beyond its header: feed it only streams
 * you produced or verified (e.g. by hash).
 */
size_t anz_decode(const void *src, size_t n, void *dst, size_t cap, void *work);

/* Compress in[0..n) into out (n * 2 + 4096 bytes); returns the size. */
size_t anz_compress(const uint8_t *in, uint32_t n, unsigned lclo, uint8_t *out);

#endif
