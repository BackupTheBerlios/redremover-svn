#!/usr/bin/perl
# Redundancy remover translater;
# (C) by Ph. Marek 2009; released under the GPLv3.

use strict;
use Data::Dumper;
use Getopt::Std;

require "cpu-spec.pm";


$Data::Dumper::Maxdepth=4;

our($opt_s, $opt_h, $opt_D);
getopts("s:hD");
die "Usage:

$0  -s {substitution directory or file} {input.s}
" if $opt_h;

my $input=shift();
our $original=new AsmFile($input, sub { print IN $_; } );


our $translate=[];
for (-d $opt_s ? <$opt_s/*.s> : $opt_s)
{
	D("loading translation $_");
	push @$translate, new AsmFile($_);
}


# The format is
#   opcode => { 
#   	operand => [ 
#   		[ [ this line in translate file, last line of block], ... ], 
#   		{ opcode =>
our %translate_tree=();
MakeTranslateTree( \%translate_tree, @$translate);


my @to_change;
for my $end_of_block ($original->marks)
{
	FindSubstitution($end_of_block, \%translate_tree, \@to_change);
}

ChangeText(@to_change);


$original->print();
close(STDOUT);

exit;


sub ChangeText
{
	my $chg;

	for $chg (@_)
	{
		my($ori_first, $ori_last, $tr_first, $tr_last)=@$chg;
		my($tr_next, $line);

		D("change:",
		 " ori [", $ori_first->nr, ":", $ori_last->nr, "] to",
		 " tr [", $tr_first->nr, ":", $tr_last->nr, "]");

		$tr_next=0;
		D("ori=", $ori_last->op, " tr=", $tr_last->op);

		# We go from back to front, so that the opcodes could be done in sync.
		for($line=$ori_last; $line->nr>$ori_first->nr; $line=$line->prevOp)
		{
			# If the original had an opcode here, we have to jump to the next 
			# opcode line in the translation, too.
			$tr_next=$tr_last->prevOp if $line->opcode;

			# Set comment
			$line->comment( $line->op );

			# Opcode and operands get deleted
			$line->opcode("");
			$line->operands("");

			# A label gets changed to a definition line
			if ($line->label)
			{
				$line->opcode( $line->label . "=" . $tr_last->label );
				$line->label("");
			}

			$tr_last=$tr_next if $tr_next;
			$tr_next=undef;
		}

		while (!$tr_last->labels)
		{
			warn("Would have translated, but no label ",
				"for \"", $tr_last->op, "\" in\n",
				"  ", $tr_last->file->filename, ":", $tr_last->nr, "\n");

			$tr_last=$tr_last->nextOp;
			$line=$line->nextOp;
		}

		D("labels:", join("; ", $tr_last->labels));
		# The start of the changed block gets translated to a jump.
		$line->opcode( makeUncondJump() );
		$line->operands( ($tr_last->labels)[0] );
	}
}


sub FindSubstitution
{
	my($ori_marked_line, $tree, $to_change)=@_;

	my $best_match;
	my($ori_line, $ori_last, $opc_count);

#	# We need a copy.
#	my(@possible); #map { $_->marks; } @$translate_files;
#	my($ori_cur, $tr_cur);
#	my $start_of_current_tr_block=0;
#	# Stores that simplifying to line x ain't allowed, but that line y is 
#	# possible. See "Jump Comparision" in the POD.
#	my %rollback;
#	my($ori_last, $tr_last);
#	return;

	$ori_line=$ori_marked_line;
	$opc_count=0;
	while ($ori_line && !isStop($ori_line->op))
	{
		D($ori_line->nr, ": ", $ori_line->op);
		D("!opcode: ",join(",", keys %$tree)),
		last if !exists($tree->{ $ori_line->opcode });

		# Matches, one further
		$tree=$tree->{ $ori_line->opcode };

		# Jumps may have different operands, if the jumps result in a 
		# comparable destination.
		if (isAnyJump($ori_line->opcode))
		{
			# TODO
			D("jump!"),last;

			# If the ops don't match, there's a single chance to continue:
			# They're jumps to the same relative positions.
#			last unless JumpsToTheSameRelativePosition($tr_cur, $ori_line);

#			$tree=$tree->{ $ori_line->operands };
		}
		else
		{
			# Non-jump opcodes must have identical operands.
			# TODO: small differences allowed, by a subroutine definition with 
			# params?
			D("!= operand"),last if !exists($tree->{ $ori_line->operands });

			$tree=$tree->{ $ori_line->operands };
		}

		# Now we're at the list of lines, and the next tree.
		$best_match = $tree->[0][0];
		$tree = $tree->[1];

		$ori_last = $ori_line;
		$ori_line = $ori_line->prevOp;
		$opc_count++;
	}

	if ($ori_last && $opc_count>2)
	{
		# mark text to be changed
		push @$to_change, [ $ori_last, $ori_marked_line, @$best_match];
#			D("changing ", join(", ", @{$to_change[-1]}), "\n");
	}
}


sub JumpsToTheSameRelativePosition
{
	my($tr_cur, $ori_cur)=@_;
	my($tr_opc, $tr_opr, $tr_cur_lin,
		$ori_opc, $ori_opr, $ori_cur);
	my($tr_dest, $ori_dest);
	my $case;

	D("jump");

	return 0 unless $tr_cur->opcode eq $ori_cur->opcode;

	# If it's a unconditional jump, it can only be replaced if the 
	# destinations are the same - and that means a global symbol, not a local. 
	if (isUncondJump($tr_cur->opcode))
	{
		return 0 if $tr_cur->operands =~ /^\./;
		return 0 if $tr_cur->operands ne $ori_cur->operands;
		return 1;
	}

	return 0 unless isAnyJump($tr_cur->opcode);

	# Now compare the number of instructions that are skipped, to see whether 
	# they could match, and to populate the rollback array.
	$tr_dest=$tr_cur->file->lookup( $tr_cur->{$tr_cur->operands} ) || die;
	$ori_dest=$original->lookup( $ori_cur->{$ori_cur->operands} ) || die;

	# TODO Forward jumps are not substituted currently.
	# They could be done if they are fully within the current substitution 
	# block.
	return 0 if $tr_dest->nr > $tr_cur->nr;
	return 0 if $ori_dest->nr > $ori_cur->nr;

	# Now do the steps.
	while (1)
	{
		$case=
		(($tr_cur->nr == $tr_dest->nr) ? 1 : 0) |
		(($ori_cur->nr == $ori_dest->nr) ? 2 : 0);
		last if $case;

		$tr_cur = $tr_cur->next_op;
		$ori_cur = $ori_cur->next_op;
	}

	D("Compare jumps: $case");

	return $case == 3;
}


sub MakeTranslateTree
{
	my($tree, @files)=@_;

  for my $file (@files)
	{
#	D("making tree for ", $file->filename);
		for my $curlin ($file->marks)
		{
#			D("  translating from ", $file->filename, " ", $curlin->op);
			MakeTranslateTree2($tree, $curlin);
		}
	}
}

sub MakeTranslateTree2
{
	my($tree, $marked_line)=@_;
	my $line=$marked_line;

	while ($line && !isStop($line->opcode))
	{
#		D("    tree ", $line->op, " at #", $line->nr);
		my $n = ($tree->{$line->opcode}{$line->operands} ||= [[],{}] );

		push @{$n->[0]}, [ $line, $marked_line ];

		$tree = $n->[1];
		$line = $line->prevOp;
	}
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


# All non-opcodes (directives for the assembler) stop the translation.
sub isStop
{
	return $_[0] =~ /^\./;
}

sub isOpcode
{
	return $_[0] =~ /^[a-z]/i;
}


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 


sub D { print STDERR @_,"\n" if $opt_D; }
sub Df { if ($opt_D) { printf STDERR @_; print STDERR "\n"; } }



############################################################

package AsmFile;


sub new
{
	my $class=shift();
	my($fn, $callback)=@_;
	my($fhdl, $self);
	my($label, $prev_opcodeline);
	my(@labels);
	my($is_gas_listing, $macro_level);


	$self=bless( {
			"lines" => [],
			"fn" => $fn,
			"syms" => {}, 
			"marks" => [], 
		}, $class);

	open($fhdl, ( ($fn eq "-") ? "<& STDIN" : ("<", $fn) )
	) || die "open $fn: $!";


	$is_gas_listing=0;
	while (<$fhdl>)
	{
		if (/^\f? GAS \s LISTING \s .* \s page \s \d+/x)
		{
			# Remember that it's a listing file
			$is_gas_listing=1;
			# Ignore up to two empty lines; if one is not empty, process it.
			( ($_=<$fhdl>) =~ /^\s*$/) &&
			( ($_=<$fhdl>) =~ /^\s*$/) && ($_=<$fhdl>);
		}

		if ($is_gas_listing)
		{
			# Get the assembler listing
			(undef, $_)=split(/\t/, $_, 2);

			# Ignore rest of macro definition lines
			next if /^\s*\.macro\s/;

			my $ml;
			# Remove the macro expansion signs, and the macro name line 
			# that's given *before* the macro lines (on each level!)
			if (s/^(\>+)//)
			{
				$ml=length($1);

				if ($ml>$macro_level)
				{
					my $l=splice(@{$self->line}, -1, 1);
#					main::D("Removing line ", $l->opcode);
				}
			}

			$macro_level=$ml;
		}

		&$callback($_) if $callback;

		# Get a label.
		$label=s/^\s*([.\w]+):// ? $1 : undef;
		push @labels, $label if $label;

		# Normalize whitespace.
		s/^\s+//;
		s/\s+$//;

		# Even tabs get changed.
		s/\s+/ /g;

		# Save remaining opcode and operands.
		my ($opcode, $operands)=split(/ /, $_, 2);

		if (main::isOpcode($opcode))
		{
			# Change all operands to decimal.
			# Must be a word boundary, else "r10d" would get translated, too.
			$operands =~ s/\b(0x?[a-f0-9]+)/oct($1)/ie;

			$operands = main::NormalizeOps($opcode, $operands);
		}


		my $line=new AsmLine(
			"opc" => $opcode,
			"opr" => $operands,
			"file" => $self,
			"label" => $label,
			"#" => $#{$self->line},
			"labels" => [@labels],
		);

		$self->lookup($label, $line) if $label;

		# Is this an "interesting" line?
		push @{$self->{"marks"}}, $line if main::isEndOfBlock($line->opcode);

		push @{$self->line}, $line;

		# Remember the line number, if it has an opcode in it,
		# ie. doesn't start with a ".".
		if (main::isOpcode($_))
		{
			$line->{"prev_op"} = $prev_opcodeline;
			$prev_opcodeline->{"next_op"}=$line if $prev_opcodeline;
			@labels=();
			$prev_opcodeline=$line;
		}
	}
	close $fhdl;

	return $self;
}


sub marks
{
	my($self)=@_;
	return @{$self->{"marks"}};
}

# Returns the line number of a label, or a reference to the labels hash.
sub lookup
{
	my($self, $name, $line)=@_;
	if ($name)
	{
		$self->{"syms"}{$name}=$line if defined($line);
		return $self->{"syms"}{$name};
	}

	return $self->{"syms"};
}

# Returns an AsmLine
sub line
{
	my($self, $l_nr)=@_;
	return defined($l_nr) ? $self->{"lines"}[$l_nr] : $self->{"lines"};
}

sub print
{
	my($self)=@_;

	for (@{$self->line()})
	{
		print "# ",$_->comment,"\n" if $_->comment;
		print $_->label,":" if length($_->label);
		print 
		+($_->opcode eq '.globl' ? "" : "\t"),
		$_->opcode, " ", $_->operands if $_->opcode;
		print "\n";
	}
}

sub filename
{ my($self)=@_; return $self->{"fn"}; }



############################################################

package AsmLine;


sub new {
	my $class=shift();
	my (%data)=@_;

	return bless(\%data, $class);
}

sub comment
{ 
	my($self, $text)=@_; 
	$self->{"cmt"}=$text if defined($text);
	return $self->{"cmt"};
}

sub nr 
{ my($self)=@_; return $self->{"#"}; }

sub operands 
{
 	my($self, $t)=@_;
 	$self->{"opr"}=$t if defined($t);
 	return $self->{"opr"}; 
}

sub opcode 
{
 	my($self, $t)=@_;
 	$self->{"opc"}=$t if defined($t);
 	return $self->{"opc"}; 
}

sub label
{
 	my($self, $t)=@_;
 	$self->{"label"}=$t if defined($t);
 	return $self->{"label"}; 
}

sub labels
{ my($self)=@_; return @{$self->{"labels"}}; }

sub prevOp
{ my($self)=@_; return $self->{"prev_op"}; }

sub nextOp
{ my($self)=@_; return $self->{"next_op"}; }

sub file
{ my($self)=@_; return $self->{"file"}; }

sub op {
	my($self)=@_;
	return $self->opcode . " " . $self->operands;
}

sub next 
{ 
	my($self)=@_;
	return $self->{"file"}->lines( $self->{"#"}+1 );
}

sub prev
{
	my($self)=@_;
	return $self->{"file"}->lines( $self->{"#"}-1 );
}


__END__


=pod

=head1 Assembler translator


=head2 Purpose

This script parses a reference assembler file, and replaces occurences of 
such given blocks in the input file by one or more jumps to the labels from 
the reference file.

This can be used to B<translate> I<redundant> assembler code to a jump 
instruction, and thereby make the binary (and its footprint in the 
instruction cache) a bit smaller.


=head2 Implementation


=head3 The reference code

The reference code is just normal assembler code; labels B<must> have 
unique names, as these labels will be used in the substituted jump 
instructions.

In case that some other code jumps right in the middle of some reference 
block there has to be a label defined, so that the label in the original 
block can be redefined. See below.


=head3 Jump Comparision

If the assembler statements include conditional jumps, it might be 
necessary to cut the substitution there, because the code blocks that are 
jumped to are different.

An example:

		je .L8
	.L4:
		addl %eax,%ecx
		ret

	.L8:
		...

If there's a similar sequence with a different opcode at C<.L8> (or later), 
only the sequence from C<.L4> can be substituted with a jump (at least 
currently).

So currently forward jumps mark an end to the comparision, and backward 
jumps mark the range in a rollback array - if substitution isn't possible 
all the way back to the jump destination, the jump is kept.


=head3 Substitution

=over

=item Labels

Labels are changed to lines with assignments, relative to the start of the 
section.

=back

=head3 Example

Reference block:

	Label1:
		xorl %edx,%eax
		addl %ecx,%eax
	Label1b:
		xorl %ecx,global_var(%rip)
		addl %eax,%ecx
		ret

Input code:

	.L1:
		cmpl %eax,%ebx
		je .L4
	.L3:
		xorl %edx,%eax
		addl %ecx,%eax
	.L4:
		xorl %ecx,global_var(%rip)
		addl %eax,%ecx
		ret

In this example the code from C<.L3> on could get replaced by this:

	.L1:
		cmpl %eax,%ebx
		je .L4
	.L3:
		jmp Label1
	.L4=Label1b

and a few bytes could be saved.

But if the input looks like this:

	.L1:
		cmpl %eax,%ebx
		je .L4
		jg .L5
	.L3:
		xorl %edx,%eax
	.L5:
		addl %ecx,%eax
	.L4:
		xorl %ecx,global_var(%rip)
		addl %eax,%ecx
		ret

the translation will fail, as the needed label C<.L5> isn't available in 
the reference block.

=cut
