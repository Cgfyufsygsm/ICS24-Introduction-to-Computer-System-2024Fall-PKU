	.file	"a.c"
	.text
	.section .rdata,"dr"
LC0:
	.ascii "Target function called!\0"
	.text
	.globl	_target_function
	.def	_target_function;	.scl	2;	.type	32;	.endef
_target_function:
LFB119:
	.cfi_startproc
	subl	$28, %esp
	.cfi_def_cfa_offset 32
	movl	$LC0, (%esp)
	call	_puts
	addl	$28, %esp
	.cfi_def_cfa_offset 4
	ret
	.cfi_endproc
LFE119:
	.def	___main;	.scl	2;	.type	32;	.endef
	.globl	_main
	.def	_main;	.scl	2;	.type	32;	.endef
_main:
LFB120:
	.cfi_startproc
	pushl	%ebp
	.cfi_def_cfa_offset 8
	.cfi_offset 5, -8
	movl	%esp, %ebp
	.cfi_def_cfa_register 5
	andl	$-16, %esp
	call	___main
	call	_target_function
	movl	$0, %eax
	leave
	.cfi_restore 5
	.cfi_def_cfa 4, 4
	ret
	.cfi_endproc
LFE120:
	.ident	"GCC: (MinGW-W64 i686-ucrt-mcf-dwarf, built by Brecht Sanders) 13.2.0"
	.def	_puts;	.scl	2;	.type	32;	.endef
