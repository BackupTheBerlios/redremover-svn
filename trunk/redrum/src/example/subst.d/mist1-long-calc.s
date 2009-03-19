
.globl	some_random_computation
	.type some_random_computation, @function
some_random_computation:
	movl	g(%rip), %eax
	subl	$1, %eax
	addl	-4(%rbp), %eax
	movl	%eax, %edx
	xorl	-20(%rbp), %edx
	movl	g(%rip), %eax
	leal	(%rdx,%rax), %esi
	movl	g(%rip), %eax
	notl	%eax
	movl	%eax, %edx
	addl	-4(%rbp), %edx
	movl	-4(%rbp), %ecx
	movl	$3, %eax
	sall	%cl, %eax
	xorl	-20(%rbp), %eax
	imull	%edx, %eax
	leal	(%rsi,%rax), %edx
	movl	g(%rip), %eax
	orl 	-20(%rbp), %eax
	addl	-4(%rbp), %eax
	leal	(%rdx,%rax), %ecx
	movl	g(%rip), %eax
	movl	%eax, %edx
	andl	-20(%rbp), %edx
	movl	-4(%rbp), %eax
	subl	%edx, %eax
	leal	(%rcx,%rax), %eax
.globl	some_random_computation1
	.type some_random_computation1, @function
some_random_computation1:
	leave
	ret
