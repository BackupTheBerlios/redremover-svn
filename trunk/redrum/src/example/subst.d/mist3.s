
.globl	IXS_b01
	.type IXS_b01, @function
IXS_b01:
	movl	g(%rip), %eax
	movl	%eax, -4(%rbp)
	jmp 	IXS_b02
IXS_b03:
	movl	-4(%rbp), %eax
	movl	-20(%rbp), %edx
	xorl	%edx, %eax
	addl	%eax, -4(%rbp)
IXS_b02:
	cmpl	$0, -20(%rbp)
	setg	%al
	subl	$1, -20(%rbp)
	testb	%al, %al
.globl	IXS_b12
	.type IXS_b12, @function
IXS_b12:
	jne 	IXS_b03
IXS_b11:
	movl	-4(%rbp), %eax
	leave
	ret

