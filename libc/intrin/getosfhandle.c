/* SPDX-License-Identifier: BlueOak-1.0.0 */
#include "libc/calls/internal.h"
#include "libc/calls/io.h"
#include "libc/calls/state.internal.h"
#include "libc/calls/struct/sigset.internal.h"
#include "libc/sysv/errfuns.h"
#include "libc/sysv/pib.h"

/**
 * Returns the borrowed Windows handle owned by a file descriptor.
 *
 * Close the descriptor, not this handle. Unassociated standard streams return
 * -2 without changing errno. Other invalid descriptors fail with EBADF;
 * synthetic descriptors fail with ENOTSUP, and non-Windows calls with ENOSYS.
 */
intptr_t _get_osfhandle(int fd) {
  intptr_t result;
  if (!IsWindows())
    return enosys();
  BLOCK_SIGNALS;
  __fds_lock();
  if (!__isfdopen(fd)) {
    result = 0 <= fd && fd <= 2 ? -2 : ebadf();
  } else {
    const struct Fd *f = &__get_pib()->fds.p[fd];
    switch (f->kind) {
      case kFdFile:
      case kFdSocket:
      case kFdConsole:
      case kFdSerial:
      case kFdDevNull:
        result = f->handle;
        break;
      default:
        result = enotsup();
        break;
    }
  }
  __fds_unlock();
  ALLOW_SIGNALS;
  return result;
}
