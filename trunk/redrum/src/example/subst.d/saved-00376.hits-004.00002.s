# Redundancy Remover generated file.
# This code part was originally seen at 0x00000000004004be
# in example//test-prog; got 4 hits and was 94 bytes long.

.globl RRfF98nB2hyOf7oVjMCVaOnQ
.type RRfF98nB2hyOf7oVjMCVaOnQ, @function
RRfF98nB2hyOf7oVjMCVaOnQ:
	movl g,%eax
	subl $0x1,%eax
	addl -0x4(%rbp),%eax
	movl %eax,%edx
	xorl -0x14(%rbp),%edx
	movl g,%eax
	leal (%rdx,%rax,1),%esi
	movl g,%eax
	notl %eax
	movl %eax,%edx
	addl -0x4(%rbp),%edx
	movl -0x4(%rbp),%ecx
	movl $0x3,%eax
	sall %cl,%eax
	xorl -0x14(%rbp),%eax
	imull %edx,%eax
	leal (%rsi,%rax,1),%edx
	movl g,%eax
	orl -0x14(%rbp),%eax
	addl -0x4(%rbp),%eax
	leal (%rdx,%rax,1),%ecx
	movl g,%eax
	movl %eax,%edx
	andl -0x14(%rbp),%edx
	movl -0x4(%rbp),%eax
	subl %edx,%eax
	leal (%rcx,%rax,1),%eax
	leave 
	ret 
