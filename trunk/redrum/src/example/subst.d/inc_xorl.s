.globl	Increment_xorl_something
	.type Increment_xorl_something, @function

Increment_xorl_something:
	jmp	Increment_xorl_something_L10
Increment_xorl_something_L11:
	decl	%ebx
	movl	%ebx, %eax
	xorl	%edx, %eax
	addl	%eax, %edx
Increment_xorl_something_L10:
	testl	%ebx, %ebx
	jg	Increment_xorl_something_L11
	movl	%edx, %eax
	popq	%rbx
	leave
	ret


