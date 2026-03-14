// Request high-performance GPU on systems with multiple GPUs (NVIDIA/AMD discrete GPUs).
// These exported variables are recognized by drivers to prefer the high-performance GPU.

#include <windows.h>

extern "C" {
// NVIDIA Optimus
__declspec(dllexport) unsigned long NvOptimusEnablement = 0x00000001;
// AMD PowerXpress
__declspec(dllexport) unsigned long AmdPowerXpressRequestHighPerformance = 0x00000001;
}
