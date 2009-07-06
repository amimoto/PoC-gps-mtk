package GPS::MTK::Parser::GPX;

use strict;
use bytes;
use vars qw/ @ISA $MTK_ATTRIBS /;
use GPS::MTK;
use GPS::MTK::Constants qw/:all/;
use GPS::MTK::Parser;

@ISA = 'GPS::MTK::Parser';
$MTK_ATTRIBS = {
    fpath_out => '%Y-%M-%D_%h:%m:%s.gpx',
};

sub log_fpath_open {
# --------------------------------------------------
# Let's open the file and create our header
#
    my ($self,$fpath_new,$state,$entry_info,$header_info) = @_;

# This will create a GPX file for us to play with
    my $headers = $header_info->{log_format_elements};
    $state->{track_segment_count} = 0;

# Open the file deposit the header...
    my $fh = Symbol::gensym();
    open $fh, ">$fpath_new";

# Add the GPX header
    print $fh qq`<?xml version="1.0"?>
<gpx
version="1.0"
creator="ExpertGPS 1.1 - http://www.topografix.com"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns="http://www.topografix.com/GPX/1/0"
xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
`;

    return $fh;
}

sub log_fpath_close {
# --------------------------------------------------
# This will be called when the file is no longer
# required. At this point either the track or the
# track segment has completed. The footer can be added to the
# output at this point
#
    my ($self,$state,$entry_separator,$header_info) = @_;

    my $fh = $state->{fpath_fh} or return;

# $entry_separator is undef only we've finished parsing
    if ( $state->{track_segment_started} ) {
        print  $fh qq`</trkseg>\n</trk>\n`;
        $state->{track_segment_started} = 0;
        $state->{track_point_count} = 0;
    }

    if ( $entry_separator ) {
        return;
    };

    print $fh qq`
</gpx>
`;

}

sub log_entry_handler {
# --------------------------------------------------
    my ( $self, $state, $entry_info, $header_info ) = @_;

    my $fh = $state->{fpath_fh} or return;

# If the track segment hasn't been started, we must start one
    unless ( $state->{track_segment_started} ) {
        $state->{track_segment_started} = 1;
        $state->{track_segment_count}++;

# Add the track header
    print $fh qq`\n
<trk>
<name><![CDATA[]]></name>
<desc><![CDATA[]]></desc>
<number>$state->{track_segment_count}</number>
<trkseg>
`;

    }

# Insert a single entry
    $state->{track_point_count}++;
    my $buf = qq`<trkpt lat="$entry_info->{latitude}" lon="$entry_info->{longitude}">`;
    $buf .= qq`<cmt><![CDATA[$state->{track_point_count}]]></cmt>`;

    if ( my $utc = $entry_info->{utc} ) {
        my @z = gmtime $utc;
        $z[4] ++;
        $z[5] += 1900;
        $buf .= sprintf qq`<time>%04i-%02i-%02iT%02i:%02i:%02iZ</time>`, reverse @z[0..5];
    }
#<ele>44.805600</ele>
#<name><![CDATA[T-0431]]></name>
#<cmt><![CDATA[Sat May 26 20:42:57 2001]]></cmt>
#<desc><![CDATA[Trackpoint 0431]]></desc>
#<sym>Dot</sym>

    $buf   .= qq`</trkpt>\n`;

    print $fh $buf;
}


1;
