/*
 * RPCS3 for the PS5 - the title's program: RPCS3's PS5 frontend.
 *
 * ps5/src/main.cpp calls this in place of the samples once the platform layer
 * is up (klog, the pad, the splash) and volk points at the RADV linked in.
 * The frontend is my fork's (PS5_RPCS3, rpcs3/ps5/ps5_frontend.h), linked from
 * its archives (rpcs3/rpcs3.cmake).
 *
 * What it boots: the first line of /app0/rpcs3-boot.txt (an ELF, or a game's
 * folder), if there is one; else RPCS3 starts, reports the PS3 system software
 * it finds, and stops.
 *
 * Copyright (C) 2026 KongaTime
 * SPDX-License-Identifier: MIT
 */

#include "platform.h"

#include <fstream>
#include <string>

int rpcs3_ps5_run(const char *boot_path);

extern "C" int ps5_title_main(void)
{
	std::string boot;
	if (std::ifstream file{"/app0/rpcs3-boot.txt"}) {
		std::getline(file, boot);
		while (!boot.empty() && (boot.back() == '\r' || boot.back() == ' '))
			boot.pop_back();
	}
	say("RPCS3: %s", boot.empty() ? "starting without a game" : boot.c_str());
	const int status = rpcs3_ps5_run(boot.c_str());
	say("RPCS3: stopped, status %d", status);
	return status;
}
