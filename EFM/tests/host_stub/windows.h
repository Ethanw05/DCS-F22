// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
// Test only: deliberately absent CockpitBase DLL. Never included in a DCS build.
using HMODULE = void*;
inline HMODULE GetModuleHandleA(const char*) { return nullptr; }
inline void* GetProcAddress(HMODULE,const char*) { return nullptr; }
