# RPCS3 on the PS5

This title's program is [RPCS3](https://rpcs3.net/), the PlayStation 3 emulator, from my
fork [PS5_RPCS3](https://github.com/KongaTime/PS5_RPCS3). RPCS3's developers make the
emulator; the fork adds what the console needs (`__PROSPERO__` and `PS5` in its sources
and CMake), and its frontend for the console is in `rpcs3/ps5/` there.

**Not working yet.** It builds into a packaged title (`dist/PPSA99200/`, a 60 MB
`eboot.bin`) that starts on the console: on my PS5 (PS5_RPCS3 cdca878) RPCS3
initialised the emulator, reported "PS3 system software: missing" (none installed),
and stopped cleanly. It plays nothing yet: no game has been booted, nothing is drawn.
What is proven, and what is not, is in the commit messages of both repositories.

**Licence.** RPCS3 is GPL-2.0-only and the PS5 platform layer it links is
GPL-3.0-or-later: the two cannot be combined in one program that is shared. Build it
for your own console from source; do not share the builds. No games, firmware or keys
are or will be provided: install the PS3 system software from Sony's own
`PS3UPDAT.PUP`, and use dumps of games you own.

## How the pieces fit

| Piece | Where | What |
| --- | --- | --- |
| RPCS3's emulator core and the PS5 frontend | PS5_RPCS3, beside this repository | `rpcs3_emu`, `rpcs3_ps5` and their libraries |
| `rpcs3/build-rpcs3.sh` | here | cross-builds the fork into `build/rpcs3/` (clang 19 or later) |
| `rpcs3/build-ffmpeg.sh` | here | FFmpeg 8.1.1 for the console (RPCS3's video and audio decoding) |
| `rpcs3/build-libiconv.sh` | here | GNU libiconv 1.18 for the console (`cellL10n`'s text encodings) |
| `rpcs3/clang-scan-deps-ps5` | here | C++20 module scanning with the console compiler's flags (OpenAL Soft) |
| `rpcs3/rpcs3.cmake` | here | joins `title_main.cpp` to the title and RPCS3's archives to its link |
| `rpcs3/title_main.cpp` | here | the program: reads the controllers, starts RPCS3 |

RPCS3's Vulkan calls go through the foundation's volk to the RADV the title links. Its
files live in `/app0/rpcs3/` (the configuration, `dev_hdd0`), its caches and log in
`/app0/rpcs3/cache/` (`RPCS3.log`). Its warnings and errors reach klog, and each step
of the start, with those warnings and errors, goes to `/app0/rpcs3-trace.txt`, which
FTP can read without klog.

The controllers: players 1 to 4 are the console's controllers. OPTIONS is START, the
touch pad's click is SELECT; the PS button stays the console's.

## Building

With the stack beside this repository (`ps5/tools/bootstrap.sh`), with
`../PS5_PayloadSDK` my fork ([KongaTime/PS5_PayloadSDK](https://github.com/KongaTime/PS5_PayloadSDK):
the SDK pin, `220b1be`, adds `pathconf`), and PS5_RPCS3 cloned as `../PS5_RPCS3` with
its submodules (LLVM's and OpenCV's are not needed yet):

```bash
rpcs3/build-rpcs3.sh rpcs3_ps5 Fusion     # FFmpeg and libiconv first, then RPCS3
PS5_CLANG=clang-20 ps5/tools/build.sh     # the title, linked with RPCS3, in dist/PPSA99200/
```

Then copy `dist/PPSA99200/` to the console's `/data/homebrew/` (`ps5/tools/deploy.sh`).

`PS5_CLANG` names the clang whose compiler-rt the link takes: the same version the SDK
compiles with (the newest `llvm-config` it finds), or the link stops on a missing
`libclang_rt.builtins-x86_64.a`.

## Running

`/app0/rpcs3-boot.txt` (the title's folder on the console) names what to boot, on its
first line: an ELF, or a game's folder. Without it RPCS3 starts, reports in klog whether
the PS3 system software is installed, and stops.

## Not done

- LLVM: the PPU and SPU recompilers are off, so games run on the interpreters, far too
  slow to play.
- Sound (the null backend), firmware and package installation, a game list.
- The console's 16 KiB pages against RPCS3's 4 KiB memory protection, and its
  thread-local storage (emulated on the console: every access is a call).
