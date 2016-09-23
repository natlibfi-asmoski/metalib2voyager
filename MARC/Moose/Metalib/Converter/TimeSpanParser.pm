package MARC::Moose::Metalib::Converter::TimeSpanParser;
# ABSTRACT parser for time span field 513 in Metalib export files
$MARC::Moose::Metalib::Converter::TimeSpanParser = '0.1.0';

use Moose::Role;

sub _fillyear {    return sprintf '%04u', $_[0];    }

sub TSParser {
    my $self = shift;
    my $fld = shift;
    my $s = $fld->subfield('a');
    my %res = ('start' => '', 'end' => '9999', 'startera' => 'a', 'endera' => 'a', 'err' => 0); # era: a->AD, b->BC


    if($s =~ m/^\s*depuis\s+(\d{3,4})\s*$/goi) {
	$res{'start'} = _fillyear($1);
    }
    elsif($s =~ m/^\s*(\d{3,4})\s*[-–]+\s*>?\s*(\d{3,4})?\s*(jaa)?$/go) { # "1840 ->" and friends
	$res{'start'} = _fillyear($1);
	$res{'end'} = _fillyear($2) if(defined($2));
    }
    elsif($s =~ m/^(n\.)?\s*(\d{3,4})\s*[-–]+\s*>?\s*(\d{3,4})?\s*(jaa)?$/go) { # "1840 ->" and friends, special case
	$res{'start'} = _fillyear($2);
	$res{'end'} = _fillyear($3) if(defined($3));
    }
    elsif($s =~ m/^(\d{4})\s*[-–]*\s*>?\s*(current|tämä päivä|to present day|alkaen\/current|lähtien|present)$/go) {
	$res{'start'} = $1;
    }
    elsif($s =~ m/^(\d{3,4})$/go) {
	$res{'start'} = _fillyear($1);
	$res{'end'} = '';
    }
    elsif($s =~ m/^\s*(\d{3,4})\s*[-–]+\s*(luku|talet)\s*$/go) {
	$res{'start'} = _fillyear($1);
	$res{'end'} = $res{'start'};
	substr($res{'end'}, 2, 2, '99');
    }
    elsif($s =~ m/^\s*(\d{3,4})\s*[-–]+\s*(luku|talet)\s*([-–]+)\s*$/go) {
	$res{'start'} = _fillyear($1);
    }
    elsif($s =~ m/^\s*(\d{3,4})\s*[-–]*\s*(\d{3,4})\s*[-–]*\s*(luku|luvut)\s*$/go) {
	$res{'start'} = _fillyear($1);
	$res{'end'} = _fillyear($2); substr $res{'end'}, 2, 2, '99';
    }
    elsif($s =~ m/^\s*(n\.)?\s*(\d{2,4})\s*([-–\s]*luku|[-–\s]*talet)?\s*(eKr\.?|f\.?Kr\.?)([-–\s]*)/go) {
	my @tok = ($1, $2, $3, $4, $5);
	$res{'startera'} = 'b';
	$res{'start'} = _fillyear($tok[1]);
	$res{'end'} = '' unless (defined $tok[4] && $tok[4] ne '');
	substr $res{'start'}, 2, 2, '99' if defined($tok[2]); # century, not year
	$s = $'; #'
	if($s ne '') {
	    if($s =~ m/^(\d{2,4})\s*([je]Kr\.?|f\.?Kr\.?)?\s*$/go) {
		$res{'end'} = _fillyear($1);
		if(defined($2) && $2 =~ m/[ef]/go) {
		    $res{'endera'} = 'b';
		}
	    }
	    else {
		$res{'err'} = "Could not parse time span string \"$s\" in field 513; now making it a 500 field.";
	    }
	}
    }
    else {
	$res{'err'} = "Could not parse time span string \"$s\" in field 513; now making it a 500 field.";
    }
    return \%res;
}
