/* SPDX-License-Identifier: BlueOak-1.0.0 */
#include "libc/calls/calls.h"
#include "libc/calls/internal.h"
#include "libc/calls/syscall_support-nt.internal.h"
#include "libc/nt/createfile.h"
#include "libc/nt/enum/fileflagandattributes.h"
#include "libc/nt/enum/fileinformationclass.h"
#include "libc/nt/enum/filesharemode.h"
#include "libc/nt/files.h"
#include "libc/nt/nt/file.h"
#include "libc/nt/process.h"
#include "libc/nt/runtime.h"
#include "libc/nt/struct/fileaccessinformation.h"
#include "libc/nt/struct/filemodeinformation.h"
#include "libc/nt/struct/iostatusblock.h"
#include "libc/sysv/consts/o.h"
#include "libc/sysv/errfuns.h"

static int FileMode(int64_t handle, struct NtFileModeInformation *mode) {
  struct NtIoStatusBlock io;
  int32_t status = NtQueryInformationFile(handle, &io, mode, sizeof(*mode),
                                         kNtFileModeInformation);
  if (status < 0) {
    SetLastError(RtlNtStatusToDosError(status));
    return __winerr();
  }
  return 0;
}

textwindows int __file_sync_nt(int64_t handle) {
  struct NtFileModeInformation mode;
  if (FileMode(handle, &mode) == -1)
    return -1;
  return !!(mode.Mode & (kNtFileSynchronousIoAlert |
                         kNtFileSynchronousIoNonalert));
}

textwindows int __file_set_mode_nt(int64_t handle, unsigned clear,
                                  unsigned set) {
  struct NtFileModeInformation mode;
  if (FileMode(handle, &mode) == -1)
    return -1;
  mode.Mode &= kNtFileWriteThrough | kNtFileSequentialOnly |
               kNtFileSynchronousIoAlert | kNtFileSynchronousIoNonalert;
  mode.Mode = (mode.Mode & ~clear) | set;
  struct NtIoStatusBlock io;
  int32_t status = NtSetInformationFile(handle, &io, &mode, sizeof(mode),
                                       kNtFileModeInformation);
  if (status < 0) {
    SetLastError(RtlNtStatusToDosError(status));
    return __winerr();
  }
  return 0;
}

textwindows int64_t __file_reopen_nt(int64_t handle, unsigned attrs) {
  struct NtFileAccessInformation access;
  struct NtIoStatusBlock io;
  int32_t status = NtQueryInformationFile(handle, &io, &access, sizeof(access),
                                         kNtFileAccessInformation);
  if (status < 0) {
    SetLastError(RtlNtStatusToDosError(status));
    return __winerr();
  }
  attrs &= kNtFileFlagBackupSemantics | kNtFileFlagDeleteOnClose |
           kNtFileFlagNoBuffering | kNtFileFlagOpenNoRecall |
           kNtFileFlagOpenReparsePoint | kNtFileFlagOverlapped |
           kNtFileFlagPosixSemantics | kNtFileFlagRandomAccess |
           kNtFileFlagSequentialScan | kNtFileFlagWriteThrough;
  int64_t opened =
      ReOpenFile(handle, access.AccessFlags,
                 kNtFileShareRead | kNtFileShareWrite | kNtFileShareDelete,
                 attrs);
  return opened == -1 ? __winerr() : opened;
}

textwindows int64_t __file_positional_nt(struct Fd *f) {
  struct Cursor *cursor = f->cursor;
  if (!cursor)
    return einval();
  __cursor_lock(cursor);
  uint32_t owner = GetCurrentProcessId();
  if (cursor->positional_owner != owner) {
    cursor->positional_handle = 0;
    cursor->positional_owner = owner;
  }
  if (!cursor->positional_handle) {
    unsigned attrs;
    int64_t handle = -1;
    if (GetNtOpenFlags(f->flags & ~O_NOFOLLOW, f->mode, 0, 0, 0, &attrs) != -1)
      handle = __file_reopen_nt(f->handle, attrs | kNtFileFlagOverlapped);
    if (handle == -1) {
      __cursor_unlock(cursor);
      return -1;
    }
    cursor->positional_handle = handle;
  }
  int64_t handle = cursor->positional_handle;
  __cursor_unlock(cursor);
  return handle;
}

textwindows int64_t __file_seek_nt(int64_t handle, int64_t offset, int whence) {
  if (whence < SEEK_SET || whence > SEEK_END)
    return einval();
  int64_t position;
  if (!SetFilePointerEx(handle, offset, &position, whence))
    return __winerr();
  return position;
}
