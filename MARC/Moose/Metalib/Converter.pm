package MARC::Moose::Metalib::Converter;
# ABSTRACT: A generic MARC record converter 
$MARC::Moose::Metalib::Converter::VERSION = '0.1.0';

use Moose::Role;
use MARC::Moose::Record;
use MARC::Moose::Field::Control;
use MARC::Moose::Field::Std;
#use MARC::Moose::Metalib::Converter::Metalib2Voyager;
use MARC::Moose::Metalib::Converter::Logfile;

has ok       => (is => 'rw', isa => 'Bool');			
has logname  => (is => 'rw', isa => 'Str', default => '&STDERR');
has log      => (is => 'rw', isa => 'MARC::Moose::Metalib::Converter::Logfile');
has loglevel => (is => 'rw', isa => 'Int', default => 3);
has recordid     => (is => 'rw', isa => 'Str', default => '');

# You should initialize the log in the consumer BUILD, e.g.
#
# sub BUILD {
#    my $log = $self->log();
# 
#    unless(defined $log) {
#	my $log = MARC::Moose::Metalib::Converter::Logfile->new('file' => $self->logname());
#	$self->log($log);
#    }
#    binmode($log->fh(), ":encoding(UTF-8)");
# }

sub convert {
    my ($self, $rec) = @_;
    my ($f, $i, @rfields);
    my @wfields = @{$rec->fields()};       	# Get all fields from the record
    my $ct = $self->table();
    my $report = '';
    my $err = '';
    my $errSeen = 0;
    
    # run conversion from table
    $i = 0;

    unless($self->initialise($rec)) {
	$self->ok(0);
	return $rec;
    }
    while($i < scalar @wfields) {
	unless(exists($ct->{$wfields[$i]->tag()})) { 
	    $self->error("unrecognised tag \"" . $wfields[$i]->tag() . "\"");
	    $i++; 
	    $errSeen = 1;
	    next; 
	} 
	$self->ok(1);
	@rfields = &{$ct->{$wfields[$i]->tag()}[0]}($self, $wfields[$i], $rec, $ct->{$wfields[$i]->tag()}[1]); 
	$errSeen |= (not $self->ok());
	splice(@wfields, $i, 1, @rfields); 	# merge fields
	$i += scalar @rfields;
    }
    
    @wfields = (@wfields, @{$self->additions()});   # do "stand-alone" additions given as a ready-made list 
    						    # of fields
    @wfields = $self->finish(\@wfields);    	    # polish the results if needed
    $i = $self->leader();
    $rec->_leader($i);				    # update leader when necessary
    $rec->fields(\@wfields);			    # reinsert converted fields
    $self->ok(not $errSeen);			    # 
    return $rec;
}


sub error {
    my($self, $msg) = @_;
    $self->log()->write("Error (" . $self->recordid() . "): " . $msg . "\n");
}

sub info {
    my($self, $msg) = @_;
    $self->log()->write("Info  (" . $self->recordid() . "): " . $msg . "\n"); # could use log levels here
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MARC::Moose::Metalib::Converter - A record converter base class

=head1 VERSION

version 0.1.0

=head1 METHODS

=head2 lint

=head2 begin

=head2 end

=head2 parse

Return a converted MARC::Moose::Record object 

=head1 SEE ALSO

=over 4

=item *

L<MARC::Moose>

=back

=head1 AUTHOR

=head1 COPYRIGHT AND LICENSE

=cut
