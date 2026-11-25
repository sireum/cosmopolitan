/* SPDX-License-Identifier: BlueOak-1.0.0 */
#include "libc/intrin/atomic.h"
#include "libc/nt/process.h"
#include "libc/nt/runtime.h"
#include "libc/nt/synchronization.h"
#include "libc/nt/thread.h"
#include "libc/thread/posixthread.internal.h"
#ifdef __x86_64__

static void LockIoWake(struct PosixThread *pt) {
  while (atomic_exchange_explicit(&pt->pt_io_wake_lock, 1,
                                   memory_order_acquire))
    asm("pause");
}

static void UnlockIoWake(struct PosixThread *pt) {
  atomic_store_explicit(&pt->pt_io_wake_lock, 0, memory_order_release);
}

static void __msabi WakeIo(uintptr_t argument) {
  struct PosixThread *pt = (struct PosixThread *)argument;
  LockIoWake(pt);
  pt->pt_io_wake_pending = false;
  UnlockIoWake(pt);
}

textwindows void __sig_io_begin(struct PosixThread *pt, uint64_t mask) {
  LockIoWake(pt);
  pt->pt_blkmask = mask;
  atomic_store_explicit(&pt->pt_blocker, PT_BLOCKER_NT_IO,
                         memory_order_release);
  UnlockIoWake(pt);
}

textwindows void __sig_io_wake(struct PosixThread *pt) {
  LockIoWake(pt);
  if (atomic_load_explicit(&pt->pt_blocker, memory_order_acquire) ==
          PT_BLOCKER_NT_IO &&
      (atomic_load(&pt->tib->tib_sigpending) & ~pt->pt_blkmask) &&
      !pt->pt_io_wake_pending) {
    intptr_t thread = atomic_load(&pt->tib->tib_syshand);
    pt->pt_io_wake_pending = QueueUserAPC(WakeIo, thread, (uintptr_t)pt);
  }
  UnlockIoWake(pt);
}

textwindows void __sig_io_end(struct PosixThread *pt) {
  uint32_t error = GetLastError();
  LockIoWake(pt);
  atomic_store_explicit(&pt->pt_blocker, 0, memory_order_release);
  bool pending = pt->pt_io_wake_pending;
  UnlockIoWake(pt);
  while (pending) {
    SleepEx(0, true);
    LockIoWake(pt);
    pending = pt->pt_io_wake_pending;
    UnlockIoWake(pt);
  }
  SetLastError(error);
}
#endif
