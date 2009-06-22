package GPS::MTK::Parser;

use strict;
use bytes;
use Symbol;
use GPS::MTK;
use GPS::MTK::Constants qw/:all/;

###################################################
# Main code follows
###################################################

sub parse {
# --------------------------------------------------
    my $self = shift;
    my $fpath = shift or die "No data file provided!";
    -f $fpath or die "Require path to data file";

# Get a fix on the data file
    my $fh = Symbol::gensym();
    open $fh, "<$fpath";
    my $fh_size = -s $fpath;

# Go in block chunks
    my $fh_read = 0;
    while ( $fh_read < $fh_size ) {

# Load a block in
        read $fh, my $block_buf, LOG_BLOCK_SIZE;
        my $b_i    = 0;

# Parse out the header
        my $header_info_buf = substr $block_buf, $b_i, LOG_HEADER_INFO_SIZE; $b_i += LOG_HEADER_INFO_SIZE;
        my $header_info = $self->log_parse_header( $header_info_buf );

# Sector status we don't know how to handle so this is just a stub.
        my $sector_info_buf = substr $block_buf, $b_i, LOG_SECTOR_INFO_SIZE; $b_i += LOG_SECTOR_INFO_SIZE;
        my $sector_info = $self->log_parse_sector( $sector_info_buf );

# Handle the padding. We really don't need any information from here
        my $padding     = substr $block_buf, $b_i, LOG_HEADER_PADDING_SIZE; $b_i += LOG_HEADER_PADDING_SIZE;

# At this point, we can trim the fat from the end of this buffer. While each block is 0x10000 
# bytes long, the unused portions are merely blanked out with 0xFF. We need to find out
# where that ends.
        my $block_buf_len = length($block_buf);
        while ($block_buf_len) {
            unless ( ord(substr($block_buf,$block_buf_len-1,1)) == 0xff ) {
                last;
            };
            $block_buf_len--;
        }

# Now we can handle the data from the header. The log chunk can be
# either a single point or a record of a log attribute being changed.
        while ( $b_i < $block_buf_len ) {
            if ( my $entry_separator = $self->log_parse_entry_separator(\$block_buf,\$b_i,$header_info) ) {
                $self->log_separator_handler($entry_separator,$header_info);
            }
            else {
                my $entry_info = $self->log_parse_entry(\$block_buf,\$b_i,$header_info);
                $self->log_entry_handler($entry_info,$header_info);
            }
        }

# Setup for next chunk
        $fh_read += LOG_BLOCK_SIZE;
    }

    close $fh;
}

###################################################
# Log handler hooks
###################################################

sub log_separator_handler {
# --------------------------------------------------
    my ( $self, $entry_separator, $header_info ) = @_;
    print "------------- Seperator ----\n";
}

sub log_entry_handler {
# --------------------------------------------------
    my ( $self, $entry_info, $header_info ) = @_;

    printf "%s,%0.05f,%0.05f\n", "".gmtime($entry_info->{utc}), @$entry_info{qw(latitude longitude)};
}

###################################################
# Log parser code
###################################################

sub log_parse_header {
# --------------------------------------------------
# From: http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# Log info consist of 20 bytes, the log count is FFFF until 
# the entire 64kByte block has been filled. It will then represent 
# the number of log items in this block.
#
# 0    1        2    3    4    5    6    7
# FFFF BBBBBBBB MMMM PPPP 0000 DDDD 0000 SSSS 0000
# FFFF     -- log count, updated when entire 64kB block full.
# BBBBBBBB -- log format - LSB is first. In my case (reordered): 0x0020003F
# MMMM     -- Mode - 0401 --- ??? / also 0601 (second block in my case: what setting 
#                                           could that be? May be to indicate if the 
#                                           log period/distance/speed is active! 
#                                           (default=1s, my case: distance too)
# PPPP     -- Log period in 10:ths of seconds
# DDDD     -- Log distance in 10:ths of meters
# SSSS     -- Log speed in 10:ths of km/h
# 
    my ( $self, $header_buf ) = @_;

    my @h = unpack( "SLS*", $header_buf );
    my $header_info = {
        log_count    => $h[0],
        log_format   => $h[1],
        log_mode     => $h[2],
        log_period   => $h[3]/10,
        log_distance => $h[5]/10,
        log_speed    => $h[7]/10,
    };

# What's the log format look like?
    $header_info->{log_format_elements} = $self->log_parse_format($header_info->{log_format   });

    return $header_info;
}

sub log_parse_format {
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

sub log_parse_sector {
# --------------------------------------------------
# Stub.
#
    my $self = shift;
    return shift;
}

sub log_parse_entry {
# --------------------------------------------------
# From: http://spreadsheets.google.com/pub?key=pyCLH-0TdNe-5N-5tBokuOA&gid=5
#
# utc_data ?!
# valid_data ?!
# latitude_data ?!
# longitude_data ?!
# height_data ?!
# speed_data ?!
# heading_data ?!
# dsta_data ?!
# dage_data ?!
# pdop_data ?!
# hdop_data ?!
# vdop_data ?!
# nsat_data ?!
# ( nosat_data
# | sat_data * ) ?!
# rcr_data ?!
# mili-second_data ?
# distance_data ?!
#
# This defines the order of the data logged. The '?' indicates that the 
# data is optional. The actual data logged depends on the settings of the 
# device at the moment of the log
# [A '!' after the '?' indicates that the position of this data in the 
# log has been confirmed.
# Some information concerning size catched on 
# http://pc11.2ch.net/test/read.cgi/mobile/1173306239
#
# If there is no satellite data and SID is being logged, then the number of sats will be set to 0 and there will be no ele, azi or snr data)
    my ( $self, $block_buf_ref, $b_i, $header_info ) = @_;

# Iterate through the header format now.
    my $fmt = LOG_STORAGE_FORMAT;
    my $entry_info = {};
    for my $type ( @{$header_info->{log_format_elements}} ) {
        my $type_data = $fmt->{$type};

# We handle NSAT information as an exception since it's of a variable length
        if ( $type eq 'NSAT' ) {
            die "NSAT";
        }

# We will handle the rest in standard format
        my $data_buf = substr $$block_buf_ref, $$b_i, $type_data->{numbytes};
        $entry_info->{lc $type} = unpack($type_data->{format},$data_buf);
        $$b_i += $type_data->{numbytes};
    }

# Then we get the trailing '*' and checksum
    my $star = substr $$block_buf_ref, $$b_i++, 1;
    my $checksum = substr $$block_buf_ref, $$b_i++, 1;

    return $entry_info;
}

sub log_parse_entry_separator {
# --------------------------------------------------
# Log separators look like:
#
# 0xAA AA AA AA AA AA AA
# 0xYY
# 0xXX XX XX XX
# 0xBB BB BB BB
#
# Switching the device on/off results in some synchronization ???
# The information record is 16 bytes long and contains a command (YY) 
# and an argument XXXXXXXX. The argument should be interpreted as a 
# word or long depending on the command byte. LSB is first byte of the 
# data XXXXXXXX. The following commands are known.
#
# 0x02 - Log bitmask change [long bitmask]
# 0x03 - Log period change [word period/10 sec]
# 0x04 - Log distance change [word distance/10 m]
# 0x05 - Log speed change [word speed/10 km/h]
# 0x06 - Log overwrite/log stop change - argument = same as log status (PMTK182,2,7 response)
# 0x07 - Log on/off change - argument = same as log status (PMTK182,2,7 response)
#
    my ( $self, $block_buf_ref, $b_i, $header_info ) = @_;

# We check to see if the prefix and suffix data match our expected
# pattern (or it's not a log separator!)
    unless (
        substr( $$block_buf_ref, $$b_i, LOG_ENTRY_SEPARATOR_PREFIX_LENGTH ) eq LOG_ENTRY_SEPARATOR_PREFIX
        and
            substr( 
                $$block_buf_ref, 
                LOG_ENTRY_SEPARATOR_PREFIX_LENGTH + 5 + $$b_i, 
                LOG_ENTRY_SEPARATOR_SUFFIX_LENGTH 
                ) eq LOG_ENTRY_SEPARATOR_SUFFIX

    ) {
        return;
    }

# Now we can figure out how the formatting changed
# TODO: this needs to be handled in the constants better
    my $entry_separator = {};
    my $mode = substr $$block_buf_ref, $$b_i+LOG_ENTRY_SEPARATOR_PREFIX_LENGTH, 1;

    if ($mode == LOG_ENTRY_SEPARATOR_BITMASK) {
        die "Bitmask Separator found";
    }

    $$b_i += 16;

    return $entry_separator;
}

sub print_hex_dump {
# --------------------------------------------------
    my ( $self, $buf_ref, $b_i, $bytes ) = @_;
    my $buf = substr $$buf_ref, $$b_i, $bytes;
    my @e   = map {sprintf "%02x", ord} split //, $buf;
    print join " ", @e;
    print "\n";
}

1;