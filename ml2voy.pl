#!/usr/bin/perl -w

use Moose;
use Getopt::Long;
use MARC::Moose::Record;
use MARC::Moose::Metalib::Reader;
use MARC::Moose::Metalib::Converter::Metalib2Voyager;
use MARC::Moose::Formater::Text;
use MooseX::RW::Writer::File;
use NelliISIL;

binmode(STDOUT, ":encoding(UTF-8)");

my $rec;
my $format = 'text';
my $outname = '';
my $logname = 'Metalib2Voyager.log';
my $drop = '';
my $swaptitles = 0;
my $keeplcodes = 0;


my %formatters = ('text' => sub { MARC::Moose::Formater::Text->new() }, 
		  'marc' => sub { MARC::Moose::Formater::Iso2709->new() },  
		  'xmlmarc' => sub {MARC::Moose::Formater::Marcxml->new() },
    );

if(!GetOptions('format=s' => \$format,
	       'output=s' => \$outname,
	       'logfile=s' => \$logname,
	       'swaptitles' => \$swaptitles,
	       'keeplangcodes' => \$keeplcodes,
               'drop=s' => \$drop
   ) || ($#ARGV == -1) || ($#ARGV > 1) || !exists $formatters{$format}) {
    print STDERR "Usage: $0 [ -format text|marc|xmlmarc -drop <tag>[,<tag>]* -swaptitles -output filename -logfile filename] metalib-xml-file\n";
    print STDERR "       Dump records in a Metalib export file to stdout in requested format\n";
    print STDERR "       after doing some conversions in the appropriate records.\n";
    print STDERR "       Default format is text and default log file name 'Metalib2Voyager.log'.\n";
    exit 1;
}

my $rawdump = 0;
my $reader = MARC::Moose::Metalib::Reader->new( file => $ARGV[0] );
my $dropthese = join('|', qw(024 073 270 307 50[56] 53[12] 57[45] 59[1235] 650 720 956 AF3 AIP ATG CJK FIL ICN
 			     INT LUP MTD NEW NWD NWP PXY REG RNK SES S[FP]X TAR TRN UPD VER VRD ZAT ZDC ZHS));
my $hashfields = '500|520|545|LCL';	# these fields may contain ## -markup to be cleaned up

if($drop ne '') {
    $dropthese .= '|' . join('|', split(/,/, $drop));
}
unless(defined $reader) {
    print STDERR "Kaboom, reader constructor failed: $!\n";
    exit 2;
}

unless($rawdump) {
    $reader->only001(1);
    $reader->dropfields($dropthese);
    $reader->hash2lf($hashfields);
}

my $fmt = &{$formatters{$format}};
unless(defined $fmt) {
    print STDERR "Kaboom, formatter constructor failed: $!\n";
    exit 3;
}

my $output;

if($outname ne '') {
    open($output, '>', $outname) or die "$0: cannot open output file \"$outname\": $!\n";
    binmode($output, ":encoding(UTF-8)");
}
else {
    open($output, ">&STDOUT");
}

my $cnv = MARC::Moose::Metalib::Converter::Metalib2Voyager->new(
    logname => $logname, 
    swap210_245 => $swaptitles,
    droplangcodes => !$keeplcodes,
    isil_table => NelliISIL->new()
    );

unless(defined $cnv) {
    print STDERR "Zap!  Converter constructor failed: $!\n";
    exit 4;
}
my $log = $cnv->log();
print STDERR "Kaboom, bad log! $!\n" unless defined $log;


my ($r, $s);
my $records = 0;
my $errors  = 0;
my @recs = ();
my @ftlrecs = ();
my %recs_by_url = ();

#$log->write("Conversion done on " . localtime() . ", input file $foo, parameters: $bar\n");

while($rec = $reader->read()) {
    $r = $cnv->convert($rec);
    $errors++ unless $cnv->ok();
    push @recs, $r;
    $s = $cnv->ui_url();
    push(@ftlrecs, [$r, $s]) if $cnv->has_ftl();
    $recs_by_url{$s} = [] unless exists $recs_by_url{$s};	# should really report multiple 
    push @{$recs_by_url{$s}}, $r;				# instances of the same url
    $records++;
}

# if(cmd line parameter for ftl handling) {
foreach $r (@ftlrecs) {
    next if scalar @{$recs_by_url{$r->[1]}} == 1;	# just one record, nothing to be done
#    $log->write("Removing limited search record " . $r->[0]->field('035') . ": full search record " . 
#		$recs_by_url{$r->[1]}->field('035') . " exists\n");
    $log->write("Removing limited search record: full search record exists.\n");
}
#}

print $output $fmt->begin();
foreach $r (@recs) {
    print $output '-' x 60 . "\n" if($format eq 'text');
    print $output $fmt->format($r) if($r != 0);
}
print $output $fmt->end();

$log->write("\nFile \"$ARGV[0]\", $records record" . ($records == 1 ? '' : 's') . 
	    ", $errors conversion problem" .
	    ($errors == 1 ? '' : 's') . " reported.\n");

exit 0;
