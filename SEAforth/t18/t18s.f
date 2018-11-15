cr .( $Id: t18s.f,v 1.30.2.17 2006-09-23 04:11:17 dean Exp $ )
\ =========================================================================
\ T18 Simulator (except for parts in variables, ports, testbed, and interface)
\ =========================================================================
decimal

\ =========================================================================
\ The actual stepping word. (This could go almost anywhere.)
\ =========================================================================

: step   reset-slog  node @ >r  #nodes 0 do  i node !  /clock recall  loop
   2 time +!  #nodes 0 do  i node !  \clock recall  loop  r> node ! ;
   
\ =========================================================================
\ Some stacking tools..
\ =========================================================================
\
\   The structure of  r rp  and  s sp  are set up so that the pointer names
\ set their upper limit for travel and the top item names set the bottom limit.
\

\ Change r after use
: rpush   r @  rp @ cell+  dup rp = if
      drop r cell+  then dup rp !  ! ;

\ Grab r before use
: rpop   rp @ @ r !  rp @ cell -
   dup r = if  drop rp cell -  then rp ! ;

\ Change t after use
: dpush   t @  s @  sp @ cell+  dup sp = if
      drop s cell+  then dup sp !  !  s ! ;

\ Grab t before use
: dpop   s @ t !  sp @ @ s !  sp @ cell -
   dup s = if  drop sp cell -  then sp ! ;

\ =========================================================================
\ Details factored out of opcodes
\ =========================================================================

: !hasty   1 hasty ! ;
: -hasty   0 hasty ! ;
4 s" Performed an add in haste." logger "hasty
: ?hasty   hasty @ if  "hasty then ;

\ Produce address of current opcode in slots table.
: 'slot ( - a)   slot @ cells slots + ;
: opcode ( - n)   'slot @ ;

\ Define named fields within the instructions table for the 'slot opcode.
0 value instructions
: op:   constant  does> ( - a)
      @  opcode 16 * instructions + + ;
   0 op: 'op      \ Address of simulation behavior
   4 op: op@      \ Memory opcode precludes prefetch
   5 op: op;      \ This opcode is the last one in an iw (not unext)
   6 op: op+      \ If op;=1 show adrs fld (w/symbol if =2), if op;=0 then pc+ 
   8 op: op"      \ Text of display name padded to 8 characters
: xop ( op -- f )  'op @ execute ;

\ Roll up some common functions used in opcode simulation.
: -op   /clock ign ;       \ Don't redo opcodes waiting on memory
: /op   \clock ign  /clock commit  xop ;      \ Initial "decode"
: +op   1 slot +!  /op ;   \ Done, go to next slot and enable decode

\ Merge the address field into an address on the stack.
create fldmask  $1fff , $ff , $7 , 0 , 0 ,  ( the last two are imaginary!)
: adrmask ( - m)   slot @ cells fldmask + @ ;
: &adrfld ( a - a')   adrmask invert and  'slot cell+ @ + ;

\ Branch and conditional branch address calulations
: &fld ( - a)   pc @ &adrfld ;
: ?&fld ( t - a)   pc @  swap 0= if  &adrfld then ;

\ =========================================================================
\ Port interface API
\ =========================================================================
\
\   These words provide the clock up selection and clock down servicing
\ needed for managing memory and I/O tranfers and timing. It is best if
\ only one clock up is used and if clock down does not occur until a
\ tranfer is requested. This will happen if they are enabled in mutually
\ exclusive pieces of code. The clock down code expects a stack count to
\ accumulate transfer completes that are passed out as a completion flag.
\ the same flag is used to trigger internal completion messages on exit.
\

1 s" Address does not decode" logger "undecode
: /access ( r/w)   r-w !  -1 rest !
   0  1 #ports do  i port !
      /clk recall  -1 +loop  0 port !
   0= if  "undecode  then ;
   
: /fetch ( a)   adrs !  2 /access  -op ;
: /store ( n a)   adrs !  data !  1 /access  -op ;

: \access ( - t)   -1 rest !  ( *)0  1 #ports do
      i port !  \clk recall  -1 +loop
   ( * any lc) dup if  1 4 do
         i port !  0 >event  -1 +loop
      0 rest !  0 r-w !  then  0 port ! ;

: \fetch ( - t)   \access  dup if  +op then ;
: \store ( - t)   \access  dup if  +op then ;   ( ** s must pop when done)

\ =========================================================================
\ First pass instruction scan
\ =========================================================================
\
\   The action of this prescan is to split the iw content into separate
\ entries in the slots table, from zero through that entry responsible for
\ fetching the next instruction. Opcodes <8 will fetch the next iw and so
\ will terminate execution of the current iw. Opcodes from 2 through 7
\ consume the rest of the iw with address information.
\
\   The current slots opcode is indexed by slot via the word 'slot , and
\ if an address field is needed it will be found at 'slot cell+ . The
\ index in @slot is the slot number which, *if reached*, will automaticly
\ prefetch the next iw. Prefetch cannot begin until after any other
\ fetching opcode, and so @slot is set to one greater than the slot of
\ any opcode < 16. It is initially set to 0 when scan begins.
\

\   Return true unless the current opcode is the last in iw (ie, <8),
\ save current opcode and adrs in slots, and find best @slot value.
\
: !slot ( r q - r t | f)   'slot 2!         \ save opcode and "adrs"
   op@ c@ if  slot @ 1+  @slot !            \ set prefetch after any mem ops
      op; c@ if  0  exit then  then         \ set when this opc fetches next iw
   1 slot +!  opcode 1 ;                    \ bump slot & return to process more
   
\   Prescan instruction word as described above. In order to affect
\ differences in prefetch depending upon address space, the pc is examined
\ by iw!. This means that all branching words must set the new pc value
\ before calling iw!. This should not prove a hardship, even for .adrs .
\
: iw! ( n)   dup iw !  0 slot !  1 @slot !  \ setup (4 slot xor would mash adrs)
   $2000 /mod  $0a xor  !slot if            \ slot 0 (xor's normalize paterns)
      $100 /mod  $15 xor  !slot if          \ slot 1 (odd slot xor)
         8 /mod  $0a xor  !slot if          \ slot 2 (.. rest is 3 and "4")
            4 *  $14 xor  -1 swap           \ -1 = prefetch (in slot 4)
            dup $04 = 2* or  !slot if       \ -2 = unext (ie, $04 = 2*)
               drop then then then then     \ stack adjustment
   pc @ .memy off? if
      @slot @ 3 max  @slot !  then ;        \ do this here to simplify ?/fetch

\ Some more rolled up functions.
\
: +adrs ( - n)   adrs @ 1 +adr ;   ( This is the address bus auto increment)
: !inst   +adrs pc !  data @ iw!  0 slot ! ;   ( Address bus to  iw  and  pc)

\ =========================================================================
\ Prefetch support
\ =========================================================================

\   Returns true if prefetch was in progress or has been started and this
\ instruction is in slot 3. For other slots, prefetch is started at @slot .
\ Well... maybe. It seems as if ram/rom prefetch desn't get into gear until
\ around slot 1 (so it finishes in slot 3), and prefetch from port space
\ doesn't seem to start until slot 3 (and thats a good thing because what
\ could we do if the neighbor finished its write before our iw was free).
\ In use, ?/fetch is not called after returning true, then ?\fetch is used.

: ?/fetch ( - t)   0  @slot 2@ 1- > if   ( after its ok, and we're sill here)
         r-w @ 0= if  pc @ adrs !  2 /access  then   ( start fetch)
      slot @ 3 = -  dup if  -op exit then  then  1 slot +! ;
      ( answer true to slot 3 fetching)

\   Returns true if active prefetch has just completed. PC will have been
\ incremented.
\
: ?\fetch ( - t)   \access  dup if  !inst  /op  then ;

\ =========================================================================
\ So...  uh...  opcodes go here...  eh?
\ =========================================================================

\ Finally the opcode executors. ** check all for clips & extends, esp pc & b
\
: _!01!   ?/fetch if  \clock commit  ?\fetch while  then
      -hasty  then ;
: _!05!   ?/fetch if  \clock commit  ?\fetch while  then
      -hasty  then ;
: _unext   \clock commit
      r @ $ffff and if  -1 r +!  0 else  rpop  slot @ 1+ then  slot !  -hasty ;
: _fetch   pc @ /fetch  \clock commit  \fetch if
      !inst  -hasty  then ;
: _;   r @ /fetch  \clock commit  \fetch if
      rpop  !inst  -hasty  then ;
: _;:   r @ /fetch  \clock commit  \fetch if
      rpop  pc @ rpush r !  !inst  -hasty  then ;
: _call   &fld /fetch  \clock commit  \fetch if
      pc @ rpush r !  !inst  -hasty  then ;
: _jump   &fld /fetch  \clock commit  \fetch if
      !inst  -hasty  then ;
: _next   r @ $ffff and 0= ?&fld /fetch  \clock commit  \fetch if
      r @ $ffff and if  -1 r +!  else  rpop  then  !inst  -hasty  then ;
: _1if   t @ 1 and ?&fld /fetch  \clock commit  \fetch if
      !inst  -hasty  then ;
: _if   t @ ?&fld /fetch  \clock commit  \fetch if
      !inst  -hasty  then ;
: _-if   t @18 0< ?&fld /fetch  \clock commit  \fetch if
      !inst  -hasty  then ;
: _@p+   pc @ /fetch  \clock commit  \fetch if
      dpush  data @ t !  +adrs pc !  !hasty  then ;
: _@a+   a @ /fetch  \clock commit  \fetch if
      dpush  data @ t !  +adrs a !  !hasty  then ;
: _@b   b @ /fetch  \clock commit  \fetch if
      dpush  data @ t !  !hasty  then ;
: _@a   a @ /fetch  \clock commit  \fetch if
      dpush  data @ t !  !hasty  then ;
: _!p+   t @ pc @ /store  \clock commit  \store if
      dpop  +adrs pc !  !hasty  then ;
: _!a+   t @ a @ /store  \clock commit  \store if
      dpop  +adrs a !  !hasty  then ;
: _!b   t @ b @ /store  \clock commit  \store if
      dpop  !hasty  then ;
: _!a   t @ a @ /store  \clock commit  \store if
      dpop  !hasty  then ;
: _+*   ?/fetch if  \clock commit  ?\fetch while  -hasty then  ?hasty
      s @18 t @18  dup 1 and if  over + then  2/ t !18  drop  !hasty  then ;
: _2*   ?/fetch if  \clock commit  ?\fetch while  then
      t @ 2* t !18  !hasty  then ;
: _2/   ?/fetch if  \clock commit  ?\fetch while  then
      t @18 2/ t !18  !hasty  then ;
: _not   ?/fetch if  \clock commit  ?\fetch while  then
      t @ invert t !18  !hasty  then ;
: _+   ?/fetch if  \clock commit  ?\fetch while  -hasty then
      ?hasty  s @ t @ +  dpop  t !18  !hasty  then ;
: _and   ?/fetch if  \clock commit  ?\fetch while  then
      s @ t @ and  dpop  t !  !hasty  then ;
: _xor   ?/fetch if  \clock commit  ?\fetch while  then
      s @ t @ xor  dpop  t !  !hasty  then ;
: _drop   ?/fetch if  \clock commit  ?\fetch while  then
      dpop  !hasty  then ;
: _dup   ?/fetch if  \clock commit  ?\fetch while  then
      dpush  !hasty  then ;
: _pop   ?/fetch if  \clock commit  ?\fetch while  then
      r @ rpop  dpush t !  !hasty  then ;
: _over   ?/fetch if  \clock commit  ?\fetch while  then
      s @ dpush t !  !hasty  then ;
: _a@   ?/fetch if  \clock commit  ?\fetch while  then
      dpush  a @ t !  !hasty  then ;
: _.   ?/fetch if  \clock commit  ?\fetch while  then
      -hasty  then ;
: _push   ?/fetch if  \clock commit  ?\fetch while  then
      t @ dpop  rpush r !  !hasty  then ;
: _b!   ?/fetch if  \clock commit  ?\fetch while  then
      t @ b !  dpop  !hasty  then ;
: _a!   ?/fetch if  \clock commit  ?\fetch while  then
      t @ a !  dpop  !hasty  then ;

\ =========================================================================
\ Opcode decode shell
\ =========================================================================
\ Create a table of simulation words with the following properties:
\
\ 1. Canonical Opcodes are used to index into the table.
\    e.g. The first entry is for ;  the last entry is for a!
\ 2. The table consists of one section per opcode, where each section contains:
\   a. The address of the simulation behavior for the opcode (e.g ' _; ), 1 cell.
\   b. 4 1-byte flags.
\   c. The display string for this opcode; 8 bytes, space pad.
\ =========================================================================

: ,sim  ( f f f f) \ _name
   bl word  pad over c@ 1+ move  pad >r
   r@ find  forth  0= abort" opcode not found"
   ,  c, c, c, c,  here 8 blank
   r@ 2 + here r> c@ 1- move  8 allot ;   host

\ -0- op+ op; op@ <- flag bytes
\
0 0 0 1 ,sim _unext
0 0 0 1 ,sim _fetch
forth here  host  to instructions
0 0 1 1 ,sim _;
0 0 1 1 ,sim _!01!
0 ( 2**)1 1 1 ,sim _call
0 ( 2**)1 1 1 ,sim _jump

0 1 1 1 ,sim _next
0 1 1 1 ,sim _!05!
0 1 1 1 ,sim _if
0 1 1 1 ,sim _-if

0 1 0 1 ,sim _@p+
0 0 0 1 ,sim _@a+
0 0 0 1 ,sim _@b
0 0 0 1 ,sim _@a

0 1 0 1 ,sim _!p+
0 0 0 1 ,sim _!a+
0 0 0 1 ,sim _!b
0 0 0 1 ,sim _!a

0 0 0 0 ,sim _+*
0 0 0 0 ,sim _2*
0 0 0 0 ,sim _2/
0 0 0 0 ,sim _not

0 0 0 0 ,sim _+
0 0 0 0 ,sim _and
0 0 0 0 ,sim _xor
0 0 0 0 ,sim _drop

0 0 0 0 ,sim _dup
0 0 0 0 ,sim _pop
0 0 0 0 ,sim _over
0 0 0 0 ,sim _a@

0 0 0 0 ,sim _.
0 0 0 0 ,sim _push
0 0 0 0 ,sim _b!
0 0 0 0 ,sim _a!

\ =========================================================================
\ Initialization (revisited)
\ =========================================================================

\ **Don't forget to initialize port specifics and/or testbed.
: initnode                        \ pc slot sp rp t a b s[1]-s[9] r[0]-r[8] iw
   bootadr pc !  4 slot !
   -1 slots 16 + !
   s cell+ sp !  r cell+ rp !
   $15555  dup a !  dup b !
      dup t !  dup s !  r !
   #stk 0 do  dpush  rpush  loop ;

: init   initports  connections  0 port !
   #nodes 0 do  i node !
      /op  ( ** Anything else??)
      initnode  loop  0 node ! ;
init

\ =========================================================================
\ Some display primatives (?)
\ =========================================================================
\

( widely used)
: (.opcode) ( - a n)   op" 8 -trailing ;
: .opcode   (.opcode) 1+ type ;

( internal)
: .ta ( ta - x)   \ display xfer address (and a label if call/jump)
   op+ c@ if  &adrfld  dup .          \ calc dest adrs for branches
      op+ c@ 2 = if                   \ search symbols if flag = 2
         dup symbol?  dup 0= if       
            -1 global-search !        \ check globals if it's not local
            2drop  dup symbol?
            0 global-search !         \ count = 0 if not found, type it
         then space type  then then ;

( used by .adrs)
: .inst ( ta)
   slot @ >r  iw @ >r  pc @ >r    \ save current context
   dup ta @ iw!  1 +adr ( ta')    \ keep address for finding destination
   slot @ 1+ 0 do  i slot !       \ slot has opcode count after iw!
      .opcode  op; c@ if  .ta     \ show op, then optional dest
         else  op+ c@ +adr  then  \ or skip any literals
   loop drop
   r> pc !  r> iw!  r> slot ! ;   \ restore context
