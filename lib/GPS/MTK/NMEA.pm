package GPS::MTK::NMEA;

use strict;
use bytes;

sub checksum {
# --------------------------------------------------
# Calculates the checksum of an NMEA string
#
    my ($self,$line) = @_;
    my $c = 0;
    my @e = split //, $line;
    for ( 1..@e-1 ) {
        $c ^= ord( $_ );
    }
    return sprintf '%02X', $c;
}

1;
