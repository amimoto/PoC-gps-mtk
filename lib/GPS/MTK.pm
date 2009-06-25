package GPS::MTK;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {

# Driver based handling of IO and parsing
        io_class         => 'GPS::MTK::IO',
        downloader_class => 'GPS::MTK::Downloader',
        parser_class     => 'GPS::MTK::Parser',
        event_class      => 'GPS::MTK::Event',

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

            use Data::Dumper; warn Dumper $self->{gps_state};

        } while ( defined $line );
    };

    return;
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

        $event_obj;
    };
}

sub _event_default {
# --------------------------------------------------
# The default event handler
#
    my ($line,$cb_args,$code,$elements) = @_;
    print "[$line]\n";
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
    my $location_new = {
        time_current => \@utc_time,
        data_status  => $elements->[1],
        latitude     => GPS::MTK::NMEA->dms_to_decimal( $elements->[2], $elements->[3] ),
        longitude    => GPS::MTK::NMEA->dms_to_decimal( $elements->[4], $elements->[5] ),
        speed        => $elements->[7],
        track        => $elements->[8],
    };
    my $gps_state = $self->{gps_state};
    @$gps_state{keys %$location_new} = values %$location_new;

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
    my $location_new = {
        latitude     => GPS::MTK::NMEA->dms_to_decimal( $elements->[1], $elements->[2] ),
        longitude    => GPS::MTK::NMEA->dms_to_decimal( $elements->[3], $elements->[4] ),
        gps_quality  => $elements->[5],
        sats_used    => $elements->[6],
        hdop         => $elements->[7],

# FIXME
# Huh? to the rest of 'em

    };
    my $gps_state = $self->{gps_state};
    @$gps_state{keys %$location_new} = values %$location_new;

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
