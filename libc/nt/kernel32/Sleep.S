#include "libc/nt/codegen.h"
.imp	kernel32,__imp_Sleep,Sleep

	.text.windows
	.ftrace1
Sleep:
	.ftrace2
#ifdef __x86_64__
	push	%rbp
	mov	%rsp,%rbp
	mov	__imp_Sleep(%rip),%rax
	jmp	__sysv2nt
#elif defined(__aarch64__)
	ret
#endif
	.endfn	Sleep,globl
	.previous
