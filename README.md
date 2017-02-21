This script print out duplicated library symbols for the binary.

Example:

    $ ./checkdupls.sh mplayer
    Checking /usr/bin/mplayer ...
    Read all libs... 219
    Get all symbols... 49666
    Get all non uniq symbols... 182
    Repeated:
    attr_get /usr/lib/libncurses.so.5.9
    attr_get /lib/libattr.so.1.1.2448
    attr_set /usr/lib/libncurses.so.5.9
    attr_set /lib/libattr.so.1.1.2448
    pa_ascii_filter /usr/lib/libpulse.so.0.20.1
    pa_ascii_filter /usr/lib/pulseaudio/libpulsecommon-10.0.so
    ....
