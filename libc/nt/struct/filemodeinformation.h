#ifndef COSMOPOLITAN_LIBC_NT_STRUCT_FILEMODEINFORMATION_H_
#define COSMOPOLITAN_LIBC_NT_STRUCT_FILEMODEINFORMATION_H_

#define kNtFileWriteThrough           0x02
#define kNtFileSequentialOnly         0x04
#define kNtFileSynchronousIoAlert     0x10
#define kNtFileSynchronousIoNonalert  0x20

struct NtFileModeInformation {
  uint32_t Mode;
};

#endif /* COSMOPOLITAN_LIBC_NT_STRUCT_FILEMODEINFORMATION_H_ */
