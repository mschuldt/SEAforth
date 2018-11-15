\ descriptor.f
\ Support for creating Route Descriptors

\ north south east and west are like on a map:  from 1 to 2 to 8 to 14 to 20
\ would be east north north north and coded like this:

\   [ route EAST NORTH NORTH NORTH descriptor ] equ 1to20  \ named literal
\   ... [ route EAST NORTH NORTH NORTH descriptor ]# ...   \ unnamed literal

\ NOTE: there must be 1 to 8 NSEW entries for a valid descriptor!

\ to wake up a nearby (neighbor) node the same mechanism is used with the
\ addition of the neighbor's address, like this from 11 -> 10 -> 4:

\   [ route WEST SOUTH 4 's x0 neighbor ] equ WSneighbor \ named literal
\   ... [ route WEST SOUTH 4 's x0 neighbor ]# ...       \ unnamed literal

\ NOTE: there must be 1 to 4 NSEW entries for a valid neighbor address!

host

-1 constant route
 0 constant NORTH
 1 constant SOUTH
 2 constant EAST
 3 constant WEST

: neighbor ( -1 NSEWs '01'|address -- rd|na|ni )
   begin over 0< 0= while
     2* 2* +
   repeat
   nip ;

: descriptor ( -1 NSEWs -- rd )
   1  neighbor ;

: >njump ( -1 NSEWs na -- ni )   \ put na into [ @p+ ram0 -; ] instruction
   $ff and $05600 or neighbor ;  \ note: na must be a memory address

\ Note: target places the current node in the search order
: 's ( node -<name>- na )
   node @ >r  node !
    t'
   r> node ! ;
