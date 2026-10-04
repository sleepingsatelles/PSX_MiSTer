#!/usr/bin/env python3
"""Run self-contained GHDL tests against a pinned, unmodified GTE baseline."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASELINE = "cd17b5a0ad261005c321d9d5ba41b8dbe313a7d3"
SOURCES = ("pGTE.vhd", "gte_mac0.vhd", "gte_mac123.vhd", "gte_UNRDivide.vhd", "gte.vhd")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghdl", default=os.environ.get("GHDL", "ghdl"))
    args = parser.parse_args()
    ghdl = shutil.which(args.ghdl)
    if not ghdl:
        parser.error("GHDL is required; pass --ghdl /absolute/path/to/ghdl")

    with tempfile.TemporaryDirectory(prefix="psx-gte-precision-") as temporary:
        build = Path(temporary)

        def run(*arguments):
            subprocess.run([ghdl, *arguments], cwd=build, check=True)

        def simulation_source(source, name):
            # Upstream simulation-only loggers hardcode a shared Windows path.
            # Remove only explicitly marked translate_off regions, identically
            # for both libraries. No synthesizable RTL is changed.
            source = re.sub(rb"-- synthesis translate_off.*?-- synthesis translate_on",
                            b"", source, flags=re.DOTALL)
            path = build / name
            path.write_bytes(source)
            return str(path)

        # Baseline dependencies also come from the pinned revision. Separate
        # libraries prevent the DUT from accidentally being its own reference.
        for filename in SOURCES:
            original = subprocess.check_output(
                ["git", "show", f"{BASELINE}:rtl/{filename}"], cwd=ROOT
            )
            run("-a", "--std=08", "--work=baseline",
                simulation_source(original, "baseline_" + filename))

        for filename in (*SOURCES[:-1], "gte_precision.vhd", "gte.vhd"):
            run("-a", "--std=08", simulation_source(
                (ROOT / "rtl" / filename).read_bytes(), "current_" + filename))
        for test in ("tb_precision", "tb_gte_precision"):
            run("-a", "--std=08", str(Path(__file__).parent / f"{test}.vhd"))
            run("-e", "--std=08", test)
            run("-r", "--std=08", test, "--assert-level=error", "--ieee-asserts=disable-at-0")
        # Portable synthesizability smoke test, not Quartus fit/timing analysis.
        subprocess.run([ghdl, "--synth", "--std=08", "gte_precision"], cwd=build,
                       stdout=subprocess.DEVNULL, check=True)
        print(f"PASS: precision FIFO, GTE differential tests, synthesis smoke test (baseline {BASELINE})")


if __name__ == "__main__":
    main()
