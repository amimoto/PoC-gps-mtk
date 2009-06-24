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
    shift @e; # get rid of the $
    for ( @e ) {
        $c ^= ord( $_ );
    }
    return sprintf '%02X', $c;
}

1;
