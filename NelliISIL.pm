package NelliISIL;
# ABSTRACT: Mapping of Metalib organisation ids to ISIL ids

use Moose;

has isilIds => (is => 'ro', isa => 'HashRef', builder => '_build_ISILtable' ); 


sub getIsilIds { 
    my ($self, $mlId) = @_;

    return undef unless exists $self->isilIds()->{$mlId};
    return  $self->isilIds()->{$mlId};
}

sub _build_ISILtable {
    return {
#    'AA' =>		[qw(FI-Abo FI-Abo-ASA FI-Abo-ICT FI-Åh FI-Åx)],
     'AA' =>		[qw(FI-Abo)], 		# agreed with Andreas Söderlund on Oct 6, 2016
    'ARCADA' =>		[qw(FI-Arcada)],	# agreed with Ann-Kristin Åvall on Sep 21, 2016
#    'DIAK' =>		[qw(FI-Diak FI-Diao FI-Diap FI-Diaa)],
    'DIAK' =>		[qw(FI-Diak)],		# agreed with Hanna Saario on Sep 23, 2016
#    'EKAMK' =>		[qw(FI-Ekaic FI-Ekaim FI-Ekals FI-Ekalt)],
    'EKAMK' =>		[qw(FI-Eka)],		# agreed with Pia Paavoseppä on Sep 30, 2016
    'EVTEK' =>		[qw(FI-Metag FI-Metbu FI-Metha FI-Metko FI-Metle FI-Metmy 
                            FI-Meton FI-Metpo FI-Metso FI-Metti FI-Mettu FI-Metvi)],
    'HAAGA' =>		[qw(FI-Hihi)],
#    'HAAGA-HELIA' =>	[qw(FI-Helib FI-Helip FI-Hihli FI-Himli FI-Hivli)],
    'HAAGA-HELIA' =>	[qw(FI-Helip)],		# agreed with Johanna Miettunen on Oct 10, 2016
#    'HAMK' =>		[qw(FI-Hamk FI-Hamk-F FI-Hamk-La FI-Hamk-Le FI-Hamk-M FI-Hamk-E FI-Hamk-R FI-Hamkv)],
    'HAMK' =>		[qw(FI-Hamk)],  	# agreed with Jarmo Loponen on Sep 8, 2016
#    'HKKK' =>		[qw(FI-K FI-Aalto)],
    'HKKK' =>		[qw(FI-Aalto)],		# agreed with Mari Aaltonen on Sep 23, 2016
#    'HUMAK' =>		[qw(FI-Humal FI-Humki FI-Humks FI-Humku FI-Humpa FI-Humpk FI-Humps FI-Humta)],
    'HUMAK' =>		[qw(FI-Humps)],		# agreed with Hilla Mäkelä on Oct 6, 2016
#    'HY' =>		[qw(FI-H3 FI-Hb FI-Hc FI-HELKA FI-Hh FI-Hhant FI-Hhkki FI-Hhlitt FI-Hhmus FI-Hhsuo
#			    FI-Hhtai FI-Hhu38 FI-Hk FI-Hl FI-Hlham FI-Hlhlm FI-Hloik FI-Hmetm FI-Hmkti FI-Ho
#			    FI-Hq FI-Hs FI-Ht FI-Hul FI-Hv FI-Hxai)],
    'HY' =>		[qw(FI-Hul)],  		# agreed with Maria Kovero on Sep 27, 2016
#    'JAMK' =>		[qw(FI-Jadyn FI-Jakir FI-Jaluo FI-Jamus)],
    'JAMK' =>		[qw(FI-Jakir)], 	# agreed with Tuija Ylä-Sahra on Sep 19, 2016
#    'JY' =>		[qw(FI-J FI-Jmus FI-Jx)],
    'JY' =>		[qw(FI-J)],		# agreed with Hannu Markkanen on Sep 22, 2016
    'KAJAK' =>		[qw(FI-Kamk)],
#    'KPAMK' =>		[qw(FI-Kphum FI-Kpkk FI-Kptes)],
    'KPAMK' =>		[qw(FI-Kpkk)],		# agreed with Päivi Toikkanen on Oct 12, 2016
    'KTAMK' =>		[qw(FI-Ktah FI-Ktai FI-Ktao FI-Ktat)],
#    'KUVA' =>		[qw(FI-Tx FI-ARSCA)],    # BTW, KUVA is obsolete, SIBA is used for KUVA and TEAK
    'KUVA' =>		[qw(FI-Tx FI-Sib FI-SibK FI-Teat)],    # Agreed with Erkki Huttunen on Sep 8, 2016
#    'KYAMK' =>		[qw(Fi-Kymka FI-Kymme FI-Kymte FI-Xamk)],
    'KYAMK' =>		[qw(FI-Xamk)],		# agreed with Mia Kujala on Oct 7, 2016
    'LAUREA' =>		[qw(FI-Evahy FI-Evale FI-Evalo FI-Evalp FI-Evava FI-Laupo)],
    'LTY' =>		[qw(FI-L)],		# agreed with Pia Paavoseppä on Sep 22, 2016
    'LY' =>		[qw(FI-R)],
#    'MAMK' =>		[qw(FI-Mamk-M FI-Mamk-S FI-Xamk)],
    'MAMK' =>		[qw(FI-Xamk)],		# agreed with Mia Kujala on Oct 7, 2016
    'METROPOLIA' =>	[qw(FI-Metag FI-Metbu FI-Metha FI-Metko FI-Metle FI-Metmy FI-Meton FI-Metpo
       			    FI-Metso FI-Metti FI-Mettu FI-Metvi)],
    'OAMK' =>		[qw(FI-Oakau FI-Oamok FI-Oaout FI-Oasot FI-Oatek)],
    'OY' =>		[qw(FI-Oakau FI-Ol)],
#    'PHKK' =>		[qw(FI-Lamk FI-Lakk(?) FI-Phfa FI-Phft FI-Phhe FI-Phmi FI-Phnt FI-Phot
#			    FI-Phpa FI-Phpyk FI-Phso FI-Phst)],
    'PHKK' =>		[qw(FI-Lamk)], 		# agreed with Pertti Föhr on Nov 16, 2016
    'PKAMK' =>		[qw(FI-Kareli)],
    'RAMK' =>		[qw(FI-Rkaup FI-Rm FI-Rteku FI-Rteso)],
#    'SAMK' =>		[qw(FI-Samk0 FI-Samk1 FI-Samk2 FI-Samk4 FI-Samk5 FI-Samk6 FI-Samk8 FI-Samk9 FI-Ttp)],
    'SAMK' =>		[qw(FI-Samk5)],		# agreed with Harri Salminen on Sep 30, 2016
    'SAVONIA' =>	[qw(FI-Pssti FI-Psstk FI-Pstek FI-Pstew)],
#    'SEAMK' =>		[qw(FI-Sekor FI-Sekau FI-Sekäs FI-Semaa FI-Semet FI-Serav FI-Seter)],
    'SEAMK' =>		[qw(FI-Sekor)],		# agreed with Jarkko Meronen on Sep 22, 2016
    'SHH' =>		[qw(FI-Z)],		# agreed with Mattias Nordling on Oct 5, 2016
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
#    'TAY' =>		[qw(FI-Y FI-Yh FI-Yk FI-Yl FI-Yx)],
    'TAY' =>		[qw(FI-Y)],		# agreed with Timo Vuorisalmi on Sep 29, 2016
#    'TEAK' =>		[qw(FI-Teat FI-ARSCA)],  # BTW, TEAK is obsolete, SIBA is used for KUVA and TEAK
    'TEAK' =>		[qw(FI-Tx FI-Sib FI-SibK FI-Teat)],    # Agreed with Erkki Huttunen on Sep 8, 2016
#    'TKK' =>		[qw(FI-P FI-P-ETA FI-P-IL FI-P-KM FI-P-TFM FI-Aalto)],
    'TKK' =>		[qw(FI-Aalto)],		# agreed with Mari Aaltonen on Sep 23, 2016
#   'TTY' =>		[qw(FI-Tt FI-Ttk)],
    'TTY' =>		[qw(FI-Tt)],		# agreed with Ismo Raitanen on Nov 11, 2016
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
    }
};


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

NelliISIL -- map Metalib organisation ids to ISIL codes

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
