# Experimental GTE precision capture

This is the first implementation milestone toward geometry stabilization. It
retains fractional screen coordinates that the existing GTE discards when it
writes SXY. **It does not yet change rendered graphics and is not an installable
PGXP core.** No production menu option is exposed.

## Implemented

`rtl/gte_precision.vhd` is a separate metadata FIFO connected to the GTE's
existing projection results. The native calculation, registers, flags, busy
logic, and savestate format are unchanged. `gte` has a `PRECISION_CAPTURE`
generic, defaulting to `false`; normal core instantiations keep that default.
The disabled generate branch drives zero metadata and does not instantiate the
capture module. This structural exclusion is not a measured Quartus timing or
bitstream-equivalence result.

With the generic enabled and `precision_enable = '1'`:

- Reads of SXY0, SXY1, SXY2 and SXYP (12–15) return precision metadata alongside
  the existing registered `gte_readData`. SXYP aliases SXY2.
- `precision_read_x/y` are signed 32-bit Q16.16 coordinates. They retain MAC0
  projection fractions; earlier matrix, divide, and widescreen rounding remains.
- `precision_read_valid` identifies a valid paired response. It and the
  coordinates hold until the next read, just like native read data; validity is
  **not an event pulse**. A future consumer must use the corresponding read
  transaction, and use the original integer response when validity is zero.
- Native FIFO shifts, simultaneous read/write behavior, and projection priority
  over direct writes are mirrored without feeding back into the GTE.
- Direct writes to SXY0/1/2 invalidate that slot. Writing SXYP shifts older
  metadata and invalidates the newly written slot, even if its integer word
  matches an older projection. Other register reads return invalid metadata.
- A clipped X or Y, or the GTE's divide-overflow flag, invalidates a projection.
  The flag is cumulative within RTPT, so later vertices can conservatively fall
  back after an earlier vertex overflowed.
- Reset, savestate loading, `SS_reset`, and runtime disabling invalidate all
  metadata, including while CE is low. Re-enabling does not restore it.

There is no CPU/memory/DMA propagation, depth metadata, subpixel rasterizer,
perspective texture correction, or saved precision state yet. The production
core leaves the new outputs disconnected.

## Run the tests

Requires Python 3, Git, and GHDL with VHDL-2008 and synthesis support. From the
repository root:

```sh
python3 sim/gte_precision/run.py
# Or select a simulator explicitly:
python3 sim/gte_precision/run.py --ghdl /absolute/path/to/ghdl
```

The runner builds in a temporary directory and deletes it on exit. It reads
the original GTE and its arithmetic units from pinned Git revision
`cd17b5a0ad261005c321d9d5ba41b8dbe313a7d3`; that commit must exist locally.
It compiles that baseline into a separate library and tests the current source
with capture both enabled and disabled. Existing `synthesis translate_off`
debug loggers are removed from temporary copies in both libraries because their
hardcoded Windows filename would make all instances write the same file. No
synthesizable source is removed or rewritten.

The tests cover:

- Known positive/negative fractional projections with an independently computed
  identity-transform result, RTPS and all three RTPT vertices, all widescreen
  modes, FIFO aliases, direct writes, read/write overlap, and CE stalls.
- Integer clipping boundaries, divide overflow, reset, savestate invalidation,
  disable/re-enable, and simultaneous projection/write priority.
- Every original output against the baseline each clk2x cycle: native read
  data, busy, savestate read data/idle, and debug status. A deterministic stress
  sequence exercises all 22 supported opcodes, every register, command selector
  variations, normal/turbo modes, and all widescreen modes.
- Alignment of every valid precision response with its original integer word.
- GHDL synthesis of the capture module as a synthesizability smoke test.

Initial validation passed using GHDL 6.0.0 on macOS: the FIFO tests, 16,849
clk2x cycles of differential checks in both builds, and the synthesis smoke test.
The unmodified baseline
emits startup `TO_INTEGER` metavalue warnings before its savestate address
register initializes; these are also emitted by both current instances.
Assertion failures fail the runner. These are synthetic tests, not exhaustive
equivalence checking or game compatibility tests.

## Remaining milestones

1. Propagate tagged coordinates through CPU register transfers and RAM writes,
   invalidate tags on partial/unsupported writes, then preserve provenance
   across DMA and GPU packet assembly. Integer-coordinate matching alone is not
   sufficient: distinct vertices can share the same packed screen coordinate.
2. Add optional subpixel triangle coverage/interpolation, with reliable fallback
   and deliberate handling of drawing offsets, clipping, and VRAM readback.
3. Obtain baseline/enhanced Quartus utilization and timing reports, compare
   guest-visible GPU/DMA timing and video/audio traces, then test games on the
   exact SuperStation hardware/firmware. Identify Retro Remake fork differences
   before producing a compatible RBF.

No claim of zero performance/compatibility impact is justified yet. Quartus and
SuperStation hardware validation were not available for this milestone, and no
console files or firmware were changed.
