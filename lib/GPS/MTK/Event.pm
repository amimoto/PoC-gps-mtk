package GPS::MTK::Event;

use strict;
use GPS::MTK::Base
    MTK_ATTRIBS => {
        event_hooks => {
        },
    };

sub event {
# --------------------------------------------------
# Triggers a single event based upon the NMEA
# string
#
    my ( $self, $line ) = @_;
}

sub hook_register {
# --------------------------------------------------
# This will register a single hook on the event queue
# for a particular type of event
#
}

sub hook_unregister {
# --------------------------------------------------
# This will remove a single hook on the event queue
# for a particular type of event. Basically, it will
# take events off the list and cause the "default"
# handler to be triggered when this event comes up
# again.
#
}

1;
