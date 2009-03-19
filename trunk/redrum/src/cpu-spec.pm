


# X86 specific

sub isAnyJump
{
	return $_[0] =~ /^j\w+$/;
}

sub isUncondJump
{
	return $_[0] =~ /^jmpq?\b/;
}

sub makeUncondJump
{
	return "jmp";
}

sub isCall
{
	return ($_[0] =~ /^callq?\b/);
}

our $end_of_block= ["ret", "iret", "retq", makeUncondJump(), "jmpq"];
sub isEndOfBlock
{
	return scalar(grep($_[0] eq $_, @$end_of_block));
}


# Sometimes the operations can be normalized, so that substitution gets 
# visible.
# This function gets opcode and operands, and returns the normalized 
# operands.
sub NormalizeOps
{
	my($op, $operand)=@_;

	if ($op =~ /^lea/)
	{
#	lea (%rcx,%rax,1), %eax  ==> lea (%rcx,%rax), %eax
	  $operand =~ s/ \( ( \%\w+ , \%\w+ ) ,1\) /($1)/x;
	}

	if ($op =~ /^mov/)
	{
#	mov variable(%rip)... ==> mov variable...
	  $operand =~ s/ (\w+) \(\%rip\) /$1/x;
	}


# are these really identical?
	$op="sall" if ($op eq "shll");


	return ($op, $operand);
}

1;
