package GPS::MTK::Event;

use strict;
use GPS::MTK::NMEA;
use GPS::MTK::Constants qw/:all/;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        event_hooks => {
            _default => undef, 
            _error   => undef, 

            gprmc    => undef, 
            gpgga    => undef, 
            gpgsa    => undef, 
            gpgsv    => undef, 

            pmtk001  => undef, 
            pmtk182  => undef, 
            pmtk705  => undef, 

        },
    };

sub init_instance_attribs {
# --------------------------------------------------
    my $self = shift;

# Rack our default hooks
    $self->hook_register( _default => \&_event_default );
    $self->hook_register( _error   => \&_event_error );
    $self->hook_register( gprmc    => \&_event_gps_gprmc );
    $self->hook_register( gpgga    => \&_event_gps_gpgga );
    $self->hook_register( gpgsa    => \&_event_gps_gpgsa );
    $self->hook_register( gpgsv    => \&_event_gps_gpgsv );
    $self->hook_register( pmtk001  => \&_event_gps_pmtk001 );
    $self->hook_register( pmtk182  => \&_event_gps_pmtk182 );
    $self->hook_register( pmtk705  => \&_event_gps_pmtk705 );

    return $self->SUPER::init_instance_attribs (@_);
}

sub event {
# --------------------------------------------------
# Triggers a single event based upon the NMEA
# string
#
    my ( $self, $line, $cb_args ) = @_;

# Trim, ensure we have something to work with then arguments are actually
# comma delimited
    $line =~ s/^\s*|\s*$//g;
    return unless $line;

# Handle the checksum
    my $checksum_str = $line;
    $checksum_str  =~ s/\*([0-9a-f]{2})$//i or return $self->event_error($line,$cb_args,"NOCHECKSUM");
    my $checksum = $1;
    my @e = split /,/, $checksum_str;

# Now handle the event code
    my $code = shift @e;
    return $self->event_error($line,$cb_args,"NOTNMEA") unless $code and $code =~ s/^\$//;

    my $checksum_calc = GPS::MTK::NMEA->checksum($checksum_str);
    if ( $checksum_calc ne $checksum ) {
        $self->event_error($line,$cb_args,"CHECKSUMFAIL : $checksum_calc vs $checksum");
    }

# Not an error, we hand off to the trigger event
    return $self->event_trigger($line,$code,\@e,$cb_args);
}

sub event_error {
# --------------------------------------------------
# Throw an error event if we can
#
    my ( $self, $line, $cb_args, $error_msg ) = @_;
    my $func = $self->hook_current('_error') or return;
    return $func->($line,$cb_args,$error_msg);
}

sub event_trigger {
# --------------------------------------------------
# This will send the event to the proper handler as required
#
    my ( $self, $line, $code, $elements, $cb_args ) = @_;
    my $events = $self->{events};
    $code = lc $code;
    my $func = $self->hook_current($code) || $self->hook_current('_default');
    return unless $func;
    return $func->($line,$cb_args,$code,$elements);
}

sub hook_current {
# --------------------------------------------------
# This will return the currently active hook function
# for the hook code requested
#
    my ( $self, $code ) = @_;
    my $hooks = $self->{events}{lc $code};
    $hooks and @$hooks or return;
    return $hooks->[-1];
};

sub hook_register {
# --------------------------------------------------
# This will register a single hook on the event queue
# for a particular type of event
#
    my ( $self, $code, $callback ) = @_;
    push @{$self->{events}{lc $code}||=[]}, $callback;
}

sub hook_unregister {
# --------------------------------------------------
# This will remove a single hook on the event queue
# for a particular type of event. Basically, it will
# take events off the list and cause the "default"
# handler to be triggered when this event comes up
# again.
#
    my ( $self, $code ) = @_;
    pop @{$self->{events}{lc $code}};
}

################################################### 
# !!! These following functions expect the 
# GPS::MTK object to be passed through as the
# callback argument
################################################### 

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
    my $sv_id = $elements->[3] or return;
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

sub _event_gps_pmtk001 {
# --------------------------------------------------
# This is a particularly loaded response string since
# it has many many sub commands. For more info, have a 
# look at:
#
# http://spreadsheets.google.com/ccc?key=pyCLH-0TdNe-5N-5tBokuOA
#
    my ($line,$self,$code,$elements) = @_;
    my $sc = $elements->[1]; # sc = subcommand
}

sub _event_gps_pmtk182 {
# --------------------------------------------------
# This is a particularly loaded response string since
# it has many many sub commands. For more info, have a 
# look at:
#
# http://spreadsheets.google.com/ccc?key=pyCLH-0TdNe-5N-5tBokuOA
#
    my ($line,$self,$code,$elements) = @_;
    my $sc = $elements->[0]; # sc = subcommand

# subcommand 3 is for responses to previous pmtk
# requests for information
    if ( 3 == $sc ) {
        return _event_gps_pmtk182_subcomm3(@_);
    }

# subcommand 8 is for responses that hold log data
# in hex format. 
    elsif ( 8 == $sc ) {

# PMTK182,8,00000000,6F... appears to be actual data
#         offets:
#                1 - code identifying data
#                2 - offset off base of the first byte
#                3 - the actual data

# FIXME: make sure we handle the offset. Currently it merely
# appends.
        my $chunk_offset = hex( $elements->[1] );
        my $chunk        = pack "H*", $elements->[2];
        my $chunk_size   = length $chunk;

        $self->{gps_state}{log_data_chunks} = [ $chunk_offset, $chunk_size, $chunk ];
    }
}

sub _event_gps_pmtk182_subcomm3 {
# --------------------------------------------------
# Handle the response to a device parameter request
#
    my ($line,$self,$code,$elements) = @_;

    my $cmd_type = $elements->[1];
    my $gps_info = $self->{gps_state}{gps_info} ||= {};

    if ( PMTK182_PARAM_LOG_FORMAT == $cmd_type ) {
        my $log_format = $gps_info->{log_format} = $elements->[2];
        $gps_info->{log_format_entries} = GPS::MTK::NMEA->log_format_parse($log_format);
    }

    elsif ( PMTK182_PARAM_REC_METHOD == $cmd_type ) {
        $gps_info->{rec_method} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_TIME_INTERVAL == $cmd_type ) {
        $gps_info->{time_interval} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_DISTANCE_INTERVAL == $cmd_type ) {
        $gps_info->{distance_interval} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_SPEED_INTERVAL == $cmd_type ) {
        $gps_info->{speed_interval} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_RECORDING_METHOD == $cmd_type ) {
        $gps_info->{recording_method} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_LOG_STATE == $cmd_type ) {
        $gps_info->{log_state} = $elements->[2];
    }

    elsif ( PMTK182_PARAM_MEMORY_USED == $cmd_type ) {
        $gps_info->{memory_used} = hex($elements->[2]);
    }

    elsif ( PMTK182_PARAM_POINTS_COUNT == $cmd_type ) {
        $gps_info->{points_count} = hex($elements->[2]);
    }
}

sub _event_gps_pmtk705 {
# --------------------------------------------------
# This is a particularly loaded response string since
# it has many many sub commands. For more info, have a 
# look at:
#
# http://spreadsheets.google.com/ccc?key=pyCLH-0TdNe-5N-5tBokuOA
#
    my ($line,$self,$code,$elements) = @_;
    my $gps_info = $self->{gps_state}{gps_info} ||= {};

    $gps_info->{firmware} = shift @$elements;
    $gps_info->{model_id} = shift @$elements;
    $gps_info->{device} = join " ", @$elements;

    return;
}

1;
