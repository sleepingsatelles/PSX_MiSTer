# SuperStation One hardware and installation compatibility

## What hardware and MiSTer compatibility are confirmed?

### Takeaway
Assuming the user means SuperStation One, Retro Remake explicitly supports MiSTer cores. The manufacturer confirms Cyclone V and 128 MB SDRAM, but the exact FPGA part and any extra usable resources over DE10-Nano were not established from primary documentation.

### Cited Findings
- The manufacturer describes full MiSTer platform support without a jailbreak, specifies a Cyclone V FPGA and 128 MB BGA SDRAM, and lists microSD/USB game storage plus native PlayStation SNAC connections. — [Retro Remake product overview](https://retroremake.co/pages/superstation%E1%B5%92%E2%81%BF%E1%B5%89)
- Terasic specifies DE10-Nano's FPGA as Cyclone V SE 5CSEBA6U23I7 with 110K logic elements. — [Terasic specifications](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=139&Language=English&No=1046&PartNo=2)
- Retro Remake's official firmware page links the SuperStation documentation, SD installer, and Console Mode distribution. This validates the Taki-hosted documentation as a manufacturer-endorsed source. — [Firmware/setup](https://retroremake.co/pages/firmware-setup)

### Inferences
- General MiSTer compatibility makes a suitably built enhancement core a plausible eventual installation target, but does not establish available FPGA resources or a zero-performance-impact implementation.

### Gaps
- Exact unit/revision/firmware used by this user is unknown. No primary-source exact SuperStation part number was verified. Secondary reports claim 5CSXFC6D6F31I7N, but avoid making a precise capacity comparison based on those reports alone.

## Is there a manufacturer PGXP core, and what integration matters?

### Takeaway
No manufacturer PGXP build was found. A Retro-Remake PSX fork exists; do not assume replacing it with an arbitrary upstream build preserves every SuperStation function.

### Cited Findings
- The Retro-Remake PSX fork README lists texture filtering, 24-bit rendering, widescreen, dithering control, and native SNAC input; its fetched README contains no PGXP entry. — [Retro-Remake PSX_MiSTer](https://github.com/Retro-Remake/PSX_MiSTer)
- Manufacturer-endorsed documentation covers PlayStation SNAC-port1/port2, real memory cards, dock SNAC bypass, and subcarrier video support. It notes some cores lack subcarrier support. It also describes dock NVMe dependencies on updated Linux files. — [SuperStation documentation](https://github.com/Takiiiiiiii/SuperStation-Documentation/blob/main/README.md)
- Console Mode bundles a custom frontend, host executable, and menu FPGA core; some releases also require particular Linux image/kernel files. — [Console Mode distribution](https://github.com/Retro-Remake/ConsoleMode_Distribution)

### Inferences
- An eventual PGXP test build needs explicit testing of the user's controllers/memory cards, analog or HDMI output, and Console Mode/dock workflow in addition to game graphics and timing.
- The existence of a vendor fork is reason to verify differences, not proof that upstream PSX does not work.

### Gaps
- GitHub web fetches of the vendor fork's PSX.sv, PSX.qsf, releases directory, commits, and compare view failed. A direct shell GitHub API request also failed DNS. Therefore no verified vendor-versus-upstream code difference or current fork commit is established here.
- Searches for SuperStation + PGXP and Retro-Remake + PGXP yielded no reliable installable implementation; this is a bounded search result, not proof no private experiment exists.

## How should a future test build be installed without replacing the working setup?

### Takeaway
MiSTer supports separate menu entries for RBF cores, so a future validated build can be staged separately. There is no verified PGXP artifact to install now.

### Cited Findings
- MiSTer documentation permits custom underscore-prefixed menu folders and specifies MGL RBF paths relative to SD root, with PSX examples using `_console/psx`. — [MiSTer MGL documentation](https://mister-devel.github.io/MkDocs_MiSTer/advanced/mgl/)
- The manufacturer's documentation explains downloader filters for preventing unwanted redownloads and recommends resetting altered PSX unsafe options when diagnosing compatibility problems. — [SuperStation documentation](https://github.com/Takiiiiiiii/SuperStation-Documentation/blob/main/README.md)
- Its provided downloader.ini disables Linux updates by default and includes optional experimental core repositories. — [Official recommended downloader configuration](https://raw.githubusercontent.com/Takiiiiiiii/SuperStation-Documentation/main/INI_Files/downloader.ini)

### Inferences
- Proposed future workflow: identify the exact installed core/firmware and relevant vendor changes; retain a copy of the working SD and saves; put a validated test RBF in a separate custom menu folder or spare SD; launch manually through MiSTer for testing; ensure updates do not replace the experiment. Avoid replacing the whole host/Linux installation merely to test graphics changes.
- A filename/menu separation alone may not isolate saves and core configuration; use a spare SD or carefully configured separate MGL name/config when required.

### Gaps
- No actual installation attempted, no device access available, and no tested PGXP RBF identified. Instructions above are a proposed staging approach, not a claim of validated SuperStation PGXP compatibility.
