# RPCS3 for the PS5 - RPCS3 as the title's program (included by ps5/CMakeLists.txt).
#
# The entry (rpcs3/title_main.cpp) joins the title's objects. The link takes
# RPCS3's PS5 frontend, its emulator core and every library they were built
# with: the archives rpcs3/build-rpcs3.sh left in build/rpcs3/ (built first),
# and the console's FFmpeg (rpcs3/build-ffmpeg.sh), as one group, since they
# refer to each other in every direction.
#
# Copyright (C) 2026 KongaTime
# SPDX-License-Identifier: MIT

target_sources(samples PRIVATE ${ROOT}/rpcs3/title_main.cpp)
# stb_image's code comes once, from RPCS3 (rpcs3/Emu/stb_image.cpp, v2.30);
# the foundation's glTF loader uses it instead of its own (v2.21)
target_compile_definitions(samples PRIVATE PS5_STB_IMAGE_ELSEWHERE)

set(rpcs3_build ${ROOT}/build/rpcs3)
if(NOT EXISTS ${rpcs3_build}/rpcs3/ps5/librpcs3_ps5.a)
	message(FATAL_ERROR "RPCS3 is not built: run rpcs3/build-rpcs3.sh rpcs3_ps5 first")
endif()

file(GLOB_RECURSE rpcs3_archives CONFIGURE_DEPENDS ${rpcs3_build}/*.a)
# RADV's archive is linked whole and carries zlib (1.3.1, Mesa's subproject):
# RPCS3's own copy (1.3.2, the same interface) would define it twice
# and FFmpeg is the console's (below), never upstream's Linux prebuilts
list(FILTER rpcs3_archives EXCLUDE REGEX "/libvulkan-placeholder\\.a$|/CMakeFiles/|/3rdparty/zlib/zlib/libz\\.a$|/3rdparty/ffmpeg/")
file(GLOB ffmpeg_archives CONFIGURE_DEPENDS ${ROOT}/.deps/native/ffmpeg-ps5/lib/*.a)

# libc functions the console lacks, which the platform layer this title pins has
# as ps5_<name> (ps5platform/libc.h) and PS5_Vulkan's recipe does not bind yet:
# asmjit's getpagesizes, Abseil's syscall, RPCS3's times, wolfSSL's accept4,
# miniupnpc's if_nametoindex and if_indextoname
set(rpcs3_libc_bindings)
foreach(name getpagesizes syscall times accept4 if_nametoindex if_indextoname)
	list(APPEND rpcs3_libc_bindings --defsym=${name}=ps5_${name})
endforeach()

set(PS5_TITLE_LINK_INPUTS --start-group ${rpcs3_archives} ${ffmpeg_archives} --end-group ${rpcs3_libc_bindings})
set(PS5_TITLE_LINK_DEPENDS ${rpcs3_archives})
list(LENGTH rpcs3_archives rpcs3_archive_count)
message(STATUS "RPCS3: linking ${rpcs3_archive_count} archives from ${rpcs3_build}")
