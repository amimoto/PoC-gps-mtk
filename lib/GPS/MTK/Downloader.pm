package GPS::MTK::Downloader;

use strict;
use bytes;
use GPS::MTK::Constants qw/ :all /;

sub download {
# --------------------------------------------------
    my ( $self, $port ) = @_;
}

sub main {
# --------------------------------------------------
    $F = Symbol::gensym();
    open $F, "+<", "/dev/rfcomm4" or die $!;

# Wait till we get a reading on something
    packet_wait('GPGSV');

# Preamble
    my @preamble = (
        'PMTK182,2,9,9F',
        'PTSI000,TSI', 
        'PMTK182,2,3',
        'PMTK182,2,4',
        'PMTK182,2,5',
        'PMTK182,2,6',
        'PMTK182,2,7',
    );
    for my $s ( @preamble ) {
        packet_send($s);
    }

# What type of device is it?
    my $d = packet_send_wait('PMTK605','PMTK705');
    $d->[3] eq 'QST1300' or warn "Only tested with a QST1300";

# How much memory are we pigging
    $d = packet_send_wait('PMTK182,2,8','PMTK182,3,8');
    my $gps_mem = hex($d->[3]);

# How many points have we got registered?
    $d = packet_send_wait('PMTK182,2,10','PMTK182,3,10');
    my $gps_points = hex($d->[3]);

# Turn logging off
    packet_send('PMTK182,5');

# Request data
    my $mem_index = 0;
    my $mem_chunk = '10000';
    my $data_buffer = '';
    my $fh_o = Symbol::gensym();
    open $fh_o, ">output.bin";
    binmode $fh_o;

    while ( $mem_index < $gps_mem ) {
        packet_send(sprintf("PMTK182,7,%x,%s",$mem_index,$mem_chunk));
        while ( my $l = packet_read() ) {
            $d = packet_elements($l);

# PMTK001,182,5,3 appears to be "start"
# PMTK001,182,7,3 appears to be "end"
            if ( $d->[0] eq 'PMTK001' ) {
                if ( $d->[2] eq '7' ) {
                    $mem_index = length($data_buffer);
                    last;
                }
            }

# PMTK182,8,00000000,6F... appears to be actual data
#         offets:
#                1 - code identifying data
#                2 - offset off base of the first byte
#                3 - the actual data
            elsif ( $d->[0] eq 'PMTK182' ) {
                my $buf = pack "H*", $d->[3];
                print $fh_o $buf;
                $data_buffer .= $buf;
            }

        }
    }

    close $fh_o;
    close $F;
}

sub packet_send {
# --------------------------------------------------
    my $key = shift;
}

sub packet_elements {
# --------------------------------------------------
    my $l = shift;
    my $a = [split /,/, $l];
    return $a;
}

sub packet_wait {
# --------------------------------------------------
    my ( $key ) = @_;
    while ( my $l = packet_read() ) {
        if ( $l =~ /^$key/ ) {
            return $l;
        }
    };
}

sub packet_read {
# --------------------------------------------------
    my $l = <$F>;
    $l =~ s/\n|\r//g;
    $l =~ s/\*[\da-f]+$//gi;
    $l =~ s/^\$//g;
    $DEBUG and print "> [$l]\n";
    return $l;
}

sub packet_send_wait {
# --------------------------------------------------
    my ( $pkt, $key ) = @_;
    packet_send($pkt);
    my $l = packet_wait($key);
    my $a = packet_elements($l);
    return $a;
}

# FROM MTK BABEL

#-------------------------------------------------------------------------
# Send NMEA packet to the device.
#-------------------------------------------------------------------------
sub packet_send {

    my $pkt = shift;
    my $n;

    # Add the checksum to the packet.
    $pkt = $pkt . '*' . sprintf('%02X', packet_checksum($pkt));

    # Add the preamble and <CR><LF>.
    $DEBUG and print "< {\$$pkt}\n";
    $pkt = '$' . $pkt . "\r\n";

    print $F $pkt;
}
#-------------------------------------------------------------------------
# Calculate the packet checksum: bitwise XOR of string's bytes.
#-------------------------------------------------------------------------
sub packet_checksum {

    my $pkt   = shift;
    my $len   = length($pkt);
    my $check = 0;
    my $i;

    for ($i = 0; $i < $len; $i++) { $check ^= ord(substr($pkt, $i, 1)); }
    #printf("0x%02X\n", $check);
    return($check);
}



1;
