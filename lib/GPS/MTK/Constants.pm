package GPS::MTK::Constants;

# All the work related to the format of the bin dumps can be credited here:
#
# http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# Thanks to you guys I can actually use my GPS the way I wanted to!

use strict;
use bytes;
use Exporter;
use vars qw/
        $LOG_STORAGE_FORMAT_LOOKUP
        $DEBUG
        @ISA
        @EXPORT_OK
        %EXPORT_TAGS
    /;
@ISA = 'Exporter';

$DEBUG = 1;

use constant {

        PMTK182_PARAM_LOG_FORMAT          => 2,
        PMTK182_PARAM_REC_METHOD          => 3,
        PMTK182_PARAM_TIME_INTERVAL       => 3,
        PMTK182_PARAM_DISTANCE_INTERVAL   => 4,
        PMTK182_PARAM_SPEED_INTERVAL      => 5,
        PMTK182_PARAM_RECORDING_METHOD    => 6,
        PMTK182_PARAM_LOG_STATE           => 7,
        PMTK182_PARAM_MEMORY_USED         => 8,
        PMTK182_PARAM_POINTS_COUNT        => 10,

        LOG_BLOCK_SIZE                    => 0x10000,
        LOG_HEADER_INFO_SIZE              => 20,
        LOG_SECTOR_INFO_SIZE              => 32,
        LOG_HEADER_PADDING_SIZE           => 460,

        LOG_ENTRY_SEPARATOR_PREFIX        => chr(0xAA) x 7,
        LOG_ENTRY_SEPARATOR_PREFIX_LENGTH => length(chr(0xAA) x 7),
        LOG_ENTRY_SEPARATOR_SUFFIX        => chr(0xBB) x 4,
        LOG_ENTRY_SEPARATOR_SUFFIX_LENGTH => length(chr(0xBB) x 4),

        LOG_ENTRY_SEPARATOR_BITMASK       => 0x02,
        LOG_ENTRY_SEPARATOR_PERIOD        => 0x03,
        LOG_ENTRY_SEPARATOR_DISTANCE      => 0x04,
        LOG_ENTRY_SEPARATOR_SPEED         => 0x05,
        LOG_ENTRY_SEPARATOR_OVERWRITE     => 0x06,
        LOG_ENTRY_SEPARATOR_POWERCYCLE    => 0x07,

        LOG_STORAGE_FORMAT                => do {
                                                my $list = [
                                                    [ UTC  => 'L' ],
                                                    [ VALID  => 'S' ],
                                                    [ LATITUDE  => 'd' ],
                                                    [ LONGITUDE  => 'd' ],
                                                    [ HEIGHT  => 'f' ],
                                                    [ SPEED  => 'f' ],
                                                    [ HEADING  => 'f' ],
                                                    [ DSTA  => 'f' ],
                                                    [ DAGE  => 'L' ],
                                                    [ PDOP  => 'S' ],
                                                    [ HDOP  => 'S' ],
                                                    [ VDOP  => 'S' ],
                                                    [ NSAT  => 'CC' ],
                                                    [ SID  => 'C' ],
                                                    [ ELEVATION  => 'S' ],
                                                    [ AZIMUTH  => 'S' ],
                                                    [ SNR  => 'S' ],
                                                    [ RCR  => 'S' ],
                                                    [ MILISECOND  => 'S' ],
                                                    [ DISTANCE  => 'd' ],
                                                    [ LOGVALIDONLY => 's' ],
                                                ];
                                                my $i = 0;
                                                my $fmt = {
                                                    map {;
                                                        $_->[0] => {
                                                            format   => $_->[1],
                                                            bit_mask => 2**$i,
                                                            order    => $i++,
                                                            numbytes => length(pack $_->[1]),
                                                        },
                                                    } @$list
                                                };

                                                $fmt;
                                            },
    };

use constant {
        LOG_STORAGE_FORMAT_KEYS => [ sort {LOG_STORAGE_FORMAT()->{$a}{order} <=> LOG_STORAGE_FORMAT()->{$b}{order}} keys %{LOG_STORAGE_FORMAT()} ],
    };

@EXPORT_OK = qw(

    PMTK182_PARAM_LOG_FORMAT
    PMTK182_PARAM_REC_METHOD
    PMTK182_PARAM_TIME_INTERVAL
    PMTK182_PARAM_DISTANCE_INTERVAL
    PMTK182_PARAM_SPEED_INTERVAL
    PMTK182_PARAM_RECORDING_METHOD
    PMTK182_PARAM_LOG_STATE
    PMTK182_PARAM_MEMORY_USED
    PMTK182_PARAM_POINTS_COUNT

    LOG_BLOCK_SIZE
    LOG_HEADER_INFO_SIZE
    LOG_SECTOR_INFO_SIZE
    LOG_HEADER_PADDING_SIZE

    LOG_ENTRY_SEPARATOR_PREFIX
    LOG_ENTRY_SEPARATOR_PREFIX_LENGTH
    LOG_ENTRY_SEPARATOR_SUFFIX
    LOG_ENTRY_SEPARATOR_SUFFIX_LENGTH

    LOG_ENTRY_SEPARATOR_BITMASK
    LOG_ENTRY_SEPARATOR_PERIOD
    LOG_ENTRY_SEPARATOR_DISTANCE
    LOG_ENTRY_SEPARATOR_SPEED
    LOG_ENTRY_SEPARATOR_OVERWRITE
    LOG_ENTRY_SEPARATOR_POWERCYCLE

    LOG_STORAGE_FORMAT
    LOG_STORAGE_FORMAT_KEYS

    $LOG_STORAGE_FORMAT_LOOKUP
    $DEBUG
);
%EXPORT_TAGS = ( all => \@EXPORT_OK );

###################################################
# Initialization routines for various values/constants
###################################################

my $i = 0;
for my $k ( @{&LOG_STORAGE_FORMAT_KEYS} ) {
    $LOG_STORAGE_FORMAT_LOOKUP->{$k} = 2**$i;
    $i++;
};


1;
