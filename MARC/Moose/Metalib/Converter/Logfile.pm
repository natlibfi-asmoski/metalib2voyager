package MARC::Moose::Metalib::Converter::Logfile;
# ABSTRACT: A log file class for the generic MARC record converter 
$MARC::Moose::Metalib::Converter::Logfile::VERSION = '0.1.0';

use Moose;
with 'MooseX::RW::Writer::File';

sub write {
    my ($self, $msg) = @_;
    my $fh = $self->fh;
    print $fh $msg;
}
