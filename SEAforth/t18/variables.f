( $Id: variables.f,v 1.28.4.11 2006-09-23 05:39:10 randy Exp $ )
decimal

\ =========================================================================
\ System configuration flags
\ =========================================================================

-1 value sim    ( compile certain literals as small values to speed test)
\   0 to sim !   ( unless sim is zero, then use nominal values)

true value c18-optimize   ( true attempts short forward branches)

\ =========================================================================
\ Simulated external ram
\ =========================================================================

create xram $10000 cells allot      \ 64k 16-bit words of external ram
: exram ( a - a)                    \ cell index to external RAM as pc byte addr
   $ffff and cells xram + ;         \ external ram simulation address conversion

create testbed1 $4000 cells allot   \ 64k bytes for testbed
create testbed2 $80000 cells allot  \ 2MB for testbed2 for audio/rf data files

\ =========================================================================
\ Symbol array supports address to name generation
\ =========================================================================

create symtable  $800 cells allot   \ target adr, name pointer pairs
   symtable $800 cells erase
variable *symbol  symtable *symbol !

create symarray  $4000 cells allot  \ 64k names array
variable sym*  symarray sym* !

\ =========================================================================
\ AR25c18 rev7 specific dimensions
\ =========================================================================

  8 constant #stk       \ size of invisible stack bodies, assume both same
6   constant #cols      \ chip dimentions, # node collumns
  4 constant #rows      \ chip dimentions, # node rows
6 4 * constant #nodes   \ chip size in nodes
256 constant #ram/rom   \ ram/rom space, not always fully decoded (see below)
$BF constant &decode    \ address "wrap" (partial decode) mask (BF or FF)
$7f constant &wrap      \ address wrap (carry break) likely will not change
512 constant |regs|     \ max node "reg" space (includes memory)
 16 constant |port|     \ max nunber of port variables
  6 constant #ports     \ max # of ports (rdlu-cs are 1st, ram/rom is a port)
\ Port numbers are 1 through #ports. 0 means no port selected (so be careful!)
$aa value bootadr       \ where we go from reset

\ =========================================================================
\ Internal memory, register and state variable space
\ =========================================================================

create c18mem  |regs| #nodes * cells allot   ( 512 words for each of 24 nodes)

create node^s  #nodes cells allot   ( table of base pointers to node vars)
variable ^mem  0 ^mem !   ( node register allocation pointer)

variable node  0 node !
variable port  0 port !

: reg ( n)   ( compute local register address from named offset)
   ^mem @  dup cells constant +
      |regs| over < abort" Too many node vars"
      ^mem !  does> ( - a)  @
         node @ cells node^s + @ + ;

: /node^s   node^s  #nodes 0 do
      i |regs| * cells  c18mem + over !  cell+ loop drop ;
/node^s   ( initialize node data index table)

\ It is assumed that port variables are allocated after mem & before regs
\
: pvar ( n)   ( assign port variable given offset)
   dup |port| u< 0= abort" port space is too small"
   #ram/rom + |port| -  constant  does> ( - a)  @ 
      port @ |port| * + cells
      node @ cells node^s + @ + ;

\ =========================================================================
\ General support words (some perhaps candidates for compatibility section)
\ =========================================================================

( Words paired at same return stack level to make temp node selection)

: <node ( n)   node @ r> 2>r  node ! ;
: node>   2r> >r  node ! ;   ( NOTE!!! exit must not follow node> due to SwF optimizer)

: <port ( n)   port @ r> 2>r  port ! ;
: port>   2r> >r  port ! ;   ( NOTE!!! exit must not follow port> due to SwF optimizer)

\   The preceeding are provided only for the faint hearted worriers. Our
\ preference is that they never get used in actual prictice, at least by
\ tool builders. The reason for this is that these values change far more
\ than they stay the same. Only the debugging user, in the context of the
\ simulator's interface, will have any permanent assignments here, and
\ likely only to  node  but not for  port . It falls then to those interface
\ words to provide sufficient  protection of these variables to support
\ the expected context. It is for those words that these are provided.
\ Delay their use as long as possible.

( commit acts like ASSIGN  recall acts like @EXECUTE)
: commit ( a)   r> swap ! ;   ( NOTE!!! exit must not follow commit due to SwF optimizer)
: recall ( a)   @ >r ;   ( NOTE!!! exit must not follow recall due to SwF optimizer)
: xt   ;                 ( simple exit, used by ignore below)
: ign ( a)   commit  xt ;   ( use of xt defeats SwF optimize)

( Bit field test and set functions)
: any? ( n s m - t)   >r xor  r@ and  r> xor ;  \ limited utility 
: off? ( n s m - t)   >r xor  r> and ;          \ -all? with many bits (useful?)
: on? ( n s m - t)   >r xor  r> and 0= ;        \ all? when used with many bits
: set! ( n s m - n')   invert rot and  xor ;
: rst! ( n s m - n')   rot over invert and  xor xor ;
: .+ ( s m s m - s' m')   rot or >r  or r> ;

\ =========================================================================
\ Masked selection bit names in field test format
\ =========================================================================
hex

\ iocs bit definiions (likely not useful)
20000 20000 2constant .wake
00000 10000 2constant .r@
08000 08000 2constant .r!
00000 04000 2constant .d@
02000 02000 2constant .d!
00000 01000 2constant .l@
00800 00800 2constant .l!
00000 00400 2constant .u@
00200 00200 2constant .u!

\ memory decode selectors (.rdlu useful?)
00180 00180 2constant .r---
00100 00140 2constant .-d--
00120 00120 2constant .--l-
00100 00110 2constant .---u
.r--- .-d-- .--l- .---u
   .+ .+ .+ 2constant .rdlu
00108 00108 2constant .iocs
00100 00104 2constant .nohs
00000 00100 2constant .memy

decimal
\ =========================================================================
\ Globally defined variables
\ =========================================================================

variable time      \ current "ns" time times 2, compare to odd timers
: @ns ( - n)   time @ 2/ ;   ( make units be independant of internals)
: ns> ( n - n)   2* 1- time @ + ;   ( make target time for given delay)
: remains ( a - n)   @ dup if  time @ - 1+ 2/  0 max exit
      then 1- ;   ( = ns left or -1 if no limit)

variable #errors   \ total error count this session
variable step#errs \ errors during prior step
variable errlvl    \ errors less than or equal to this are displayed
                   \ 4=info, 3=caution, 2=warning, 1=danger

\ =========================================================================
\ reg  defined words, define all C18 registers & states for each node
\ =========================================================================

#ram/rom
   reg ram/rom     \ node addressible memory

 0 reg registers   \ base loc of simulator node vars & state info

#ports |port| *
   reg ports       \ pvar definer assumes ports go here

 1 reg a           \ 18 bit incrimentable adrs (see +adr for rules)
 1 reg t           \ fetch/store & alu feed and dest, top stack item
#stk 1+ reg s      \ alu feed, second stack item and stack body
 1 reg sp          \ modulo index to data stack body
#stk 1+ reg r      \ top and body of return stack
 1 reg rp          \ modulo index to return sack body
 1 reg b           \ 9 bit, write only, non-incrementing adrs
 1 reg pc          \ 9 bit program counter
 1 reg iw          \ instruction word
 5 reg slots       \ prescanned iw as paterns ( fetch = ??, unext = ??)
 1 reg @slot       \ where prefetch might begin ( @slot 2@ = )
 1 reg slot        \ (0-4) used by asm and sim
 1 reg busy        \ set when sim active, cleared when node displayed
 1 reg hasty       \ true means + has not enough time to settle

 1 reg /clock      \ vector for start of "cycle" step
 1 reg \clock      \ vector for end of cycle, results clocked

\ next two not developed yet...
\
 1 reg prefetch    \ a prefetch is started and not yet claimed by an opcode
 1 reg waiting     \ an opcode is waiting for "memory", -1=sleep, >0=ns_left

\  used only by "assembler"...(slot also used)
\
 1 reg h           \ "top of dictionary" for next instruction or literal
 1 reg ip          \ where current iw is being assembled (could use pc ?)

\ These regs are provisionally kept for compatibility, they may be dumped.
\
 1 reg bp          \ one private breakpoint
 1 reg bp2         \ second breakpoint
 1 reg memb        \ break on memory access
 1 reg 'userbreak  \ vectored user defined breakpoint on each node

\ =========================================================================
\ port structures, sub-tables within node space
\ =========================================================================
\
\   Ports provide specialized behaviour for access to selected memory
\ decode. Ram/rom access is one port. Each of the four comunication paths
\ to neighbor nodes is a port, and the iocs register is a port. Address
\ bit 2 will disable neighbor wait function, as will iocs access. Combining
\ either of these with the address of a valid neighbor is SO FAR **
\ considered an error case. Neighbor ports associate to each other via
\ pair# . The first four port tables belong to rdlu in that order. Ports
\ number from 1, zero is reserved as "no port selected". This is important
\ only to tagging of simulator status logs.
\

 1 reg r-w         \ >2=meaningless, 2=read, 1=write, 0=no transfer active
 1 reg adrs        \ 9 bit address bus, high bits kept for post incr update
 1 reg data        \ 18 bit output data or input result
 1 reg rest        \ time left to current transfer or 0, -1 = unknown

 0 pvar /clk       \ new status advertize state vector
 1 pvar psel       \ decode and xor mask for this "port"
 3 pvar \clk       \ decision time on next state change
 4 pvar timer      \ set to odd target ns value to set delay
 5 pvar pair#      \ number of this's pair, swap with  node  to see it's port
 6 pvar remote     \ status information received from partner
 7 pvar local      \ local status; 0=idle, 1=write, 2=read
 8 pvar _data      \ data value driven by remote

: other   pair# @ node ! ;   ( use  other  again to get back!)

\   Remember support for pin-wake and neighbor-wake wires.
\ Also iocs needs to support bit inversion on in and out.

\ : up@wake             78 reg ;
\ : left@wake           79 reg ; \ revP wake registers
\ : reset               82 reg ; \ true after reset when running

\   Assembler might use a node var to remember a programmer declaired
\ default ioc value. It could then provide a support word to xor default
\ onto a user value to make a literal ready to store to port.

\ =========================================================================
\ end of 'reg' defined for each node
\ =========================================================================

\ =========================================================================
\ misc useful words
\ =========================================================================

\ increment an address bus value by addres specific rules
: +adr ( a n - |a+n| )   over .memy off? if  drop   \ stall in port space
     else  over + over xor  &wrap and xor  then ;    \ seven bit add in memory

\ convert target address to actual host address for access
: ta ( ta -- ha )   &decode and cells  ram/rom + ;

\ fetch with sign extend, assuming high bits initially zeros
: @18 ( a - n)   @ $fffe0000 xor $20000 + ;

\ mask and store
: !18 ( n a)   swap $3ffff and swap ! ;
