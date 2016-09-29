package MARC::Moose::Metalib::Reader;
# ABSTRACT: File reader for Metalib pseudo-xmlmarc export files
$MARC::Moose::Metalib::Reader::VERSION = '0.1.0';
use Moose;

use Carp;
use MARC::Moose::Record;
use MARC::Moose::Metalib::Parser;
use XML::Hash::XS;

with 'MARC::Moose::Reader::File';

has '+parser' => ( 
    default => sub { MARC::Moose::Metalib::Parser->new() },
    handles => [ qw( dropfields only001 hash2lf ) ]
);
has 'units' =>   ( is => 'rw', isa => 'ArrayRef' );
has 'next_u' =>  ( is => 'rw', isa => 'Int', default => 0 ); 


sub BUILD {
    my $self = shift;
    my $fh = $self->{fh};

    my $hsh = xml2hash($fh);  			  # Error handling?  Yes, we have no bananas!
    if(ref($hsh->{'knowledge_unit'}) ne 'ARRAY') {
	$self->units([$hsh->{'knowledge_unit'}]); # in case there's only one knowledge_unit in the file
    }
    else {
	$self->units($hsh->{'knowledge_unit'});	  
    }
}

sub read {
    my $self = shift;
    my $ku;
    my $u = $self->units();

    do {                                          # empty knowledge_units show as empty strings in the hash
	return unless defined($ku = $u->[$self->next_u()]);
	$self->next_u($self->next_u + 1);
    }
    while(($ku eq '') || !defined($ku->{'record'}) || $ku->{'record'} eq '');   # and records may be empty too

    $self->parser->parse( $ku );  		  # this is a ref instead of raw text as in the other parsers
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MARC::Moose::Metalib::Reader - File reader for Metalib export file (pseudo-MARCXML)

=head1 VERSION

version 0.1.0

=head1 DESCRIPTION

Override L<MARC::Moose::Metalib::Reader::File>, and read records from a Metalib export file.

=head1 ATTRIBUTES

=head2 parser



=head1 AUTHOR


=head1 COPYRIGHT AND LICENSE


=cut
