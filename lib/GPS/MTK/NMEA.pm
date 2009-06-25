package GPS::MTK::NMEA;

use strict;
use bytes;
use GPS::MTK::Constants qw/:all/;

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

sub log_format_parse {
# --------------------------------------------------
# Returns an array of what log elements are in
# each record
#
    my ( $self, $log_format ) = @_;

    my $i = 0;
    my @log_elements;
    for my $k ( @{LOG_STORAGE_FORMAT_KEYS()} ){
        if ( $log_format & 2**($i++) ) {
            push @log_elements, $k;
        }
    }

    return \@log_elements;
}


1;
