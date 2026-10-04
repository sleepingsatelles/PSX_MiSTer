# Technical feasibility of PGXP-style PSX MiSTer enhancement

## What must change beyond preserving fractional GTE coordinates?

### Takeaway
Geometry stabilization is technically plausible as a research project; full PGXP functionality is a system-wide metadata and rasterizer addition, not a filter or small GTE precision switch. The source alone does not establish that it fits or meets timing on the SuperStation.

### Cited Findings
- Inspected local checkout is commit `cd17b5a0ad261005c321d9d5ba41b8dbe313a7d3` (2026-08-21), remote `https://github.com/sleepingsatelles/PSX_MiSTer.git`, initially clean. Its README lists filtering, 24-bit rendering, widescreen, dithering but no PGXP. No PGXP text found in README/RTL/top level. This is evidence about this checkout, not every public fork. — [local README](/Users/cwagner/Documents/projects/PSX_MiSTer/README.md:6)
- At GTE screen-coordinate push, X and Y take MAC0 bits 31:16, discarding fractional bits, with original range clamps and flags. — [gte.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gte.vhd:1311)
- CPU/GTE interface carries 32-bit data; GTE integer screen registers enter CPU execution and stores. — [cpu.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/cpu.vhd:58), [SWC2 path](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/cpu.vhd:1689)
- GPU input accepts CPU bus writes and DMA words through the same 32-bit FIFO; parser extracts integer X/Y and texture U/V. Its vertex record has integer x/y and no z. — [GPU FIFO](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu.vhd:824), [vertex record](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu_poly.vhd:131), [position parser](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu_poly.vhd:495)
- Rasterizer increments U/V by fixed per-pixel gradients. — [texture stepping](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu_poly.vhd:1096)
- DuckStation PGXP allocates parallel register and memory metadata, propagates it through operations including SWC2, and resolves precise GPU vertices by address plus validation of original packet value. Invalid matches fall back to native geometry. — [cpu_pgxp.cpp, Initialize, CPU_SWC2, GetPreciseVertex](https://github.com/stenzek/duckstation/blob/master/src/core/cpu_pgxp.cpp)
- DuckStation distinguishes perspective textures, geometry precision, culling correction, CPU tracking, and depth testing. Its UI notes CPU mode can fix additional games at high performance cost, geometry tolerance is a workaround, and 2D polygons can need native coordinates. — [official graphics settings source](https://github.com/stenzek/duckstation/blob/master/src/duckstation-qt/graphicssettingswidget.cpp)

### Inferences
- Retaining the discarded fractional bits can reduce one major source of wobble, but cannot restore precision already lost earlier or replace full PGXP CPU arithmetic tracking. This is a narrower enhancement worth naming accurately.
- A correct implementation must associate each eventual GPU vertex with its retained coordinates despite intervening GTE register moves, CPU loads/stores, RAM copies, partial writes, and DMA lists. Coordinate-only caches can misassociate distinct vertices at the same integer location; address-tagged, value-validated metadata is the stronger design.
- Perspective textures additionally need depth and interpolation of u/z, v/z, and 1/z (or an equivalent scheme), followed by division. Preserving X/Y alone does not fix texture warping.
- A display postprocessing shader cannot exactly recover per-vertex depth and lost subpixel coordinates from the final picture. This work belongs inside or alongside the geometry/render path.

### Gaps
- No implemented PGXP extension, benchmark, or fitted prototype in this checkout. Other agents cover external implementation discovery.
- No estimate of logic, DSP, memory bandwidth or timing margin is justified without synthesis and measurement.

## Can this preserve all existing performance and behavior?

### Takeaway
Unchanged game timing is a reasonable engineering target, not a proven property. Literal zero other impact is too strong: additional hardware consumes resources, and enhanced rendering can affect both workload and game-visible VRAM unless explicitly isolated.

### Cited Findings
- GPU ready-to-receive status is restored on rendering completion; DMA readiness depends on input FIFO emptiness. Thus rendering and externally visible scheduling are coupled in this implementation. — [gpu.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu.vhd:978)
- DMA uses GPU request state for transfer triggering/stalling. — [dma.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/dma.vhd:216)
- Polygon engine has reproducible timing logic which waits for a target before completion, but this is not a guarantee of slack for arbitrary extra work. — [gpu_poly.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu_poly.vhd:1145)
- GPU has VRAM readback/transfer operations, texture cache invalidation, and a shared VRAM request/write path. — [gpu.vhd](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu.vhd:988), [VRAM arbitration](/Users/cwagner/Documents/projects/PSX_MiSTer/rtl/gpu.vhd:1594)
- Project targets Cyclone V device 5CSEBA6U23I7; configuration explicitly disables ALSA to save resources. These are not measurements of remaining capacity. — [sys.tcl](/Users/cwagner/Documents/projects/PSX_MiSTer/sys/sys.tcl:1), [PSX.qsf](/Users/cwagner/Documents/projects/PSX_MiSTer/PSX.qsf:65)

### Inferences
- FPGA parallelism can avoid extra guest cycles if the sidecar has independent resources and completes before existing deadlines. It does not make area, routing, bandwidth or timing-closure costs disappear.
- Changing covered pixels changes render workload. If enhancement delays completion or FIFO draining, GPU status/DMA/CPU behavior may change. Preserve original timing using original integer geometry for timing/accounting, and validate completion remains within deadlines.
- For an unusually strict requirement that every CPU-visible value and timing remain identical, enhanced VRAM cannot simply replace canonical VRAM wherever games can read it or use it as texture input. A separate presentation path/canonical VRAM treatment may be necessary and costs substantially more resources.
- Keeping culling calculations/flags game-visible and unchanged is important; adding PGXP-like corrected NCLIP would intentionally alter values software may use for decisions.
- A runtime Off switch can select the original behavior, but added routed logic still occupies the FPGA. A separate stock binary is the simplest trustworthy fallback; a disabled-option build also requires regression testing.

### Gaps
- No `*.fit.summary`, `*.sta.summary`, or `*.rpt` resource/timing reports found in tracked checkout scan. No Quartus build was run and no device was connected. Do not claim the FPGA is full, nor claim enough spare capacity.
- Exact SuperStation board variant and deployed core version were not established in this subtask.

## What is a credible bounded proof of concept?

### Takeaway
Start with a geometry-only, memory-tracked subset and explicit fallback, then measure feasibility before extending to perspective texture correction. This is a proposed architecture, not an available core or a promise of compatibility.

### Cited Findings
- Existing source offers GTE simulation and whole-system simulation/test scaffolding suitable as starting points. — [GTE testbench](/Users/cwagner/Documents/projects/PSX_MiSTer/sim/gte/src/tb/tb.vhd), [system testbench](/Users/cwagner/Documents/projects/PSX_MiSTer/sim/system/src/tb/tb.vhd)
- Precise-vertex fallback to original geometry is established practice in software PGXP. — [DuckStation GetPreciseVertex](https://github.com/stenzek/duckstation/blob/master/src/core/cpu_pgxp.cpp)

### Inferences
1. Establish exact hardware and baseline bitstream; obtain successful stock synthesis with ALM/register/DSP/BRAM use, external-memory bandwidth and setup/hold timing margin.
2. In simulation, retain fractional X/Y beside original GTE screen FIFO without changing original registers, flags, busy timing or integer outputs. Initially handle unsaturated RTPS/RTPT output, SWC2 and simple MFC2/memory copies; invalidate unsupported arithmetic or partial overwrites.
3. Track metadata using address/value tags, propagate it into DMA and CPU GPU-write sidebands, and instrument hit/miss/invalid/overflow cases. Never stall canonical execution to wait for missing metadata; miss means native geometry.
4. Add an experimental subpixel polygon path at original output resolution; leave perspective textures, corrected culling and depth buffering out of phase one. Preserve original drawing/timing accounting as far as architecture permits, but do not imply game-visible VRAM identity without addressing it.
5. Compare CPU/GTE registers, flags, bus transactions, GPU status, DMA completion, IRQ timing, frame cadence and audio with baseline; compare off-mode video/VRAM exactly. For on mode, inspect intended differences and investigate readback/render-to-texture effects. Test saturation, clipping, 2D UI, direct GPU writes, DMA lists, CPU-computed vertices, reset and savestate load.
6. Synthesize early and test on the actual board across difficult games. Success criterion: timing closure, no new stalls/underruns, measured stable throughput, bounded visual fallback and clear compatibility limits. FPS alone is insufficient evidence of equivalent timing.
7. Only after this works evaluate depth metadata plus perspective interpolation and any extra memory-port/bandwidth needs.

### Gaps
- No prototype exists from this research; no installation artifact was produced. Feasibility remains conditional until synthesis, simulation and actual hardware tests.
