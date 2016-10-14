#!/usr/bin/perl -w

use Moose;
use Getopt::Long;
use MARC::Moose::Record;
use MARC::Moose::Metalib::Reader;
use MARC::Moose::Metalib::Converter::Metalib2Voyager;
use MARC::Moose::Formater::Text;
use MooseX::RW::Writer::File;
use Config::Simple;
use NelliISIL;

binmode(STDOUT, ":encoding(UTF-8)");

my %options = (
    'noftlcheck' => 0,
    'format' => 'text',
    'output' => '',
    'drop' => '',
    'cf' => ''
    );

my %conv_opt = (
    'logname' => 'Metalib2Voyager.log', #
    'extra_856_to_500' => 0,		#
    'swap210_245' => 0,			#
    'droplangcodes' => 0,		#
    'language' => 'fin',		#
    'add245b' => '',			# 
    'drop_publisher' => 0,		#
    'no977' => 0,			#
    'infosub856' => 'y',		#
    'publtext856' => '',		#
    'publcode856' => 'y',		#
    'localfields' =>'989',		#
    'cat_tag' => '',			#
    'no_op_653' => 0,			#
    'langsplit_520' => 0,		#
    'no520_9' => 0,			#
    );


sub usage() {
    print STDERR <<ENDUSAGE
Usage: $0 [ options ] metalib-xml-file
       Dump records in a Metalib export file to stdout in requested format
       after doing some conversions in the appropriate records.

       Options
		-format text|marc|xmlmarc
		-output filename
		-drop <tag>(,<tag>)*
		-cf configfilename
		-logname filename
		-swap210_245
		-droplangcodes
		-language fin|swe
		-extra_856_to_500
		-add245b text
		-infosub856 y|z|3
		-noftlcheck
		-cat_tag <tag>,<ind1>,<ind2>
		-langsplit_520
		-localfields <tag>
		-no977
		-drop_publisher
		-publtext856 <text>
		-publcode856 y|z|3
		-no_op_653
		-no520_9

       Default format is text and default log file name 'Metalib2Voyager.log'.

ENDUSAGE
;   exit 1;
}

my %cl_opt = ();
my %formatters = ('text'    => sub { MARC::Moose::Formater::Text->new()    }, 
		  'marc'    => sub { MARC::Moose::Formater::Iso2709->new() },  
		  'xmlmarc' => sub { MARC::Moose::Formater::Marcxml->new() },
    );

usage() if (!GetOptions(
		 \%cl_opt,
		 'format=s',
		 'output=s',
		 'drop=s',
		 'cf=s',
		 'noftlcheck',

		 'logname=s',
		 'swap210_245',
		 'droplangcodes',
		 'extra_856_to_500',
		 'add245b=s',
		 'language=s',
		 'infosub856=s',
		 'publtext856=s',
		 'publcode856=s',
		 'localfields=s',
		 'cat_tag=s',
		 'langsplit_520',
		 'no977',
		 'drop_publisher',
		 'no_op_653',
   ) 
   || ($#ARGV == -1) 
   || ($#ARGV > 1) 
   || !exists $formatters{$options{'format'}});

# read and process config file

my $cfg;
my $output;
my $cnv;

if(exists($cl_opt{'cf'}) && $cl_opt{'cf'} ne '') {
    die "Failed to read config file" unless defined($cfg = Config::Simple->new($cl_opt{'cf'}));
}

if(defined $cfg) {
    my $cf = $cfg->vars();
    map { $options{$_}  = $cf->{$_} if exists $cf->{$_}; } (keys %options);
    map { $conv_opt{$_} = $cf->{$_} if exists $cf->{$_}; } (keys %conv_opt);
}
# overrides from command line
map { $options{$_}  = $cl_opt{$_} if exists $cl_opt{$_}; } (keys %options);
map { $conv_opt{$_} = $cl_opt{$_} if exists $cl_opt{$_}; } (keys %conv_opt);


my $rawdump = 0;
my $reader = MARC::Moose::Metalib::Reader->new( file => $ARGV[0] );
my $dropthese = join('|', qw(024 073 270 307 50[56] 53[12] 57[45] 59[1235] 650 720 956 AF3 AIP ATG CJK FIL ICN
 			     INT LUP MTD NEW NWD NWP PXY REG RNK SES S[FP]X TAR TRN UPD VER VRD ZAT ZDC ZHS));

# these fields may contain ## -markup to be cleaned up
my $hashfields = ($conv_opt{'langsplit_520'} ? '500|545|LCL' : '500|520|545|LCL');	

$dropthese .= '|' . join('|', split(/,/, $options{'drop'})) if $options{'drop'} ne '';

die "Reader constructor failed" unless defined $reader;

unless($rawdump) {
    $reader->only001(1);
    $reader->dropfields($dropthese);
    $reader->hash2lf($hashfields);
}

die "Formatter constructor failed" unless defined (my $fmt = &{$formatters{$options{'format'}}});

if($options{'output'} ne '') {
    open($output, '>', $options{'output'}) or die "$0: cannot open output file \"$options{'output'}\": $!\n";
}
else {
    open($output, ">&STDOUT");
}

binmode($output, ":encoding(UTF-8)");

die "Converter constructor failed" 
    unless defined ($cnv = MARC::Moose::Metalib::Converter::Metalib2Voyager->new(%conv_opt));

my $log = $cnv->log();

my ($rec, $r, $s);
my $records = 0;
my $errors  = 0;
my @recs = ();
#my @ftlrecs = ();
my %recs_by_url = ();

$log->write("Conversion done on " . localtime() . ", input file \"$ARGV[0]\".\n");

while($rec = $reader->read()) {
    $r = $cnv->convert($rec);
    $errors++ unless $cnv->ok();
    push @recs, $r;
    $s = $cnv->ui_url();
    $recs_by_url{$s} = [[],[]] unless exists $recs_by_url{$s};	
    push @{$recs_by_url{$s}[$cnv->has_ftl()]}, $r;		
    $records++;
}


unless($options{'noftlcheck'}) {
    map {
	if(scalar(@{$recs_by_url{$_}[0]}) == 0) {  # no "no ftl" record for the url
	    $s = shift @{$recs_by_url{$_}[1]};	# leave one ftl record active
	    $r = ": another record (" . $s->field('035')->subfield('a') . ") already exists";
	}
	else {
	    if(scalar(@{$recs_by_url{$_}[0]}) > 1) {
		my @dupids = ();
		map { push @dupids, $_->field('035')->subfield('a'); } @{$recs_by_url{$_}[0]};
		$log->write("Info: Found duplicate records for the same url: " . join(', ', @dupids) . ".\n");
	    }
	    $r = ": full search record (" . $recs_by_url{$_}[0][0]->field('035')->subfield('a') . ") exists";
	}
	# deactivate rest of ftl records
	map {
	    $s = $_->field('035')->subfield('a');
	    $log->write("Info  (\"$s\"): Deactivating limited search record" . $r . ".\n");
	    $cnv->deactivate($_);
	} @{$recs_by_url{$_}[1]}
    } keys %recs_by_url;
}

my $prefix = ($options{'format'} eq 'text' ? '-' x 60 . "\n" : '');

print $output $fmt->begin();
map { print $output  $prefix . $fmt->format($_); } @recs;
print $output $fmt->end();

$log->write("\nFile \"$ARGV[0]\", $records record" . ($records == 1 ? '' : 's') . 
	    ", $errors conversion problem" .
	    ($errors == 1 ? '' : 's') . " reported.\n");

exit 0;


