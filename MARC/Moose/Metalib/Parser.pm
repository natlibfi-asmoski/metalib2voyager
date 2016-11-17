package MARC::Moose::Metalib::Parser;
# ABSTRACT: Parser for knowledge_units in Metalib export files (XMLMARC format)
$MARC::Moose::Metalib::Parser::VERSION = '0.1.0';

use Moose;
use MARC::Moose::Field::Control;
use MARC::Moose::Field::Std;
use Readonly;

Readonly my $DEFAULTLEADER => 'xxxxxxxx'; 	# dummy for the moment

Readonly my $CATTAG      => '976';		# store categories in this field
Readonly my $MAINCATSUB  => 'a';		# subfield for main category
Readonly my $SUBCATSUB   => 'b';		# subfield for subcategory
Readonly my $CATIND1     => " ";
Readonly my $CATIND2     => " ";

Readonly my $CATNAME     => "category";
Readonly my $MAINCATNAME => "main";
Readonly my $SUBCATNAME  => "sub";

Readonly my $RECNAME     => "record";
Readonly my $CTRLNAME    => "controlfield";
Readonly my $DATANAME    => "datafield";
Readonly my $TAGNAME     => "tag";
Readonly my $CONTNAME    => "content";
Readonly my $IND1NAME    => "ind1";
Readonly my $IND2NAME    => "ind2";
Readonly my $SUBFNAME    => "subfield";
Readonly my $CODENAME    => "code";


extends 'MARC::Moose::Parser';

has 'leadervalue' => ( is => 'rw', 'isa' => 'Str',      default => $DEFAULTLEADER );
has 'cattag' =>      ( is => 'rw', 'isa' => 'Str',      default => $CATTAG );
has 'maincatcode' => ( is => 'rw', 'isa' => 'Str',      default => $MAINCATSUB );
has 'subcatcode' =>  ( is => 'rw', 'isa' => 'Str',      default => $SUBCATSUB );
has 'catind1' =>     ( is => 'rw', 'isa' => 'Str',      default => $CATIND1 );
has 'catind2' =>     ( is => 'rw', 'isa' => 'Str',      default => $CATIND2 );
has 'dropfields' =>  ( is => 'rw', 'isa' => 'Str',      default => '');
has 'only001' =>     ( is => 'rw', 'isa' => 'Bool',     default => '');
has 'hash2lf' =>     ( is => 'rw', 'isa' => 'Str',      default => '');
has 'status' =>      ( is => 'rw', 'isa' => 'Int',      default => 0);

# Metalib-export-tiedoston  rakenne XML::Hash::XS:n tarjoamana on tämä:
#
# { 'whatever...' => ...,
# 'knowledge_unit' => [                 # näitä voi olla useita yhdessä tiedostossa
#     { 'z58' => ...,                   # ja näitä voi olla useita yhdessä knowledge_unitissa
#       'find_module' => ...,           # HUOM! Export-tiedostoissa voi esiintyä tyhjiä <knowledge_unit>-
#       'program_name' => ...,          # rakenteita, jotka näkyvät tälle tyhjänä stringinä hashin sijasta
#       'present_module' => ...,
#       'present_single' => ...,
#       'record' => {                   
#            'datafield' => [
#                {
#                    'tag' => '210',
#                    'ind1' => '',
#                    'ind2' => '',
#                    'subfield' => {
#                         'code' => 'a',
#                         'content' => 'Suojelupoliisin käsikirjasto'
#                    }
#              tai
#                     'subfield' => [
#                         {'code' => 'u', 'content' => 'http://foo.bar/'},
#                         {'code' => 'y', 'content' => 'infamous interface'}
#                     ]
#                 },
#                 { 'tag' => 'xxx', 'ind1' => '1', ....},
#                 ...
#             ],
#            'controlfield' => [
#                                { 'content' => 'foo', 'tag' => 'bar' },
#                                ...,
#                              ],
#       },
#       'z39' => ...,
#       'category' => {
#                 'main' => [ main1, main2, main3 ],
#                               ^      ^      ^
#                               |      |      |
#                               v      v      v
#                 'sub'  => [ sub1,  sub2,  sub3  ]
#       }
#       tai
#       'category' => { 'main' =>  cat, 'sub' => subcat }
#    },
#    {...},
#     ...
#  ],
#  ...
# }

override 'parse' => sub {
    my ($self, $ku) = @_;
    my ($tag, $code, $ind1, $ind2, $value, $d, $sp, $i, $s);
    my $record = MARC::Moose::Record->new();
    my $droppers = $self->dropfields();
    my $lffields = $self->hash2lf(); 
    my @fields;

    if(exists $ku->{$RECNAME}) {
	if(ref($ku->{$RECNAME}{$CTRLNAME}) eq 'HASH') {  # one single controlfield
            push @fields, MARC::Moose::Field::Control->new( tag => $ku->{$RECNAME}{$CTRLNAME}{$TAGNAME},
							    value => $ku->{$RECNAME}{$CTRLNAME}{$CONTNAME} )
		if((!$self->only001) || ($ku->{$RECNAME}{$CTRLNAME}{$TAGNAME} =~ m/001|CKB/go)); 
	}
	else {
	    foreach $d (@{$ku->{$RECNAME}{$CTRLNAME}}) {
		push @fields, MARC::Moose::Field::Control->new( tag => $d->{$TAGNAME}, value => $d->{$CONTNAME} )
		    if((!$self->only001) || ($d->{$TAGNAME} =~ m/001|CKB/go)); 

	    }
	}
	foreach $d (@{$ku->{$RECNAME}{$DATANAME}}) {
	    next if(($droppers eq '') || ($d->{$TAGNAME} =~ m/$droppers/g)); 
	    $tag = $d->{$TAGNAME};	
	    $ind1 = $d->{$IND1NAME};
	    $ind2 = $d->{$IND2NAME};
	    my @subf = ();

	    if(ref($d->{$SUBFNAME}) eq 'ARRAY') {
		foreach $sp (@{$d->{$SUBFNAME}}) {
		    $s = $sp->{$CONTNAME};
		    if(($lffields ne '') && ($tag =~ m/$lffields/g)) {
			$s =~ s/\s*##\s*/\n/g;
		    }
                    push @subf, [$sp->{$CODENAME},  $s];
                }
            }
            else {
		$s = $d->{$SUBFNAME}{$CONTNAME};
		if(($lffields ne '') && ($tag =~ m/$lffields/g)) {
		    $s =~ s/\s*##\s*/\n/g;
		}
		push @subf, [$d->{$SUBFNAME}{$CODENAME}, $s];
            }
            push @fields, MARC::Moose::Field::Std->new(
                tag => $tag,
                ind1 => $ind1,
                ind2 => $ind2,
                subf => \@subf );

	}
	if(exists $ku->{$CATNAME} && $ku->{$CATNAME} ne '') { 
	    # Some category blocks in the input may be empty
	    #
	    # We move category data into 976 fields: main category to subfield a, subcategory to b.
	    # The data always has full category/subcategory pairs, so we can rely on the order of
	    # the items.
	    my($mc, $sc);

	    if(ref($ku->{$CATNAME}{$MAINCATNAME}) eq 'ARRAY') {
		my $m = $ku->{$CATNAME}{$MAINCATNAME};
		my $s = $ku->{$CATNAME}{$SUBCATNAME};
		$i = 0;
		while(defined($m->[$i])) {
		    $mc = $m->[$i]; $mc =~ s!^//|\\\\$!!go,
		    $sc = $s->[$i]; $sc =~ s!^//|\\\\$!!go,
		    push @fields, MARC::Moose::Field::Std->new(
			tag => $self->cattag,
			ind1 => $self->catind1,
			ind2 => $self->catind2,
			subf => [ [$self->maincatcode, $mc], [$self->subcatcode, $sc] ] 
			);
		    $i++;
		}
	    }
	    else { # suppose it's a single value
		$mc = $ku->{$CATNAME}{$MAINCATNAME}; $mc =~ s!^//|\\\\$!!go,
		$sc = $ku->{$CATNAME}{$SUBCATNAME};  $sc =~ s!^//|\\\\$!!go,
		push @fields, MARC::Moose::Field::Std->new(
		    tag => $self->cattag,
		    ind1 => $self->catind1,
		    ind2 => $self->catind2,
		    subf => [ [$self->maincatcode, $mc], [$self->subcatcode, $sc] ]
		    );
	    }
	}
	$record->_leader($self->leadervalue);
	$record->fields( \@fields );
    }
    else {  # no <record> in knowledge_unit in the input file
	$self->status(2);
    }
    $self->status(0);
    return $record;
};

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MARC::Moose::Metalib::Parser - Parser for Metalib export files (pseudo-xmlmarc)

=head1 VERSION

version 0.1.0

=head1 AUTHOR



=head1 COPYRIGHT AND LICENSE


=cut
