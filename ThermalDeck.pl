###############################################################################
#
# Thermal Expansion coefficient application script
#
# created by Jens M Hebisch
#
# Version 0.4
# V0.2 Completed RBE 2 lines up to 80 characters, to prevent problems when
# the expansion coefficient is the first entry on a new line
# V0.4 Fixed trailing space problem for RBE2
#
# This script is intended to apply thermal expansion coefficients.
# Currently the following cards are covered: MAT1, RBE2, RBE3.
# For PFAST and PBUSH the K1 stiffness is set to 100. This reduced axial
# stiffness reduces the stress induced by fasteners
#
# The script has two modes:
# Mode 1: provide one or more bdfs to operate on as in:
# perl ThermalDeck.pl ALPHA file1.bdf file2.bdf ...
# where ALPHA is the thermal expansion coefficient with up to 8 characters
# This will modify cards in the file(s) provided. Multiple files
# can be provided.
#
# Mode 2: provide the parameter find as in:
# perl ThermalDeck.pl ALPHA find
# This will modify all the bdf files in the folder. If no cards to modify are
# found in a file, the copy that is created during the modification process
# is automatically removed.
#
# output file containing modifications will start with "TH_" followed by the
# original file name.
# Existing files that match this pattern will get overwrittent without warning.
#
###############################################################################
use warnings;
use strict;

my ($alpha, @files) = @ARGV;

if($files[0] eq "find"){
	my @files = <*.bdf>;
}

sub reassembleAndPrint{
	my($fh, @fields) = @_;
	my $line;
	foreach my $field (@fields){
		$line = $line.$field.(" "x(8-length($field)));
	}
	print $fh $line."\n";
}

sub closeOutRBE{
	my($fh, $rbe) = @_;
	my @fields = unpack('(A8)*',$rbe);
	if($fields[0] eq "RBE2"){
		my $line = "";
		my $count = 0;
		my $set = 0;
		foreach my $field (@fields){
			$field =~ s/ //g;
			unless($field eq ""){
				if($field =~ m/\./){
					#replace existing thermal expansionf coefficient
					$field = $alpha;
					$set = 1;
				}
				if($count == 8){
					$line = $line.$field.(" "x8)."\n";
					unless($set){
						$line = $line.(" "x8);
					}
					$count = 1;
				}
				else{
					$line = $line.$field.(" "x(8-length($field)));
					$count++;
				}
			}
		}
		unless($set){
			$line = $line.$alpha.(" "x(8-length($alpha)));
		}
		$line = $line."\n";
		print $fh $line;
	}
	else{
		my $line;
		my $count = 0;
		my $set = 0;
		foreach my $field (@fields){
			if($field =~ m/ALPHA/){
				#replace existing thermal expansionf coefficient
				$line = $line."\n".$field.(" "x(8-length($field)));
				$set = 1;
			}
			elsif($count == 8){
				$line = $line.$field."\n";
				$line = $line.(" "x8);
				$count = 1;
			}
			else{
				$line = $line.$field.(" "x(8-length($field)));
				$count++;
			}
		}
		unless($set){
			unless($count == 1){
				$line = $line."\n".$line.(" "x8);
			}
			$line = $line."ALPHA   ".$alpha.(" "x(8-length($alpha)));
		}
		$line = $line."\n";
		print $fh $line;
	}
}

FILE: foreach my $file (@files){
	my $changes = 0;
	my $rbe = 0;
	open(IPT, "<", $file) or next FILE;
	open(my $opt, ">", "TH_".$file);
	while(<IPT>){
		my $line = $_;
		chomp($line);
		$line =~ s/\r//;
		if($line =~ m/^\S/ and $rbe){
			closeOutRBE($opt, $rbe);
			$rbe = 0;
		}
		if($line =~ m/^\s*$/){
			#blank line, don't copy
		}
		elsif($line =~ m/^MAT1/){
			my @fields = unpack('(A8)*',$line);
			$fields[6] = $alpha;
			reassembleAndPrint($opt, @fields);
			$changes = 1;
		}
		elsif($line =~ m/^PBUSH/){
			my @fields = unpack('(A8)*',$line);
			$fields[3] = "100.";
			reassembleAndPrint($opt, @fields);
			$changes = 1;
		}
		elsif($line =~ m/^PFAST/){
			my @fields = unpack('(A8)*',$line);
			$fields[5] = "100.";
			reassembleAndPrint($opt, @fields);
			$changes = 1;
		}
		elsif($line =~ m/^RBE/){
			$rbe = $line;
			$changes = 1;
		}
		elsif($rbe){
			$rbe = $rbe.$line;
		}
		else{
			print $opt $line."\n";
		}
	}
	if($rbe){
		closeOutRBE($opt, $rbe);
	}
	close($opt);
	close(IPT);
	#if file did not contain changes, remove copy
	unless($changes){
		unlink("TH_".$file);
	}
}
