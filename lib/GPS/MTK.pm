package GPS::MTK;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Driver based handling of IO and parsing
        io_class         => 'GPS::MTK::IO',
        downloader_class => 'GPS::MTK::Downloader',
        parser_class     => 'GPS::MTK::Parser',
        event_class      => 'GPS::MTK::Event',

# Basic configuration
        io_timeout       => 4,
        io_send_reattempts => 3,

# Some internal variables to track state
        gps_state        => {
            time_current => undef, # in localtime format
            data_status  => undef,
            latitude     => undef,
            longitude    => undef,
        },

# The files users will generally be paying with
        comm_port_fpath  => '',
        track_dump_fpath => '',
        log_dump_fpath   => '',

# This key will never be used. This is entirely for you to mess with
        my_data          => {},

    };


####################################################
# The core interface functions
####################################################

sub gps_info {
# --------------------------------------------------
# Queries the GPS for its hardware implementation
# information
#
    my ( $self ) = @_;

# clear out any pending data
    $self->loop; 

# Figure out what type of device this is
    $self->gps_send_wait( 'PMTK605', [], 'PMTK705', sub {
            my ($line,$self,$code,$elements) = @_;
            my $gps_info = $self->{gps_state}{gps_info} ||= {};
            $gps_info->{firmware} = shift @$elements;
            $gps_info->{model_id} = shift @$elements;
            $gps_info->{device} = join " ", @$elements;
        } );

    use Data::Dumper; die Dumper $self;
}

sub loop {
# --------------------------------------------------
# Just iterate and keep downloading NMEA strings
# from the GPS unit
#
    my ( $self, $blocking ) = @_;
    my $opts = {@_};
    my $io_obj    = $opts->{io_obj}    ||= $self->io_obj or return;
    my $event_obj = $opts->{event_obj} ||= $self->event_obj or return;
    my $line;

    FETCH_DATA: {
        $io_obj->blocking($blocking);
        do {
            $line = $io_obj->getline();
            $line =~ s/[\n\r]*$//;

# If there is an event, we just send it to the event 
# engine as required.
            if ( $line ) {
                $self->nmea_string_log($line);
                $event_obj->event($line,$self);
            }
            elsif ( not $blocking ) {
                last;
            }

        } while ( defined $line );
    };

    return;
}

sub gps_send {
# --------------------------------------------------
# sends a single query to the GPS
#
    my ( $self, $code, $elements ) = @_;
    require GPS::MTK::NMEA;
    my $base_string = join ",", uc($code), @$elements;
    my $checksum    = GPS::MTK::NMEA->checksum($base_string);
    my $nmea_string = '$' . $base_string . "*$checksum\r\n";
    my $io_obj      = $self->io_obj or return;
    return $io_obj->printflush($nmea_string);
}

sub gps_wait {
# --------------------------------------------------
# This will block until the requested code is found
#
    my ( $self, $code_wait ) = @_;

    my $io_obj    = $self->io_obj or return;
    my $event_obj = $self->event_obj or return;
    $code_wait    = uc($code_wait);
    my $line;

    $io_obj->blocking(1);
    while (1) {
        $line = $io_obj->getline();
        defined $line or last;
        $line =~ s/[\n\r]*$//;
        $line or next;

# If there is an event, we just send it to the event 
# engine as required.
        $self->nmea_string_log($line);
        $event_obj->event($line,$self);

# Now check to see if the event matches our wait code
        my @e = split /,/, $line;
        my $code = shift @e;
        $code =~ s/^\$//;
        if ( $code eq $code_wait ) {
            last;
        };
    };

    return 1;
}

sub gps_send_wait {
# --------------------------------------------------
# This will send a string to the GPS then wait for 
# for a particular code and trigger the appropriate
# callback if defined
#
    my ( $self, $code, $elements, $code_wait, $callback ) = @_;
    my $event_obj = $self->event_obj or return;
    $self->gps_send( $code, $elements );
    $callback and $event_obj->hook_register( $code_wait, $callback );
    $self->gps_wait($code_wait);
    warn "FINISHED WAIT\n";
    $callback and $event_obj->hook_unregister( $code_wait );
    return 1;
}

sub config {
# --------------------------------------------------
# Returns the current configuration parameters for
# the device
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $downloader = $self->download_obj;
    my $download   = $downloader->download($opts);
    return $download;
}

sub download {
# --------------------------------------------------
# Downloads the device's current memory
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $downloader = $self->download_obj;
    my $download   = $downloader->download($opts);
    return $download;
}

sub parse {
# --------------------------------------------------
# Parses the device's dumped data file
#
    my $self = shift;
    my $opts = {@_};
    $opts->{io_obj} ||= $self->io_obj;
    my $parseer = $self->parse_obj;
    my $parse   = $parseer->parse($opts);
    return $parse;
}

####################################################
# Object instantiation code
####################################################

sub io_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{io_obj} ||= do {
        my $io_class = $self->{io_class};
        return unless $io_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $io_class";
        my $io_obj = $io_class->new({ comm_port_fpath => $self->{comm_port_fpath} });
        $io_obj->connect;
        $io_obj;
    };
}

sub download_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{download_obj} ||= do {
        my $download_class = $self->{download_class};
        return unless $download_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $download_class";
        my $download_obj = $download_class->new;
        $download_obj;
    };
}


sub parser_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{parser_obj} ||= do {
        my $parser_class = $self->{parser_class};
        return unless $parser_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $parser_class";
        my $parser_obj = $parser_class->new;
        $parser_obj;
    };
}

sub event_obj {
# --------------------------------------------------
    my $self = shift;
    return $self->{event_obj} ||= do {
# Need to load the class. Okedoke
        my $event_class = $self->{event_class};
        return unless $event_class =~ /^\w+(?:::\w+)*$/; # TODO ERROR MESSAGE
        eval "require $event_class";
        $@ and die "Could not compile $event_class because '$@'";
        my $event_obj = $event_class->new;

# Rack our event handlers
        $event_obj->hook_register('_default',\&_event_default);
        $event_obj->hook_register('_error',\&_event_error);
        $event_obj->hook_register('gprmc',\&_event_gps_gprmc);
        $event_obj->hook_register('gpgga',\&_event_gps_gpgga);
        $event_obj->hook_register('gpgsa',\&_event_gps_gpgsa);
        $event_obj->hook_register('gpgsv',\&_event_gps_gpgsv);

        $event_obj;
    };
}

sub _event_default {
# --------------------------------------------------
# The default event handler
#
    my ($line,$cb_args,$code,$elements) = @_;
    print "$code => [$line]\n";
}

sub _event_error {
# --------------------------------------------------
# Default error handler
#
    my ($line,$cb_args,$error_msg) = @_;
    warn "$line\n    - $error_msg\n";
}

# Lots of data on how nmea strings work here:
#
# http://aprs.gids.nl/nmea/
#

sub _event_gps_gprmc {
# --------------------------------------------------
# GPRMC  Recommended minimum specific GPS/Transit data
#
# $GPRMC,hhmmss.ss,A,llll.ll,a,yyyyy.yy,a,x.x,x.x,ddmmyy,x.x,a*hh
# 1    = UTC of position fix
# 2    = Data status (V=navigation receiver warning)
# 3    = Latitude of fix
# 4    = N or S
# 5    = Longitude of fix
# 6    = E or W
# 7    = Speed over ground in knots
# 8    = Track made good in degrees True
# 9    = UT date
# 10   = Magnetic variation degrees (Easterly var. subtracts from true course)
# 11   = E or W
# 12   = Checksum
# 
    my ($line,$self,$code,$elements) = @_;

# Handle the date
    my @utc_time = reverse $elements->[0] =~ /(\d\d)(\d\d)(\d\d(?:\.\d+)?)/;
    push @utc_time, $elements->[8] =~ /(\d\d)(\d\d)(\d\d)/;
    $utc_time[5] += $utc_time[5] > 70 ? 1900 : 2000;

    require GPS::MTK::NMEA;
    my $gps_state_new = {
        time_current    => \@utc_time,
        data_status     => $elements->[1],
        latitude        => GPS::MTK::NMEA->dms_to_decimal( $elements->[2], $elements->[3] ),
        longitude       => GPS::MTK::NMEA->dms_to_decimal( $elements->[4], $elements->[5] ),
        speed           => $elements->[6],
        track_made_good => $elements->[7],
    };
    my $gps_state = $self->{gps_state};
    @$gps_state{keys %$gps_state_new} = values %$gps_state_new;

    return;
}

sub _event_gps_gpgga {
# --------------------------------------------------
# Global Positioning System Fix Data
#
#  $GPGGA,hhmmss.ss,llll.ll,a,yyyyy.yy,a,x,xx,x.x,x.x,M,x.x,M,x.x,xxxx*hh
#  1    = UTC of Position
#  2    = Latitude
#  3    = N or S
#  4    = Longitude
#  5    = E or W
#  6    = GPS quality indicator (0=invalid; 1=GPS fix; 2=Diff. GPS fix)
#  7    = Number of satellites in use [not those in view]
#  8    = Horizontal dilution of position
#  9    = Antenna altitude above/below mean sea level (geoid)
#  10   = Meters  (Antenna height unit)
#  11   = Geoidal separation (Diff. between WGS-84 earth ellipsoid and
#         mean sea level.  -=geoid is below WGS-84 ellipsoid)
#  12   = Meters  (Units of geoidal separation)
#  13   = Age in seconds since last update from diff. reference station
#  14   = Diff. reference station ID#
#  15   = Checksum
#
    my ($line,$self,$code,$elements) = @_;

    require GPS::MTK::NMEA;
    my $gps_state_new = {
        latitude     => GPS::MTK::NMEA->dms_to_decimal( $elements->[1], $elements->[2] ),
        longitude    => GPS::MTK::NMEA->dms_to_decimal( $elements->[3], $elements->[4] ),
        gps_quality  => $elements->[5],
        sats_used    => $elements->[6],
        hdop         => $elements->[7],

# FIXME
# Huh? to the rest of 'em

    };
    my $gps_state = $self->{gps_state};
    @$gps_state{keys %$gps_state_new} = values %$gps_state_new;

    return;
}

sub _event_gps_gpgsa {
# --------------------------------------------------
# 1    = Mode:
#        M=Manual, forced to operate in 2D or 3D
#        A=Automatic, 3D/2D
# 2    = Mode:
#        1=Fix not available
#        2=2D
#        3=3D
# 3-14 = IDs of SVs used in position fix (null for unused fields)
# 15   = PDOP
# 16   = HDOP
# 17   = VDOP
# 
    my ($line,$self,$code,$elements) = @_;

    my $gps_state_new = {
        fix_mode => $elements->[0],
        fix_type => $elements->[1],
        sv_used  => [ grep $_, @$elements[2..13] ],
        pdop     => $elements->[14],
        hdop     => $elements->[15],
        pdop     => $elements->[16],
    };
    my $gps_state = $self->{gps_state};
    @$gps_state{keys %$gps_state_new} = values %$gps_state_new;

    return;
}

sub _event_gps_gpgsv {
# --------------------------------------------------
# $GPGSV,<1>,<2>,<3>,<4>,<5>,<6>,<7>,...<4>,<5>,<6>,<7>*hh
# 1) Total number of GSV sentences to be transmitted
# 2) Number of current GSV sentence
# 3) Total number of satellites in view, 00 to 12 (leading zeros sent)
# 4) Satellite PRN number, 01 to 32 (leading zeros sent)
# 5) Satellite elevation, 00 to 90 degrees (leading zeros sent)
# 6) Satellite azimuth, 000 to 359 degrees, true (leading zeros sent)
# 7) Signal to Noise ratio (C/No) 00 to 99 dB, null when not tracking (leading zeros sent)
#
    my ($line,$self,$code,$elements) = @_;

    require GPS::MTK::NMEA;
    my $gps_state = $self->{gps_state};
    my $sv_id = $elements->[3];
    $gps_state->{sv}{$sv_id} = {
        prn          => $sv_id,
        elevation    => $elements->[4],
        azimuth      => $elements->[5],
        signal_noise => $elements->[6],
    };

    my $gps_state_new = {
        sv_visible => $elements->[2]
    };
    @$gps_state{keys %$gps_state_new} = values %$gps_state_new;

    return;
}

sub nmea_string_log {
# --------------------------------------------------
# Log a single NMEA string to the output file
#
    my ( $self, $line ) = @_;
    return unless $self->{log_dump_fpath};
    require Symbol;
    my $fh = Symbol::gensym();
    open $fh, ">>$self->{log_dump_fpath}";
    print $fh "$line\n";
    close $fh;
}


1;
