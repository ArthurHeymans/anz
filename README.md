# ANZ: adaptive-nibble LZ

An LZ77 codec with LZMA-class adaptive modelling, coded as 16-symbol
(nibble) alphabets with rANS, so a literal takes two decode steps instead of
eight. On coreboot stages it is within 1.1% of LZMA's size and decodes 1.7x
faster, with a 2.9 KB decoder.

## Numbers

Corpus: 28 coreboot stages (romstage, ramstage and postcar from 10 boards),
3,646,560 bytes. Decode time is the sum of per-stage medians on an Intel N100
core, built with gcc `-O2 -march=x86-64-v2`. Decoder size is `.text + .rodata`
at x86-64 `-Os`.

| codec | bytes | vs LZSA2 | decode | decoder | RAM |
|---|---:|---:|---:|---:|---:|
| LZMA (coreboot, lc3) | 1,565,241 | −12.8% | 101.0 ms | 3.6 KB | 16 KB |
| **ANZ** | 1,581,693 | −11.9% | **60.0 ms** | 2.9 KB | 83 KB |
| ANZ, scalar (no SSE2) | 1,581,693 | −11.9% | 196 ms | 2.6 KB | 83 KB |
| zstd -19 (coreboot decoder) | 1,665,519 | −7.2% | 6.6 ms | 41 KB | 96 KB |
| [FHL](https://github.com/ArthurHeymans/fhl) | 1,718,463 | −4.3% | 5.8 ms | 3.5 KB | 45 KB |
| LZSA2, [lzsa2-fast](https://github.com/ArthurHeymans/lzsa2-fast) | 1,795,384 | 0 | 6.4 ms | 1.9 KB | 0 |

ANZ is for cases where flash bytes matter more than decode time: a slow SPI
bus, or decoding that overlaps the flash read. When boot-time load cost is
modelled as flash read plus decode, ANZ comes out best at 15 MHz single-I/O
for a sequential load, and at 48 MHz quad for an overlapped one. Elsewhere
the winner is LZMA (overlapped, slower buses) or FHL (sequential). This is a
host model, not a measurement on real boot hardware.

## Design

- **rANS:** 64-bit state, 15-bit probabilities, one branchless 32-bit
  renormalisation per symbol. Two interleaved states, so consecutive symbols
  do not wait on each other.
- **Models:** every model is a CDF of up to 16 symbols. After each symbol it
  moves towards the coded symbol with an AV1-style shift (faster for the
  first 16 and 32 updates). A fixed floor keeps every probability at least
  32/32768. With SSE2 the symbol search and the update are two 8-lane
  operations each.
- **Literals:** the high nibble uses the previous byte as context. The low
  nibble uses the high nibble plus the top `lclo` bits of the previous byte.
  Each of these sparse models is averaged with a dense one keyed by fewer
  bits. The first literal after a match is coded against the match byte
  instead (LZMA's matched literal, at nibble level).
- **Commands:** literal-run and match-length codes as in FHL, with their
  extra bits raw. The context is the previous match-length code, whether the
  run was empty, whether the last match was a rep, and position bits.
- **Distances:** 3 rep distances plus 40 slots, coded as a 6-ary high part
  (context: match length) and an 8-ary low part. Slot extra bits are raw,
  except for an adaptive 4-bit align field.
- **Raw bits** travel in a second, forward stream.

The parse comes from FHL's optimal parser, priced with ANZ's literal contexts.
The encoder tries five pricing settings and keeps the smallest stream.

## Use

```c
#include "anz.h"
static uint64_t work[ANZ_WORK_SIZE / 8] __attribute__((aligned(16)));
size_t n = anz_decode(src, src_len, dst, dst_cap, work);   /* 0 on a bad header */
```

Build with `-DANZ_DECODER_ONLY` to get just `anz_decode()`. Building with
`-DANZ_SCALAR`, or for a target without SSE2, selects the portable (3x
slower) symbol decoder; both decoders read the same streams.

```
make            # anz c [-l 0..6] in out ; anz d in out
make test       # round trips under ASan/UBSan, SSE2 and scalar
```

The encoder verifies every stream it writes and runs at about 0.35 MB/s.

## Limitations

- The decoder trusts the stream beyond its header. Use it on streams you
  produced or have verified, for example by hash.
- The SSE2 decoder needs SSE2 in the firmware stage that decompresses.
  coreboot builds x86 stages with `-mno-sse`, so the decoder would need a
  target attribute.
- There is no stored mode: incompressible data grows by about 3%.
- The window is 1 MiB.

## License

MIT, see [LICENSE](LICENSE).
