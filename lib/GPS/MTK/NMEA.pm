package GPS::MTK::NMEA;

use strict;
use bytes;

sub checksum {
# --------------------------------------------------
# Calculates the checksum of an NMEA string
#
    my ($self,$line) = @_;
    my $c = 0;
    $line =~ s/^\$//;
    my @e = split //, $line;
    for ( @e ) {
        $c ^= ord( $_ );
    }
    return sprintf '%02X', $c;
}

sub dms_to_decimal {
# --------------------------------------------------
    my ( $self, $dms, $direction ) = @_;
    my $dms_str = sprintf( "%05.05f", $dms );
    my ( $d, $m, $s ) = $dms_str =~ /(\d+)(\d\d)\.(\d+)/;
    my $seconds = $m * 60 + $s / 1000;
    my $degrees = $d + $seconds / 3600;
    if ( $direction eq 'W' or $direction eq 'S' ) {
       $degrees *= -1;
    }
    return sprintf("%.05f",$degrees);
}

1;
