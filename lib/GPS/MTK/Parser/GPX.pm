package GPS::MTK::Parser::GPX;

use strict;
use bytes;
use vars qw/ @ISA /;
use GPS::MTK;
use GPS::MTK::Constants qw/:all/;
use GPS::MTK::Parser;

@ISA = 'GPS::MTK::Parser::GPX';


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

1;
