# Prior PGXP work on MiSTer PSX

## Is there an existing PGXP implementation or installable core?

### Takeaway
As of the October 3, 2026 research session, I found no public, installable MiSTer PSX core implementing PGXP, nor a documented PGXP development fork. This is a bounded search result, not proof that no private or unindexed experiment exists.

### Cited Findings
- The official PSX core feature list includes texture filtering, 24-bit rendering, widescreen, dithering control, and other enhancements, but does not list PGXP, geometry precision correction, or perspective-correct texturing. [Official repository README](https://github.com/MiSTer-devel/PSX_MiSTer/blob/main/README.md)
- The official top-level hardware source wires texture filtering, filter strength, 2D filtering control, render24, and dithering into the core; the visible options and connections reviewed do not advertise PGXP. This provides source corroboration beyond the README, though it is not a full code audit. [PSX.sv](https://github.com/MiSTer-devel/PSX_MiSTer/blob/main/PSX.sv)
- The official release directory contains dated RBF files including PSX_20260807.rbf in the browsed listing. No PGXP-specific release was identified there. The directory was crawled roughly a month earlier, so do not assert this is the latest possible version on October 3. [Official release directory](https://github.com/MiSTer-devel/PSX_MiSTer/tree/main/releases)
- A December 2022 discussion of PSX 2X contains users asking whether PGXP could be implemented, rather than presenting an implementation. It is community discussion only and is not technical evidence of feasibility. [NeoGAF discussion](https://www.neogaf.com/threads/psx-2x-core-for-mister-fpga-creating-a-psx-pro-that-never-existed-and-its-out-now.1648385/)

### Inferences
- There is no verified PGXP binary to recommend installing from this investigation. The existing graphic enhancements should not be described as solving the same problem.
- Absence from the official feature list plus failure to discover a public fork supports “I could not find an available implementation,” not “impossible on FPGA.”

### Gaps
- Searches covered combinations of MiSTer, PSX_MiSTer, PGXP, FPGAzumSpass, RobertPeip, perspective correction, subpixel, geometry correction, and fork, including GitHub-targeted queries. No public implementation surfaced. These queries cannot enumerate all private Discord, Patreon, or unindexed source work.
- GitHub issue search URLs failed to load through the browser research tool; the unfiltered issue list loaded. A direct GitHub API request failed at DNS resolution in the execution environment. Do not report a verified zero issue count for PGXP.

## Has the developer considered perspective correction before?

### Takeaway
There is useful historical reporting that the PSX core developer considered perspective correction too costly for MiSTer in 2022. The direct Twitter thread could not be retrieved, so this must be attributed to the contemporary report, not presented as a newly verified developer quotation or a current impossibility result.

### Cited Findings
- In a May 2, 2022 MiSTer update, RetroRGB author Lu reported that the developer had said perspective correction's cost was too high for MiSTer. The same article separately describes the newly added texture filtering. [RetroRGB, May 2, 2022](https://retrorgb.com/mister-fpga-news-updates-new-public-jotego-cores-psx-filtering-32x-sound-fix-more.html)
- The report points to a “Perspective correction thread” at [Kamil Karpowicz Twitter status 1520131587765063683](https://twitter.com/kamilkarpowicz/status/1520131587765063683) and separately to [FPGAzumSpass texture-filtering announcement](https://twitter.com/AzumFpg/status/1520123269092986886). Both direct Twitter URLs returned tool errors; the X-form equivalent also failed.
- Contemporary community conversations in 2021 and 2022 asked for geometry stabilization/perspective correction, but the retrieved comments are not developer engineering studies. [2021 ResetEra discussion](https://www.resetera.com/threads/mister-fpga-system.81088/page-74), [2022 discussion](https://www.neogaf.com/threads/psx-2x-core-for-mister-fpga-creating-a-psx-pro-that-never-existed-and-its-out-now.1648385/)

### Inferences
- This idea has been raised before; it is not an obviously overlooked menu setting.
- The 2022 cost assessment is evidence of a practical implementation barrier at that time, not a proof that every possible reduced-scope approach or future implementation must fail.
- Recommended phrasing: “There was discussion of this: a May 2022 report attributed its absence to the developer judging perspective correction too costly for MiSTer. I could not retrieve the original thread, and I did not find a newer implementation.”

### Gaps
- No primary-source quantified resource budget, prototype benchmark, synthesis report, PGXP branch, or game compatibility study was found.
- The accessible report does not specify whether cost means FPGA logic, DSPs, memory bandwidth, development complexity, or some combination. Do not invent that specificity.
- No later primary maintainer statement reversing or confirming the 2022 assessment was located.

## What can the evidence say about zero performance or compatibility impact?

### Takeaway
The prior-work search does not support promising a PGXP enhancement with zero timing, performance, or compatibility impact. This question needs implementation measurements; it cannot be answered from the existence of unrelated graphics settings.

### Cited Findings
- DuckStation's actual PGXP implementation includes precision value propagation on CPU loads/stores and a vertex lookup path that uses validity/tolerance checks and falls back to native coordinates if higher-precision data cannot be recovered. In a vertex-cache branch, its own comment identifies a game-specific tradeoff: retaining Z can worsen the result even where jitter reduction is possible. [DuckStation CPU PGXP source](https://github.com/stenzek/duckstation/blob/master/src/core/cpu_pgxp.cpp)
- The official PSX core documentation demonstrates existing optional enhancements, but makes no PGXP performance guarantee. [Official README](https://github.com/MiSTer-devel/PSX_MiSTer/blob/main/README.md)

### Inferences
- PGXP is more involved than a final-image filter. The source illustrates why precision tracking and compatibility validation matter; the FPGA implementation feasibility and cost still require a design study.
- It is plausible to set unchanged game-visible timing and optional bypass as engineering goals, but claiming they are achieved before an implementation is synthesized and tested is unjustified.

### Gaps
- This subtask did not examine the user's SuperStation hardware, install anything, or run synthesis. Other research should establish exact board compatibility and resource constraints before making installation claims.
