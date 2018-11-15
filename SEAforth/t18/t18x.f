( $Id: t18x.f,v 1.3.4.11 2006-09-21 06:24:59 randy Exp $ )

\ main t18 target compiler/simulator load file.

hex
wordlist constant (host)
wordlist constant (c18)
wordlist constant (target)
wordlist constant (global-node)

: host ( -- )   forth-wordlist (host) 2 set-order  definitions ;  immediate
: c18  ( -- )   forth-wordlist (host) (c18) 3 set-order  definitions ;  immediate
: forth ( -- )   forth-wordlist 1 set-order  definitions ; immediate  

host  \  host forth   def:host

include variables.f   \ define variables, constants, and arrays
                      \ register type variables have an instance on each node, 24 t,s, bp, etc
include logs.f        \ get those logs in early 'n use 'm!

\ #nodes cells buffer: node-wids
create node-wids  #nodes cells allot

: init-node-wids ( -- )   #nodes 0 do  wordlist node-wids  i cells + !  loop ;
init-node-wids

: @node-wid ( -- wid ) \ return wid of current target node
   node @  cells node-wids +  @
;

forth
: target ( -- )
   forth-wordlist (host) (target) 3 set-order  definitions
; immediate

: compiling ( -- ) host
   (global-node) @node-wid (target) 3 set-order 
   @node-wid set-current
; immediate

0 value global-search
: global-node ( -- )
   forth-wordlist (host) (target) (global-node) 4 set-order  definitions
   -1 to global-search ;  immediate

target
: order host order ; immediate

include t18.f         \ target compiler. target wordlist
include ports.f
include t18s.f       

\ include forthlets.f     \ Forthlet Tools F: F; S: S; X: X;
include descriptor.f    \ describe deliver|destination l u d r descriptor: <NAME>
\ include testbed1.f      \ testbed control of boot and data fed to pins
include interface.f     \ UI display and debug words
