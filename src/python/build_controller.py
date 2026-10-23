"""Build the generated controller C code into a shared library (M5).

    python src/python/build_controller.py

Compiles every .c file in src/generated/controller/ except those that define
main() (rt_main.c: the GRT example main program, not part of the controller)
into
    build/controller.dll       on Windows
    build/libcontroller.so     on Linux (CI)
The same flags are used locally and in CI, from this one place:
    -O2                  normal optimization, as a real build would use
    -ffp-contract=off    no fused multiply-add: a*b + c must be rounded twice,
                         as in MATLAB; FMA rounds once and changes the last bits
    -shared (-fPIC)      a library that Python loads with ctypes

Compiler: $CC if set; on Windows otherwise MATLAB's MinGW-w64 add-on
($MW_MINGW64_LOC or its default install folder); else gcc on the PATH. The
compiler must produce code for the same bitness as Python (64 bit): a 32-bit
gcc gives a library that 64-bit Python cannot load.
"""
import glob
import os
import platform
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "src" / "generated" / "controller"
BUILD = ROOT / "build"
LIB = BUILD / ("controller.dll" if os.name == "nt" else "libcontroller.so")
FLAGS = ["-O2", "-ffp-contract=off"]


def find_gcc():
    """Path of the C compiler to use (see module docstring for the order)."""
    if os.environ.get("CC"):
        return os.environ["CC"]
    if os.name == "nt":
        roots = [os.environ.get("MW_MINGW64_LOC", "")]
        roots += glob.glob("C:/ProgramData/MATLAB/SupportPackages/*/3P.instrset/mingw_w64.instrset")
        for r in roots:
            gcc = Path(r) / "bin" / "gcc.exe"
            if r and gcc.is_file():
                return str(gcc)
    gcc = shutil.which("gcc")
    if not gcc:
        sys.exit("No gcc found: install MATLAB's MinGW-w64 add-on (Windows) or gcc (Linux), or set CC")
    return gcc


def sources():
    """Generated .c files without a main() function, sorted for a stable build."""
    files = sorted(SRC.glob("*.c"))
    if not files:
        sys.exit(f"No C files in {SRC}: run generate_controller_code() in MATLAB first")
    has_main = re.compile(r"\bint\s+main\s*\(")
    return [f for f in files if not has_main.search(f.read_text(encoding="utf-8", errors="replace"))]


def main():
    gcc = find_gcc()
    # Bitness check: '-dumpmachine' names the target, e.g. x86_64-w64-mingw32
    target = subprocess.run([gcc, "-dumpmachine"], capture_output=True, text=True).stdout.strip()
    py64 = struct.calcsize("P") == 8
    if py64 and not re.match(r"(x86_64|amd64|aarch64)", target):
        sys.exit(f"{gcc} builds for '{target}' (32 bit), but Python is 64 bit: use a 64-bit gcc")

    files = sources()
    BUILD.mkdir(exist_ok=True)
    cmd = [gcc, "-shared", *FLAGS, f"-I{SRC}", *map(str, files), "-o", str(LIB)]
    if os.name == "nt":
        cmd.append("-static-libgcc")     # no extra MinGW runtime DLL needed next to the library
    else:
        cmd[2:2] = ["-fPIC"]
        cmd.append("-lm")
    print(f"{Path(gcc).name} ({target}) on {platform.system()}: {', '.join(f.name for f in files)}")
    subprocess.run(cmd, check=True)
    print(f"-> {LIB.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
