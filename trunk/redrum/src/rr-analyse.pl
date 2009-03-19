#!/usr/bin/perl

use strict;
use Getopt::Std;
use Data::Dumper;
use MIME::Base64;
use Digest::MD5 qw(md5);

require "cpu-spec.pm";


our($opt_h);
our $opt_t=4;
our $opt_o=undef;
our $opt_M=48; 
our $opt_m=3;
our $opt_d=undef;
our $opt_l=undef;
our $opt_v=undef;

my $help_text= "Usage: 

$0 [-o dir] [-t threshold] [-m min] [-M max] [-d dumpfile] [-v] [-l] binary

This script uses objdump to disassemble the given binary,
and displays some possible savings.

With '-o' some kind of assembler dumps are put in the given directories for 
all branches above a given threshold ('-t', default $opt_t).
Normally only lines with some need for a label are labelled; but sometimes 
it would help if all assembler statements get labels, and that is what '-l' 
is for.

The default maximum depth is '-M $opt_M'; only chains with at least 
$opt_m instructions are kept.

You can get a dump of the internal tree via '-d'; with '-v' you can see a 
bit of progress.
";

getopts("o:hd:t:m:M:l");
our $input=shift;

$|=1;


die $help_text if !$input || $opt_h;


############################################################



# Each level stores the number of hits, the length of the previous 
# instruction in bytes, and a hash that references the next level by 
# "opcode operand".
my %tree=();
our $max_savings=0;
our $real_savings=0;

ReadBinary(\%tree, $input);
print "max savings: $max_savings\n";



Progress("cleaning tree");
CleanTree(\%tree, 0, 1);
print "real savings approximate $real_savings bytes.\n";


Progress("Making .s files");
MakeAsm($opt_o, \%tree) if $opt_o;


if ($opt_d)
{
	my $fhdl;
	open($fhdl, ">", $opt_d) || die "Write to $fhdl: $!";
	print $fhdl "Dump of tree for $input.\n",
		"savings about $real_savings (max $max_savings).\n\n",
		Dumper(\%tree);
	close $fhdl;
}


print "finished.                         \n";
exit;


sub MakeLabel
{
	my($nr_func)=@_;
  my($label);


	$label="RR" . encode_base64(md5(time() . &$nr_func() . $$. rand()));
	$label =~ s/\W+//g;

	".globl $label\n" .
	".type $label, \@function\n" . 
	"$label:\n";
}


############################################################
# Goes recursively to the end of a branch, and writes a file.
sub MakeAsmRec
{
	my($dir, $tree, $nr_func, $len, @ops)=@_;
	my($k, $v, $nr, $label, $l, @ops2);

	while ( ($k, $v) = each %$tree)
	{
		$l=$len+$v->{"len"};
		@ops2=( (($v->{"need_label"} || $opt_l) ? ":" : ()),
			$k, @ops);

		if (%{$v->{"+"}})
		{
			MakeAsmRec($dir, $v->{"+"}, $nr_func, $l, @ops2);
		}
		else
		{
			my $fhdl;

			$nr=&$nr_func();

			open($fhdl, ">", sprintf("%s/saved-%05d.hits-%03d.%05d.s", 
					$dir, 
					$v->{"hits"} * $l,
					$v->{"hits"},
				 	$nr)) || die $!;

			print $fhdl "# Redundancy Remover generated file.\n",
			"# This code part was originally seen at 0x", $v->{"adr"}, "\n",
			"# in $input; got ", $v->{"hits"}, " hits ",
			"and was ", $l, " bytes long.\n",
			"\n";

			if ($opt_d)
			{
				print $fhdl "# $_\n" for (keys %{$v->{"funcs"}});
				print $fhdl "\n";
			}

			# The entry point should normally have the need for a label set, but 
			# make sure.
			unshift @ops2, ':' if ($ops2[0] ne ':');

			# Sadly the ++ operator doesn't work for the mixed base64 strings - 
			# they'd have to be sorted [a-z]+[0-9]+.
			for (@ops2)
			{
				print $fhdl ($_ eq ":" ? MakeLabel($nr_func) : "\t".$_."\n");
			}

#			print $fhdl "\n\n", Dumper($v);
			close $fhdl;
		}
	}
}


sub MakeAsm
{
	my($dir, $tree)=@_;
	my $counter;
	my $count_sub=sub { return $counter++; };

	mkdir($dir) || die "mkdir($dir): $!" unless -d $dir;

	print "Writing files to $dir.\n";
	MakeAsmRec($dir, $tree, $count_sub);
	print "Files written.\n";
}



# Removes all branches with hits beneath a treshold.
sub CleanTree
{
	my($tree, $accum_len, $depth)=@_;
	my($k, $v, $len);
	my @del;

	while ( ($k, $v) = each %$tree)
	{
		$len = $accum_len+$v->{"len"};

#		print Dumper($k, $v);
#		$v->{"hits"} -= 
		CleanTree( $v->{"+"}, $len, $depth+1)
			if $v->{"+"} && ($v->{"hits"} >= $opt_t);



		# If not enough hits, or it has no children and the length is too 
		# small, remove this.
		if (($v->{"hits"} < $opt_t) ||
			(!%{$v->{"+"}} && $depth<$opt_m) )
		{
			push @del, $k;

#			print "Clean at $depth: $k => ", $v->{"hits"},"\n"; #, Dumper($v);
		}
		else
		{
#			print "not Clean at $depth: $k => ", $v->{"hits"},"\n"; #, Dumper($v);
			# If this branch is kept, we'd save a few bytes.
			#
			# Take a jump at 4 byte (even on 64bit, as intra-binary jumps can be 
			# expressed rip-relative).
			$real_savings += ($v->{"hits"}-1) * ($len - 5);
		}
	}

	delete $tree->{$_} for (@del);
}



sub InsertIntoTree
{
	my($tree, $adr_used, @seq)=@_;

#	print "Inserting ", scalar(@seq),"\n";
	for my $cur (@seq)
	{
		if (! $tree->{ $cur->{"op"} }{"hits"})
		{
			$tree->{ $cur->{"op"} }=$cur;
			# Now the hash surely exists.
		}
		else
		{
			$max_savings += $cur->{"len"};
		}

		$tree->{ $cur->{"op"} }{"hits"}++;
#		$tree->{ $cur->{"op"} }{"adrs"}{ $cur->{"adr"} }=1;

		$tree->{ $cur->{"op"} }{"need_label"}=1
		if ($adr_used->{ $cur->{"adr"} });

		$tree->{ $cur->{"op"} }{"funcs"}{ $cur->{"func"} }=1;

		$tree = $tree->{ $cur->{"op"} }{"+"};
	}
}



sub ReadBinary
{
	my($tree, $file)=@_;
	my($hdl);
	my(@prev, $cur);
	my($adrs_used);
	my(@to_insert);
	my $cnt;


# With these additional parameters we get all bytes in the same line, not 
# wrapped, for long sequences.
# "-M suffix" gives the opcode suffix, like 'q' in "retq" (which is needed 
# for successfull comparision).
	open($hdl, "objdump --prefix-addresses --show-raw-insn " .
		"-d -M suffix $file |") || die $!;

	# As we want to build the tree from the terminating element on, which is 
	# the reverse direction as we're getting the disassembly, we use a queue 
	# of the last few instructions; when we hit a block marker, we insert 
	# them into the tree.
	@to_insert=();
	@prev=();
	while(<$hdl>)
	{
		my ($adr, $func_adr, $bytes, $opcode, $operands, $abs_adr, $adr_trl) = 
		(m/^
			(\w+)												# Address
			\s+
			\<([\w\@+\.\-]+)\>					# Name+-rel
			\s+
			(\w\w(?:\s\w\w)*)						# The bytes.
			\s\s+												# at least two whitespace
			(\w+)												# opcode
			(?: \s+ (\S+) )?						# ev. operands
			(?: \s+ \# 									# ev. comment with absolute address, 
				\s+ ([0-9a-f]+) )? 				# if operands include eip-relative addressing
			(?: \s+ \<(\S+)\> )?				# ev. address translation
			/x);  


		$cnt=4000,Progress("doing $adr") if $cnt-- <= 0;

# print("no match: $_"),
		next unless $opcode;

		# Some opcodes are not qualified with the length in the assembler list.
		$opcode =~ s/q$// if grep($opcode eq $_, 'retq', 'leaveq');

		# Normalize whitespace
		$operands =~ s#\s+# #g;

		# Substitute absolute addresses (%rip-relative)
		# Adresses that are "label+-something" can't be used by the assembler.
		$adr_trl = "0x" . $abs_adr
			if !$adr_trl || ($adr_trl =~ m#[+-]#);
		$operands =~ s{ \b ( 0x[0-9a-f]+ \( \%rip \) ) }{$adr_trl}xi;

		$cur = {
#			"opc" => $opcode,
#			"opr" => $operands,
			"adr" => $adr,
			"func"=> $func_adr,
#			"tr" => $adr_trl,
			"+" 	=> {},
			"len" => int( (length($bytes)+1)/3 ),
			"op"  => $opcode . " " .
			( isUncondJump($opcode) ? ($adr_trl || $abs_adr) :
				isCall($opcode) ? ($adr_trl || $operands) : $operands),
		};

#				if (isCall($opcode)) { print Dumper($_, $cur); exit; }
#		print $opcode, " ";


		$adrs_used->{$operands}++
		if (isUncondJump($opcode) || isCall($opcode));


		unshift @prev, $cur;
		pop @prev while @prev > $opt_M;

		if (isEndOfBlock($opcode))
		{
			push @to_insert, [@prev];
			@prev=();
		}
	}

	for $cur (@to_insert)
	{
		# We don't do that if it's just a few operations.
		InsertIntoTree($tree, $adrs_used, @$cur) if @$cur > $opt_m;
	}
}


sub Progress
{
	return unless -t STDERR;
	print @_,"\r";
}
