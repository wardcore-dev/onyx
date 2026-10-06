// Windows-only safety net for the bundled tor.exe subprocess (see
// tor_bootstrap.dart). App-level shutdown code (main.dart's onBeforeClose)
// stops tor gracefully over the control port on a normal app exit, but that
// code never runs if ONYX.exe is killed abruptly -- Task Manager "End task",
// `taskkill`, a crash, or a logoff/shutdown that doesn't wait for us. In any
// of those cases tor.exe would otherwise keep running as an orphaned
// process. A Windows "job object" with JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
// fixes this at the OS level: once tor.exe is assigned to the job, Windows
// itself guarantees it dies the moment our own process handle table is torn
// down (which happens for *any* reason our process exits), with no
// cooperation required from our own (possibly already-dead) code.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Not exposed by package:win32 -- stable, documented values from the
// Windows SDK's winnt.h / processthreadsapi.h.
const int _jobObjectExtendedLimitInformation = 9;
const int _jobObjectLimitKillOnJobClose = 0x00002000;
const int _processTerminate = 0x0001;
const int _processSetQuota = 0x0100;

final class _JobObjectBasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;
  @Int64()
  external int perJobUserTimeLimit;
  @Uint32()
  external int limitFlags;
  @IntPtr()
  external int minimumWorkingSetSize;
  @IntPtr()
  external int maximumWorkingSetSize;
  @Uint32()
  external int activeProcessLimit;
  @IntPtr()
  external int affinity;
  @Uint32()
  external int priorityClass;
  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;
  @Uint64()
  external int writeOperationCount;
  @Uint64()
  external int otherOperationCount;
  @Uint64()
  external int readTransferCount;
  @Uint64()
  external int writeTransferCount;
  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;
  @IntPtr()
  external int processMemoryLimit;
  @IntPtr()
  external int jobMemoryLimit;
  @IntPtr()
  external int peakProcessMemoryUsed;
  @IntPtr()
  external int peakJobMemoryUsed;
}

/// Assigns the process identified by [pid] to a fresh Windows job object
/// configured to kill every process in it as soon as the job handle closes
/// -- which Windows does automatically when *this* process exits, by any
/// means. Returns true if the guarantee was installed successfully.
///
/// Deliberately leaks the job handle: it must outlive this function call
/// (for the rest of the app's process lifetime) for the kill-on-close
/// guarantee to mean anything, and Windows reclaims it for us on exit.
bool killChildOnParentExit(int pid) {
  final hJob = CreateJobObject(nullptr, nullptr);
  if (hJob == 0) return false;

  final info = calloc<_JobObjectExtendedLimitInformation>();
  try {
    info.ref.basicLimitInformation.limitFlags =
        _jobObjectLimitKillOnJobClose;
    final configured = SetInformationJobObject(
      hJob,
      _jobObjectExtendedLimitInformation,
      info.cast(),
      sizeOf<_JobObjectExtendedLimitInformation>(),
    );
    if (configured == 0) {
      CloseHandle(hJob);
      return false;
    }
  } finally {
    calloc.free(info);
  }

  final hProcess = OpenProcess(_processTerminate | _processSetQuota, 0, pid);
  if (hProcess == 0) {
    CloseHandle(hJob);
    return false;
  }

  final assigned = AssignProcessToJobObject(hJob, hProcess);
  CloseHandle(hProcess);
  if (assigned == 0) {
    CloseHandle(hJob);
    return false;
  }

  return true;
}
