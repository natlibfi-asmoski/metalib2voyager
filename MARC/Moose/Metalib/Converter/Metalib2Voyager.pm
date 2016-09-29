package MARC::Moose::Metalib::Converter::Metalib2Voyager;
# ABSTRACT: Converter to make valid MARC21 from Metalib export files
$MARC::Moose::Metalib::Converter::Metalib2Voyager::VERSION = '0.1.0';

#use Readonly;
use Encode qw(decode);
use Moose;
use MARC::Moose::Record;
use MARC::Moose::Field::Control;
use MARC::Moose::Field::Std;
use Data::Validate::URI;

with 'MARC::Moose::Metalib::Converter', 'MARC::Moose::Metalib::Converter::TimeSpanParser';

has urlvalidator => (is => 'rw', isa => 'Data::Validate::URI', builder => '_build_urlvalidator');
has organisation => (is => 'rw', isa => 'Str', default => '');
has val007       => (is => 'rw', isa => 'Str', default => 'cr||||||||||||');
has extra_856_to_500 => (is => 'rw', isa => 'Bool', default => 0);
has swap210_245  =>  (is => 'rw', isa => 'Bool', default => 0);
has droplangcodes => (is => 'rw', isa => 'Bool', default => 1);

#  008 field:
#  ----------
#  00-05: creation time
#  23:    resource type, 'o' means online
#  26:    
#  35-37: language ('mul' by default here)
has def008       => (is => 'ro', isa => 'Str', default =>       '                 o  j        mul  ');
#							   0123456789012345678901234567890123456789
#							             1         2         3      
has inst008      => (is => 'rw', isa => 'Str', default => '');
#
#  In the leader, we may want to set pos 7 according to the actual resource
#  Voyager bulk import requires 'a' in pos 9 to signify utf-8.
has leader   =>  (is => 'rw', isa => 'Str', default => '00000nmc a       4i 4500');
#							012345678901234567890123
# 							          1         2
#  BTW, Finna xsl transformation set the leader to     '     nai a22     ua 4500'
#
#  Additions
#  The original Finna xsl transformation added the field 977  a Database
#  that Finna needs to be able to show the record when browsing databases.
#
has additions => (is => 'ro', isa => 'ArrayRef', builder => '_build_additions' ); 
#
# Function parameters: ref to converter, ref to field, ref to whole record, parameter hash from the table 
# Return value: a list of converted fields that also may be empty.  
# The original field will be substituted by the resulting list.
#
has table => (is => 'ro', isa => 'HashRef[ArrayRef]', builder => '_build_optable' );

has seen856 => (is => 'rw', isa => 'HashRef', default => sub { {} } );
has f856 =>    (is => 'rw', isa => 'HashRef', default => sub { {} } );

sub _build_urlvalidator {
    return Data::Validate::URI->new();
} 

sub _build_optable {
    return { 
	'001' => [ \&do001,  {}, ],
	'110' => [ \&simple, { 't' => '710', 'i1' => '2', 'i2' => ' ' } ],  # preserve original item if 
	'210' => [ \&simple, {		 'i1' => '0', 'i2' => ' ' } ],  # substitute not given here, 
	'245' => [ \&do245,  {}, ],
	'246' => [ \&simple, { 		 'i1' => '3', 'i2' => ' ' } ],  # e.g. 210 stays 210
	'260' => [ \&simple, { 't' => '264', 'i1' => '3', 'i2' => '1' } ],
	'500' => [ \&do500,  { 'droplang' => 'a' } ],
	'513' => [ \&do513,  {}, ], #[ \&drop,   {}, ],  
	'520' => [ \&do520,  {'droplang' => 'a'}, ],
	'540' => [ \&do540,  {}, ],
	'545' => [ \&simple, { 't' => '550', 'i1' => ' ', 'i2' => ' ' } ],
	'546' => [ \&do546,  {}, ],
	'561' => [ \&do561,  {}, ],
	'590' => [ \&do590,  {}, ], #[ \&simple, { 't' => '500', 'i1' => ' ', 'i2' => ' ' } ],  
	'594' => [ \&do594,  {}, ],
	'653' => [ \&do653,  {}, ],
	'655' => [ \&simple, { 		 'i1' => ' ', 'i2' => '4' } ],
	'710' => [ \&noop,   {}, ],
	'856' => [ \&do856,  {}, ],
	'902' => [ \&do902,  {}, ],
	'976' => [ \&noop,   {}, ],
	'AF1' => [ \&af1,    {}, ],
	'CAT' => [ \&drop,   {}, ],  # could drop these already in initialise()
	'CKB' => [ \&drop,   {}, ],  # for the time being; have to figure out FTL handling first
	'FTL' => [ \&drop,   {}, ],  # for the time being
	'LCL' => [ \&simple, { 't' => '989',	      'i2' => ' ' } ],
	'STA' => [ \&doSTA,  {}, ],  # 988; will be used as filtering value in Voyager harvesting
    };
}

sub BUILD {
    my $self = shift;
    my $t = $self->table();

    if($self->swap210_245()) {
	$t->{'245'} = [ \&simple, { 't' => '210', 'i1' => '0', 'i2' => ' ' } ];
	$t->{'210'} = [ \&do245,  { 's' => 1 }, ];
    }
    unless($self->droplangcodes()) {
	delete $t->{'520'}[1]{'droplang'};
	delete $t->{'500'}[1]{'droplang'};
    }
    my $log = $self->log();
    unless(defined($log) && ref($log) eq 'Marc::Moose::Metalib::Converter::Logfile') {
	$log = MARC::Moose::Metalib::Converter::Logfile->new(file => $self->logname());
	$self->log($log);
    }
    binmode($log->fh(), ":encoding(UTF-8)");
}

my $isilIds = {
#    'AA' =>		[qw(FI-Abo FI-Abo-ASA FI-Abo-ICT FI-Åh FI-Åx)],
    'AA' =>		[qw(FI-Abo)],
    'ARCADA' =>		[qw(FI-Arcada)],	# agreed with Ann-Kristin Åvall on Sep 21, 2016
#    'DIAK' =>		[qw(FI-Diak FI-Diao FI-Diap FI-Diaa)],
    'DIAK' =>		[qw(FI-Diak)],		# agreed with Hanna Saario on Sep 23, 2016
    'EKAMK' =>		[qw(FI-Ekaic FI-Ekaim FI-Ekals FI-Ekalt)],
    'EVTEK' =>		[qw(FI-Metag FI-Metbu FI-Metha FI-Metko FI-Metle FI-Metmy 
                            FI-Meton FI-Metpo FI-Metso FI-Metti FI-Mettu FI-Metvi)],
    'HAAGA' =>		[qw(FI-Hihi)],
    'HAAGA-HELIA' =>	[qw(FI-Helib FI-Helip FI-Hihli FI-Himli FI-Hivli)],
#    'HAMK' =>		[qw(FI-Hamk FI-Hamk-F FI-Hamk-La FI-Hamk-Le FI-Hamk-M FI-Hamk-E FI-Hamk-R FI-Hamkv)],
    'HAMK' =>		[qw(FI-Hamk)],  	# agreed with Jarmo Loponen on Sep 8, 2016
#    'HKKK' =>		[qw(FI-K FI-Aalto)],
    'HKKK' =>		[qw(FI-Aalto)],		# agreed with Mari Aaltonen on Sep 23, 2016
    'HUMAK' =>		[qw(FI-Humal FI-Humki FI-Humks FI-Humku FI-Humpa FI-Humpk FI-Humps FI-Humta)],
#    'HY' =>		[qw(FI-H3 FI-Hb FI-Hc FI-HELKA FI-Hh FI-Hhant FI-Hhkki FI-Hhlitt FI-Hhmus FI-Hhsuo
#			    FI-Hhtai FI-Hhu38 FI-Hk FI-Hl FI-Hlham FI-Hlhlm FI-Hloik FI-Hmetm FI-Hmkti FI-Ho
#			    FI-Hq FI-Hs FI-Ht FI-Hul FI-Hv FI-Hxai)],
    'HY' =>		[qw(FI-Hul)],  		# agreed with Maria Kovero on Sep 27, 2016
#    'JAMK' =>		[qw(FI-Jadyn FI-Jakir FI-Jaluo FI-Jamus)],
    'JAMK' =>		[qw(FI-Jakir)], 	# agreed with Tuija Ylä-Sahra on Sep 19, 2016
#    'JY' =>		[qw(FI-J FI-Jmus FI-Jx)],
    'JY' =>		[qw(FI-J)],		# agreed with Hannu Markkanen on Sep 22, 2016
    'KAJAK' =>		[qw(FI-Kamk)],
    'KPAMK' =>		[qw(FI-Kphum FI-Kpkk FI-Kptes)],
    'KTAMK' =>		[qw(FI-Ktah FI-Ktai FI-Ktao FI-Ktat)],
#    'KUVA' =>		[qw(FI-Tx FI-ARSCA)],    # BTW, KUVA is obsolete, SIBA is used for KUVA and TEAK
    'KUVA' =>		[qw(FI-Tx FI-Sib FI-SibK FI-Teat)],    # Agreed with Erkki Huttunen on Sep 8, 2016
    'KYAMK' =>		[qw(Fi-Kymka FI-Kymme FI-Kymte FI-Xamk)],
    'LAUREA' =>		[qw(FI-Evahy FI-Evale FI-Evalo FI-Evalp FI-Evava FI-Laupo)],
    'LTY' =>		[qw(FI-L)],		# agreed with Pia Paavoseppä on Sep 22, 2016
    'LY' =>		[qw(FI-R)],
    'MAMK' =>		[qw(FI-Mamk-M FI-Mamk-S FI-Xamk)],
    'METROPOLIA' =>	[qw(FI-Metag FI-Metbu FI-Metha FI-Metko FI-Metle FI-Metmy FI-Meton FI-Metpo
       			    FI-Metso FI-Metti FI-Mettu FI-Metvi)],
    'OAMK' =>		[qw(FI-Oakau FI-Oamok FI-Oaout FI-Oasot FI-Oatek)],
    'OY' =>		[qw(FI-Oakau FI-Ol)],
    'PHKK' =>		[qw(FI-Lamk FI-Lakk(?) FI-Phfa FI-Phft FI-Phhe FI-Phmi FI-Phnt FI-Phot
			    FI-Phpa FI-Phpyk FI-Phso FI-Phst)],
    'PKAMK' =>		[qw(FI-Kareli)],
    'RAMK' =>		[qw(FI-Rkaup FI-Rm FI-Rteku FI-Rteso)],
    'SAMK' =>		[qw(FI-Samk0 FI-Samk1 FI-Samk2 FI-Samk4 FI-Samk5 FI-Samk6 FI-Samk8 FI-Samk9 FI-Ttp)],
    'SAVONIA' =>	[qw(FI-Pssti FI-Psstk FI-Pstek FI-Pstew)],
#    'SEAMK' =>		[qw(FI-Sekor FI-Sekau FI-Sekäs FI-Semaa FI-Semet FI-Serav FI-Seter)],
    'SEAMK' =>		[qw(FI-Sekor)],		# agreed with Jarkko Meronen on Sep 22, 2016
    'SHH' =>		[qw(FI-Z)],
    'SIBA' =>		[qw(FI-Tx FI-Sib FI-SibK FI-Teat)],    # Agreed with Erkki Huttunen on Sep 8, 2016
#    'SIBA' =>		[qw(FI-Sib FI-SibK FI-ARSCA)],  
    'STADIA' =>		[qw(FI-Metag FI-Metbu FI-Metha FI-Metko FI-Metle FI-Metmy FI-Meton
			    FI-Metpo FI-Metso FI-Metti FI-Mettu FI-Metvi)],
#    'SYH' =>		[qw(FI-Vaz FI-Vaz-Jstad)],
    'SYH' =>		[qw(FI-Vaz)],		# agreed with Christian Nelson on Sep 12, 2016
#    'TAIK' =>		[qw(FI-Ta FI-Aalto)],
    'TAIK' =>		[qw(FI-Aalto)],		# agreed with Mari Aaltonen on Sep 23, 2016
#    'TAMPERE' =>	[qw(FI-Tamk FI-Tamkt)],
    'TAMPERE' =>	[qw(FI-Tamk)],		# agreed with Hannu Hahto on Sep 23, 2016
    'TAY' =>		[qw(FI-Y FI-Yh FI-Yk FI-Yl FI-Yx)],
#    'TEAK' =>		[qw(FI-Teat FI-ARSCA)],  # BTW, TEAK is obsolete, SIBA is used for KUVA and TEAK
    'TEAK' =>		[qw(FI-Tx FI-Sib FI-SibK FI-Teat)],    # Agreed with Erkki Huttunen on Sep 8, 2016
#    'TKK' =>		[qw(FI-P FI-P-ETA FI-P-IL FI-P-KM FI-P-TFM FI-Aalto)],
    'TKK' =>		[qw(FI-Aalto)],		# agreed with Mari Aaltonen on Sep 23, 2016
    'TTY' =>		[qw(FI-Tt FI-Ttk)],
#    'TUAMK' =>		[qw(FI-Tua FI-Tual FI-Tuas FI-Tuau FI-Tule FI-tuli FI-Turu FI-Tuse)],
    'TUAMK' =>		[qw(FI-Tua)],  		# agreed with Liisa Tiittanen on Sep 14, 2016
    'TUKKK' =>		[qw(FI-F)],
#    'TY' =>		[qw(FI-Ta FI-Tl FI-To FI-Tpo FI-Tro FI-Tyyk)],
    'TY' =>		[qw(FI-T)], 		# Agreed with Jouni Aaltonen on Sep 12, 2016
#    'UEF' =>		[qw(FI-Jo FI-Jok FI-Jom FI-Jos FI-Jox FI-Ku)],
    'UEF' =>		[qw(FI-Ku)],		# agreed with Harri Kalinen on Sep 7, 2016
    'VAMK' =>		[qw(FI-Vamk)],		# agreed with Christian Nelson on Sep 12, 2016
#    'VY' =>		[qw(FI-Vaz)], 
    'VY' =>		[qw(FI-V)],		# agreed with Christian Nelson on Sep 12, 2016
#   Public libraries
    'E-KARJALA' =>	[qw(FI-Unknown)],   	# dummies at the moment
    'ETELA-SAVO' =>	[qw(FI-Unknown)],
    'ITA-UUSIMAA' =>	[qw(FI-Unknown)],
    'KANTA-HAME' =>	[qw(FI-Unknown)],
    'KESKI-SUOMI' =>	[qw(FI-Unknown)],
    'KYMENLAAKSO' =>	[qw(FI-Unknown)],
    'PAIJAT-HAME' =>	[qw(FI-Unknown)],
    'PIRKANMAA' =>	[qw(FI-Unknown)],
    'P-KARJALA' =>	[qw(FI-Unknown)],
    'POHJANPORTTI' =>	[qw(FI-Unknown)],
    'POHJOIS-SAVO' =>	[qw(FI-Unknown)],
    'PORSTUA' =>	[qw(FI-Unknown)],
    'SATAKUNTA' =>	[qw(FI-Unknown)],
    'UUSIMAA' =>	[qw(FI-Unknown)],
    'VARS-SUOMI' =>	[qw(FI-Unknown)],
};

sub _build_additions {
    my @fields;
    my $f;
    my @asrc = ( 
	{
	    'tag' => '300', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', "1 verkkoaineisto"]],  # varmista!
	},
	{
	    'tag' => '336', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', "teksti"], ['b', 'txt'], ['2', 'rdacontent']],
	},
	{
	    'tag' => '337', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', decode('UTF-8', "tietokonekäyttöinen")], ['b', 'c'], ['2', 'rdamedia']],
	},
	{
	    'tag' => '338', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', "verkkoaineisto"], ['b', 'cr'], ['2', 'rdacarrier']],
	},
	{
	    'tag' => '977', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', "Database"]],
	},
	);

    foreach $f (@asrc) {
	push(@fields, MARC::Moose::Field::Std->new($f));
    }
	
    return \@fields;
}


sub initialise { 
    my ($self, $rec) = @_;

    my @cats = $rec->field('CAT');
    my $s = $rec->field('001');
    my ($date, $fdate);

    return 0 unless defined $s; # there is a handful of empty records in the data
    $s = $s->value();		# (but the reader now skips them)
    $self->recordid($s);

    $self->seen856( { '1' => {}, '2' => {}, '9' => {} } );
    $self->f856( { '1' => [], '2' => [], '9' => [] } );

    $s = $rec->field('AF1');
    $s = $s->subfield('a');
    $self->organisation($s);

    # Need to grab the necessary data to create field 008 in finish() after 
    # the original fields have been processed. 
    # Now we only look in the CAT fields to set the record creation date, but
    # we'll want to set the language code according to the 546 field.  It will be
    # needed for the 041 field, too.
    $fdate = 99999999;
    foreach $s (@cats) {
	$date = $s->subfield('c');
	$fdate = $date if(defined $date && $date < $fdate);
    }
    # Note that at least one CAT field is always present in the data
    $s = ($fdate == 99999999 ? "      " : substr("$fdate", 2)) . $self->def008();
    $self->inst008($s);
    1;
}

sub getIsilIds { 
    my ($self, $mlId) = @_;

    return undef unless exists $isilIds->{$mlId};
    return  $isilIds->{$mlId};
}


#   
#   Fill in the value of the 008 field and insert it with the 007 one.
#   Multiple 041 fields will reset language code to 'mul' in field 008.
#
sub finish { 
    my($self, $flist) = @_;
    my ($s, $e, $tmp);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $links;

    if(scalar(grep { $_->{'tag'} eq '041' } @{$flist}) > 1) {
	$e = $self->inst008();
	$s = substr $e, 35, 3, 'mul';
	$self->inst008($e);
    }
    # The tenth-of-a-second here is fictive.  Sori siitä.
    $s = sprintf("%04d%02d%02d%02d%02d%02d.0", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
    unshift(@{$flist}, 
	    (MARC::Moose::Field::Control->new( {'tag' => '007', 'value' => $self->val007()} ),
	     MARC::Moose::Field::Control->new( {'tag' => '008', 'value' => $self->inst008()} ),
	     MARC::Moose::Field::Control->new( {'tag' => '005', 'value' => $s} )
	    )
	);

    ($s, $links) = $self->process856set();

    if($s) {
	($e) = grep { $_->{'tag'} eq '988' } @{$flist};
	# just in case orig STA was broken
	unless(defined($e)) {
	    $e = MARC::Moose::Field::Std->new('tag' => '988');
	    push(@{$flist},  $e);
	}
	if((not defined($tmp = $e->subfield('a'))) || $tmp eq 'ACTIVE') {
	    $e->subf( [ [ 'a', 'INACTIVE' ] ] );
	    $e->ind1(0);
	    $e->ind2(' ');
	    $self->info("Resource has no " . ($s eq '2' ? 'valid ': '') . 
			"link for human UI, setting it to inactive state.");
	}
    }
    return sort { $a->{'tag'} cmp $b->{'tag'} } (@{$flist}, @{$links});
}
#
#   Parameters: ref to list of all fields in record
#   Returns:    (status, ref to list of all fields in record)
#		status = 0 if ok, 1 if no UI link, 2 if UI link syntactically incorrect
#
# If there are several different links for each ind2 value of 856 fields, we'll choose one and store
# the other ones in 500 fields.  Field instance order and link validity count in our choice.  
# If first instance of UI link is not syntactically correct, we'll set the record to inactive state.
#
sub process856set {
    my $self = shift;
    my $fields = $self->f856();
    my @res = ();
    my ($s, $i, $f);
    my $nelliseen = 'Field 856 mentions nelliportaali, please review it.';
    my $badurlu = "Questionable format of url in field 856 \$u, please check and correct if needed:\n\t\t    ";
    my $badurla = "Questionable format of url in field 856 \$a, please check and correct if needed:\n\t\t    ";
    my $v = $self->urlvalidator();
    my %labels = ('1' => 'UI', '2' => 'publisher', '9' => 'database guide');
    
    if(0) {  # BUGABOO!
	print STDOUT "856 fields:\n";
	foreach $i (sort keys %labels) {
	    foreach $f (@{$fields->{$i}}) {
		print STDOUT $f->as_formatted(), "\n";
	    }
	}
    }
    return (1, [@{$fields->{'2'}}, @{$fields->{'9'}}]) unless(scalar @{$fields->{'1'}});
    unless(defined($v->is_web_uri($s = $fields->{'1'}[0]->subfield('u')))) {
	$self->info("Questionable format of database UI url in field 856 \$u, ". 
		    "please check and correct if needed:\n\t\t    $s");
	return (2, [@{$fields->{'1'}}, @{$fields->{'2'}}, @{$fields->{'9'}}]);
    }

    foreach $i (sort keys %labels) {
	$self->info("more than one $labels{$i} link in record, please review and verify correctness") 
	    if (scalar @{$fields->{$i}}) > 1;

	# There are often invalid urls in the data, so detect and report them;
	# also detect links to Nelliportaali.
	foreach $f (@{$fields->{$i}}) {
	    if(defined($s = $f->subfield('u'))) {
		$self->info($nelliseen) if $s =~ m/nelliportaali/gio;
		$self->info($badurlu . $s) if not defined($v->is_web_uri($s));
	    }
	    if($i eq '2') {
		if(defined($s = $f->subfield('a'))) {
		    $self->info($nelliseen) if $s =~ m/nelliportaali/gio;
		    $self->info($badurla . $s) if not defined($v->is_web_uri($s));
		}
	    }
	}
    }
    return (0, [@{$fields->{'1'}}, @{$fields->{'2'}}, @{$fields->{'9'}}]) 
	unless $self->extra_856_to_500() && 
	(scalar @{$fields->{'1'}} > 1 || scalar @{$fields->{'2'}} > 1 || scalar @{$fields->{'9'}} > 1);

    $self->info("Moving contents of extra 856 fields into one 500 field.");
    @res = (shift @{$fields->{'1'}});
    push(@res, $s) if defined($s = shift @{$fields->{'2'}});
    push(@res, $s) if defined($s = shift @{$fields->{'9'}});

    $s = '';
    foreach $i (sort keys %labels) {
	map { $s .= $_->as_formatted() . "\n"; } @{$fields->{$i}};
    }
    push(@res, MARC::Moose::Field::Std->new(
		    'tag' => '500', 
		    'ind1' => ' ',
		    'ind2' => ' ',
		    'subf' => [ ['a', 
				 "Converter found the following (extra) 856 instances in the record:\n". $s
				] 
		    ]
		)
	);
    return (0, \@res);
}

#
#   In field 856, indicator 1 is always 4.  Those fields whose indicator 2 is 3,4,5, or 6 will be removed.
#   Subfield s is the result of an error in Metalib and will be removed.
#   Most of the a subfields appear in a field that also has subfield u, and i2 is always 2 when 
#   subfield a is present.
#
sub do856 {
    my ($self, $fld, $rec, $param) = @_;
    my @subs = ();
    my ($u, $a, $i2, $s);
    my $seen = $self->seen856();
    my $links = $self->f856();

    $i2 = $fld->ind2();
    if($i2 eq '1' || $i2 eq '9') {
	# With these i2 values, there should be only one subfield, $u.
	# Other subfields may appear as produced by a Metalib bug.  We'll remove them.
	$u = $fld->subfield('u');
	unless(defined $u) {
	    $self->ok(0);
	    $self->error("no subfield u in field 856 with ind2=$i2");
	    return ($fld);	# this instance is broken, we'll keep it as is for later investigation
	}
	return () if $seen->{$i2}{$u}++;  # drop duplicates
	@subs = ( ['u', $u], ['y', $i2 eq '1' ? "Database Interface" : "Database Guide"]);
	$fld->ind2($i2 eq '1' ? 0 : 2) ;  # i2=9 will be set to 2
	$fld->subf(\@subs);
	push(@{$links->{$i2}}, $fld);	  # store for later processing
    }
    elsif($i2 eq  '2') {	
	#  The publisher 856 field may have $a for server, $u for url, or both.
	$u = $fld->subfield('u');

	$a = $fld->subfield('a');
	$s = (defined($a) ? "a:$a" : '');
	$s .= (($s ne '' && defined($u)) ? "##u:$u" : (defined($u) ? "u:$u" : ''));
	
	if($s eq '') {
	    $self->ok(0);
	    $self->error("neither subfield u nor subfield a in field 856 with ind2=2");
	    return ($fld);
	}
	return () if $seen->{$i2}{$s}++;  # drop duplicates

	push(@subs, ['a', $a]) if(defined($a) && ($a ne ''));
	push(@subs, ['u', $u]) if(defined($u) && ($u ne ''));
	$fld->ind2('2') ;  
	$fld->subf(\@subs);
	push(@{$links->{'2'}}, $fld);
    }
    return ();  # other 856 fields are skipped
}

#
#   Simple conversions leave subfields and data alone.  The function creates no additional fields.
#
sub simple {
    my ($self, $fld, $rec, $param) = @_;

    $fld->tag($param->{'t'})   if exists $param->{'t'};
    $fld->ind1($param->{'i1'}) if exists $param->{'i1'};
    $fld->ind2($param->{'i2'}) if exists $param->{'i2'};
    $self->ok(1);
    return ($fld);
}

sub do500 {
    my ($self, $fld, $rec, $param) = @_;

    $fld->tag('520');
    $fld->ind1('2');
    $fld->ind2(' ');

    my $sflds = $fld->subf();

    map {
	if($_->[0] eq 'a') {
	    $_->[1] =~ s/\[(fi|s[evw]|e[ns])\]/\n/go if exists $param->{'droplang'};
	    $self->info('Field 500 mentions nelliportaali, please review it.') if $_->[1] =~ m/nelliportaali/gio;
	}
    } @{$sflds};

    $fld->subf($sflds);
    $self->ok(1);
    return ($fld);
}

sub af1 {
    my ($self, $fld, $rec, $param) = @_;

    my ($idList, $i, @af1fields);
    my $rfield;
    my $mlId = $fld->subfield('a');

    unless(defined $mlId) {
	# Never seen this but who knows when and how Metalib will break
	$self->error("AF1 field without subfield a, skipping it");
	$self->ok(0);
	return ();
    }
    $idList = $self->getIsilIds($mlId);
    unless(defined $idList) {
	# This shouldn't happen either
	$self->error("unrecognised organisation id \"$mlId\", skipping field \"AF1\"");
	$self->ok(0);
	return ();
    }
    foreach $i (@{$idList}) {
	$rfield = MARC::Moose::Field::Std->new(
	    {
	    'tag' => '850', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', decode('UTF-8', $i)]],
	    }
	    );
	push(@af1fields, $rfield);
    }
    return @af1fields;
}

sub do001 {
    my ($self, $fld, $rec, $param) = @_;

    my ($idList, $i, @af1fields);
    my $rfield;
    my $recId = $fld->value();
    my $mlId = $self->organisation();

    unless(defined $mlId) {
	$self->error("organisation id not defined for record");
	$self->ok(0);
	return ();
    }
    $idList = $self->getIsilIds($mlId);
    unless(defined $idList) {
	$self->error("unrecognised organisation id \"$mlId\", skipping field \"001\"");
	$self->ok(0);
    }
    foreach $i (@{$idList}) {
	$rfield = MARC::Moose::Field::Std->new(
	    {
	    'tag' => '035', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', decode('UTF-8',"($i)") . $recId]],
	    }
	    );
	push(@af1fields, $rfield);
    }
    return @af1fields;
}

sub do245 {
    my ($self, $fld, $rec, $param) = @_;
    my $title = $fld->subfield('a');

    # The regexp below is the result of an empirical investigation of the data and should fit the need.
    $fld->ind1('0');
    $fld->ind2($title =~ m/(Käsikirjasto-[A-Z]|L\'|Le |The |Die |Der |Das)/go ? length($1) : 0);
    $fld->tag('245') if exists $param->{'s'};	    # doing title swapping
    return ($fld);
}


#   Split the value and generate one instance of the 653 field for each part.
#   Expressions like "nursing medicine" and "veterinary medicine" in the field would generate 
#   multiple instances of the keyword "medicine", so we'll filter out any and all duplicates.
#
sub do653 {
    my ($self, $fld, $rec, $param) = @_;
    my @fields = ();

    my $s = $fld->subfield('a'); 
    unless(defined($s)) {
	$self->error("missing subfield a in field 653");
	$self->ok(0);
	return ();
    }
    
    $s =~ s/\[(fi|s[evw]|e[ns])\]/\n/go if $self->droplangcodes(); # drop language codes
    $s =~ s/^\s+|\s+$//go;
    my @keywords = split(/[;,\s]+/o, $s);
    my %stored = ();

    map {
	if($_ !~ m/^\[[a-z]+\]$/o && $_ ne '' && not $stored{$_}++) {
	    push(@fields, MARC::Moose::Field::Std->new(
		     'tag'  => '653',
		     'ind1' => '0',
		     'ind2' => ' ',
		     'subf' => [ ['a', $_] ]
		 ));
	}
    } @keywords;
    return @fields;
}

#   handle restrictions, store data in correct format in a 506 field;
#   also, with those resources that don't have a valid url, the 506 value, if present, will be misleading
#
sub do594 {
    my ($self, $fld, $rec, $param) = @_;
    my $i1;
    my $r = $fld->subfield('a');  # should check for anomalies...

    unless(defined($r)) {
	$self->error("missing subfield a in field 594");
	$self->ok(0);
	return ();
    }
    if($r =~ m/^FREE.*/go) {	# also here can be rubbish after a proper value
	$i1 = 0;				 
	$r = 'Unrestricted online access';	 
    }
    elsif($r =~ m/^SUBSCRIPTION.*/) {
	$i1 = 1;
	$r = 'Online access with authorization';
    }
    elsif($r =~ m/^\s*https?:/o) {               # urls can be seen here when the free/restricted attribute
	$i1 = 0;				 # has not been chosen either way in Metalib; 
	$r = 'Unrestricted online access';	 # empirically these cases have been free resources
	$self->info("undefined access policy resulted in an URL in field 594,\n" .
		    "\t\tnow set field 506 to 'Unrestricted onine access', please verify")
    }
    else {
	$self->error("unrecognised access policy value in field 594: \"$r\"");
	$self->ok(0);
	return ();
    }
    my $rfield = MARC::Moose::Field::Std->new( {'tag' => '506', 
						'ind1' => $i1,
						'ind2' => ' ',
						'subf' => [ ['f', $r], [ '2', 'star' ] ]
					       }
					       );
    return ($rfield);
}

my %langcodes = (
    'ARABIC' =>          'ara',
    'CHINESE' =>         'chi',
    'DANISH' =>          'dan',
    'DUTCH' =>           'dut',
    'ENGLISH' =>         'eng',
    'ESTONIAN' =>        'est',
    'FINNISH' =>         'fin',
    'FRENCH' =>          'fre',
    'GERMAN' =>          'ger',
    'GREEK' =>           'gre',
    'HEBREW' =>          'heb',
    'HINDI' =>           'hin',
    'HUNGARIAN' =>       'hun',
    'ICELANDIC' =>       'ice',
    'ITALIAN' =>         'ita',
    'JAPANESE' =>        'jpn',
    'KOREAN' =>          'kor',
    'LATIN' =>           'lat',
    'LITHUANIAN' =>      'lit',
    'NORWEGIAN' =>       'nor',
    'POLISH' =>          'pol',
    'PORTUGUESE' =>      'por',
    'RUSSIAN' =>         'rus',
    'SPANISH' =>         'spa',
    'SWEDISH' =>         'swe',
    );

my $langpat = '^(' . join('|', keys(%langcodes)) . ').*';
#   
#   Update 008, pos. 35-37 to language code, create 041.  008 value was set by initialise() and will
#   be added by finish().  546 itself is a free-form remark field, so no stress about the contents.  
#   And no need to touch the indicators. 
#   Also need to check if we need some (other) std names for the languages.
#  
#   Multiple instances of the 546 field should keep 008 code as 'mul'.  We'll fix this in finish().
#
sub do546 {
    my ($self, $fld, $rec, $param) = @_;

    my $s = $fld->subfield('a');
    my($c, $cfield, $e, $v);

    if(exists $langcodes{$s}) {
	# ok
    }
    elsif($s =~ m/$langpat/) {		# sometimes Metalib appends junk to field values
	$s = $1;    
	$self->info("cleaning up language name (to \"$s\") in field 546");
    }
    else {	# unrecognised language
	$self->ok(0);
	$self->error("unrecognised language ($s) in field 546");
	return ($fld);
    }
    $c =  $langcodes{$s};
    $s = "\u\L$s";			# pretty-print language name...
    $fld->subf( [ ['a', $s] ] );

    $cfield = MARC::Moose::Field::Std->new(
	    {
	    'tag' => '041', 
	    'ind1' => ' ', 
	    'ind2' => ' ',
	    'subf' => [['a', $c]],
	    }
	);
    # then adjust 008
    $e = $self->inst008();
    $s = substr $e, 35, 3, $c;
    $self->inst008($e);

    return ($fld, $cfield);
}

#   IRD status can be 'ACTIVE',	'INACTIVE', or 'TEST'.  Use field 988 to store it, with ind1
#
sub doSTA {
    my ($self, $fld, $rec, $param) = @_;
    my %states = ('INACTIVE' => 0, 'ACTIVE' => 1, 'TEST' => 2);

    my $s = $fld->subfield('a');

    if(!defined($s)) {
	$self->ok(0);
	$self->error("field STA: missing subfield a");
	return ();

    }
    elsif(exists $states{ $s } ) {
	$fld->ind1($states{ $s });
	$fld->tag('988');
    }
    else {
	$self->ok(0);
	$self->error("unrecognised record status in a STA field: \"$s\"");
	return ();
    }
    return ($fld);
}

#   This field is something like an archeological sediment in the database.  It is not shown in the
#   Metalib management interface (or anywhere else...) and so may have been inadvertently copied to
#   inappropriate resources.  It would be a smart thing to simply drop the whole field, but here we go...
#
sub do561 {
    my ($self, $fld, $rec, $param) = @_;

    my @links = $rec->field('856');
    my $l;

    ($l) = grep {$_->ind2() eq '1'} @links;  # trusting there is only one instance...
    unless(defined($l) && $l->subfield('u') =~ m/proquest|pollution|csa|ecology/o) {
	$self->info("Removed a 561 field not really related to the record.");
	return ();
    }
    $fld->tag('500');
    return ($fld);
}

sub _fillyear {    return sprintf '%04u', $_[0];    }
#   Still have to write proper versions of these:
#   [Parse the time span data, create a 045 field if we can make sense of the data,
#   or otherwise a 046 field. - forget the 045 for the moment, just do the 008.]
#   We'll have to update the 008 field, too.
#   Well, now we are building a 046 field after all.
#
sub do513 {
    my ($self, $fld, $rec, $param) = @_;

    my $res = $self->TSParser($fld);

    if($res->{'err'}) {
	$self->error($res->{'err'});
	$self->ok(0);
	$fld->tag('500');
	return ($fld);
    }

    # So now we got a more or less valid result.
    #
    my $resfld;
    my $s;

    # If we got '9999' end, we'll use the 046 field; indicators will be ' '.
    if($res->{'end'} eq '9999') {
	$resfld = MARC::Moose::Field::Std->new('tag' => '046', 'ind1' => ' ', 'ind2' => ' ',
					       'subf' => [ 
						   ['a' , 'i'], 
						   [ ($res->{'startera'} eq 'a' ? 'c' : 'b'), $res->{'start'} ],
						   [ ($res->{'endera'} eq 'a' ? 'e' : 'd'), $res->{'end'} ],
					       ]
	    );
    }
    else {
    #
    # If 'end' is not '9999', we'll use the 045 field.  
    # Then if it is a single year, end will be '', and we'll set ind1 to 0; otherwise ind2 will be 2.
    #
	#$res->{'startera'} eq 'b' || $res->{'endera'} eq 'b'
	my ($sf, $i1);
	if($res->{'end'} eq '') { 
	    $i1 = '0';
	    $sf = [ [ ($res->{'startera'} eq 'b' ? 'c' : 'd'), $res->{'start'} ]];
	}
	else {
	    $i1 = '2';
	    $sf = [
		[ ($res->{'startera'} eq 'b' ? 'c' : 'd'), $res->{'start'} ],
		[ ($res->{'endera'} eq 'b' ? 'c' : 'd'), $res->{'start'} ],
		];
	}
	$resfld = MARC::Moose::Field::Std->new('tag' => '045', 'ind1' => $i1, 'ind2' => ' ', 'subf' => $sf );
    }
    # now let's encode the data for use in the 008 field
    # also try and set position 06 correctly according to the years given
    $res->{'end'} = '    ' if $res->{'end'} eq '';
    my $timecode = ($res->{'startera'} ne 'b' && $res->{'endera'} ne 'b') ? 
	"c$res->{'start'}$res->{'end'}" : 'b       '; 
    $s = $self->inst008();
    substr $s, 7, 8, "$res->{'start'}$res->{'end'}";
    # publishing still continues/single publishing year/time span
    substr $s, 6, 1, ($res->{'end'} eq '9999' ? 'c' : ($res->{'end'} eq '    ' ? 's' : 'i'));
    $self->inst008($s);
    return ($resfld);
}

sub do540 {
    my ($self, $fld, $rec, $param) = @_;

    my $s = $fld->subfield('a');

    $self->info('Field 540 mentions nelliportaali, please review it.') if $s =~ m/nelliportaali/gio;

    if(defined $self->urlvalidator->is_web_uri($s)) {
	$fld->ind1(' ');
	$fld->ind2(' ');
	$fld->subf( [['u', $s ]] );
    }
    else {	# got an ordinary language name, perhaps
	$fld->tag('542');
	$fld->ind1(1);
	$fld->ind2(' ');
	$fld->subf( [['c', $s ]] );	# there are a handful of individual people's names, they'll be in the wrong
    }					# subfield (should be in a) but we can't recognise them reliably (yet?)
    return ($fld);
}

sub do590 {
    my ($self, $fld, $rec, $param) = @_;

    my $newfld = '';

    my $s = $fld->subfield('a');

    $self->info('Field 590 mentions nelliportaali, please review it.') if $s =~ m/nelliportaali/gio;

    if($s =~m/https?:/go) {
	if($s =~ m/(ehdot|conditions|oikeudet):\s*(http.*)/go) {
	    if(defined $self->urlvalidator->is_web_uri($2)) { #
		$newfld = MARC::Moose::Field::Std->new( {'tag' => '540', 'ind1' => ' ', 'ind2' => ' ',
							 'subf' => [[ 'u' => $2 ]] } );
	    }
	}
    }

    $fld->tag('500');
    $fld->ind1(' ');
    $fld->ind2(' ');
    $fld->subf( [[ 'a' , $s ]] );
    return ($fld, $newfld) if $newfld ne '';
    return ($fld);
}

sub do902 {
    my ($self, $fld, $rec, $param) = @_;
    my $newfld = '';
    #  The following strings are found in valid access right description _links_
    my $catcher = join('|', qw(aineistoehdot oikeudet permissions terms copyright conditions rules 
			       creativecommons legal access_use rattigheter license));
    my $s = $fld->subfield('a');

    $self->info('Field 902 mentions nelliportaali, please review it.') if $s =~ m/nelliportaali/gio;

    if(defined $self->urlvalidator->is_web_uri($s) && $s =~ m/$catcher/i) { 
		$newfld = MARC::Moose::Field::Std->new( {'tag' => '540', 'ind1' => ' ', 'ind2' => ' ',
							 'subf' => [[ 'u' => $s ]] } );
    }
    $fld->tag('500');
    $fld->ind1(' ');
    $fld->ind2(' ');
    $fld->subf( [[ 'a' , $s ]] );
    
    return ($fld, $newfld) if $newfld ne '';
    return ($fld);
}



sub noop {
    my ($self, $fld, $rec, $param) = @_;

    if(exists $param->{'droplang'}) {
	my $sflds = $fld->subf();
	my $c = $fld->subfield($param->{'droplang'});
	map {
	    if($_->[0] eq $c) {
		$_->[1] =~ s/\[(fi|s[evw]|e[ns])\]/\n/go;
	    }
	} @{$sflds};
	$fld->subf($sflds);
    }
    return ($fld);
}

sub do520 {
    my ($self, $fld, $rec, $param) = @_;
    my $sflds = $fld->subf();

    map {
	if($_->[0] eq 'a') {
	    $_->[1] =~ s/\[(fi|s[evw]|e[ns])\]/\n/go if(exists $param->{'droplang'});
	    $_->[1] =~ s/\@\@U([^@]+)\@\@D([^@]+)\@\@E/\[$2\]\($1\)/go;  # substitute markdown for Metalib markup
	    $self->info('Field 520 mentions nelliportaali, please review it.') if($_->[1] =~ m/nelliportaali/gio);
	}
    } @{$sflds};
    $fld->subf($sflds);

    return ($fld);
}

sub drop { 
    # LOGGING?
    return (); 
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MARC::Moose::Metalib::Converter::Metalib2Voyager - Convert Metalib export files to correct(ish) MARC21

=head1 VERSION

version 0.1.0

=head1 DESCRIPTION

This is it.

=head1 SEE ALSO

=over 4

=item *

L<MARC::Moose>

=item *

L<MARC::Moose::Converter>

=back

=head1 AUTHOR

Asmo Saarikoski 
National Library of Finland

=head1 COPYRIGHT AND LICENSE

STD NLF copyright statement here.
=cut
