( $Id: ports.f,v 1.26.2.16 2006-09-23 04:07:43 dean Exp $ )
decimal
\ =========================================================================
\ Ports state machine control
\ =========================================================================

0 value pvect

\ Event# 0 = idle/complete, 1 = wanting to write, 2 = wanting to read.
\ Add 3 to remote event codes and use 6 for clock event.
\
: pstate ( - n)   remote 2@ 3 * + ;   ( the combined state vector)
: >event ( n)   pstate 7 *  over + cells  pvect + @ execute ;

: !lcl ( n)   local ! ;   ( don't ask, don't tell)
: >lcl ( n)   dup !lcl  other 3 + >event  other ;   ( notify neighbor)
: >rmt ( n)   3 - remote ! ;   ( remote states are as remotely saved)

\ =========================================================================
\ Ports state machine payload
\ =========================================================================

: nD!   other data @  other _data ! ;
: nC! ( n)   ns> timer ! ;
: 0C!   0 timer ! ;
: !idle   0C!  0 !lcl  0 remote ! ;   ( force port back to idle)

2 s" Write terminated" logger "WT
1 s" Write data conflict" logger "WC
: "WC?   data @ _data @ xor if  "WC then ;

2 s" Read terminated" logger "RT
1 s" Read data conflict" logger "RC
: "RC?   _data @  port @  1 4 do  i port !
      pstate 5 = if  over _data @ xor if  "RC
   then then  -1 +loop  port !  drop ;

0 s" Tell me what you did" logger "What?
: ???? ( n)   "What?  drop ;
0 s" Tell me what you did-0" -logr ???0
0 s" Tell me what you did-1" -logr ???1
0 s" Tell me what you did-2" -logr ???2
0 s" Tell me what you did-3" -logr ???3
0 s" Tell me what you did-4" -logr ???4
0 s" Tell me what you did-5" -logr ???5
0 s" Tell me what you did-6" -logr ???6
0 s" Tell me what you did-7" -logr ???7
0 s" Tell me what you did-8" -logr ???8
0 s" Tell me what you did-9" -logr ???9
0 s" Tell me what you did-A" -logr ???A
0 s" Tell me what you did-B" -logr ???B
0 s" Tell me what you did-C" -logr ???C
0 s" Tell me what you did-D" -logr ???D
0 s" Tell me what you did-E" -logr ???E
0 s" Tell me what you did-F" -logr ???F
0 s" Tell me what you did-G" -logr ???G
0 s" Tell me what you did-H" -logr ???H
0 s" Tell me what you did-I" -logr ???I
0 s" Tell me what you did-J" -logr ???J
0 s" Tell me what you did-K" -logr ???K
0 s" Tell me what you did-L" -logr ???L
0 s" Tell me what you did-M" -logr ???M
0 s" Tell me what you did-N" -logr ???N
0 s" Tell me what you did-O" -logr ???O
0 s" Tell me what you did-P" -logr ???P
0 s" Tell me what you did-Q" -logr ???Q
0 s" Tell me what you did-R" -logr ???R
0 s" Tell me what you did-S" -logr ???S
0 s" Tell me what you did-T" -logr ???T
0 s" Tell me what you did-U" -logr ???U
0 s" Tell me what you did-V" -logr ???V
0 s" Tell me what you did-W" -logr ???W
0 s" Tell me what you did-X" -logr ???X

: --rw ( n)   nD!  >rmt ;
: AWrw ( n)   nD! "WC?  >rmt ;
: AWrr ( n)   1 1+ nC!  >rmt ;
: ARrw ( n)   1 1+ nC! nD! "RC?  >rmt ;
: PWlw ( n)   "WC?  >lcl ;
: PWlr ( n)   2 nC!  >lcl ;
: PRlw ( n)   2 nC!  >lcl ;
: CRcd ( n)   drop  timer remains if  exit then  _data @ data !  !idle  1+ ;
: CRlc ( n)   timer remains if  "RT  !idle  exit then  ???2 ;
: CWcd ( n)   drop  timer remains if  exit then  !idle  1+ ;
: CWlc ( n)   timer remains if  "WT  !idle  exit then  ???3 ;

\ =========================================================================
\ Ports state-table vectors
\ =========================================================================

forth here  host to pvect
(  lc 0      lw 1      lr 2      rc 3      rw 4      rr 5      cd 6)
' drop ,  ' >lcl ,  ' >lcl ,  ' ???4 ,  ' --rw ,  ' >rmt ,  ' drop , \ -- 0
' >lcl ,  ' ???5 ,  ' ???6 ,  ' ???7 ,  ' AWrw ,  ' AWrr ,  ' drop , \ AW 1
' >lcl ,  ' ???8 ,  ' ???9 ,  ' ???A ,  ' ARrw ,  ' >rmt ,  ' drop , \ AR 2
' drop ,  ' PWlw ,  ' PWlr ,  ' >rmt ,  ' ???B ,  ' ???C ,  ' drop , \ PW 3
' >lcl ,  ' ???D ,  ' ???E ,  ' >rmt ,  ' ???F ,  ' ???G ,  ' drop , \ BW 4
' CRlc ,  ' ???H ,  ' ???I ,  ' ???0 ,  ' ???J ,  ' ???K ,  ' CRcd , \ CR 5
' drop ,  ' PRlw ,  ' >lcl ,  ' >rmt ,  ' ???L ,  ' ???M ,  ' drop , \ PR 6
' CWlc ,  ' ???N ,  ' ???O ,  ' ???1 ,  ' ???P ,  ' ???Q ,  ' CWcd , \ CW 7
' >lcl ,  ' ???R ,  ' ???S ,  ' >rmt ,  ' ???T ,  ' ???U ,  ' drop , \ BR 8

: "pstates ( - a)   s" --AWARPWBWCRPRCWBR" drop ;
: "pstate ( - a)   pstate 2* "pstates + ;
: .port   "pstate 2 type
   remote 2@ or 3 = if  timer remains 0 u.r  then ;
: (.ports) ( - a n)   <#  1 4 do  i port !
      "pstate count swap c@ hold hold  -1 +loop  0. #>  0 port ! ;

\   Build port status bits from neighbor states.
\ **Ultimately vector this for full edge-node behavior.
: (ios) ( - n)   port @ >r  0  5 1 do
      i port !  2* 2*  remote @ +  loop
   9 lshift  $15555 xor  r> port ! ;

\   The following set up port structures ready for state machine.
\ The background state is /clk as set by \port and /clk set by start of /port.
\
: \port   \clk ign ;                      \ This also done by finishing \clk.
: /port   /clk commit ( n - n')           \ **when do we get back here?
   adrs @ psel 2@ on? if  1+
      0 timer !  r-w @ >event             \ execute initial event and wait for..
      timer remains rest @ umin rest !    ( set timeout & display time)
      \clk commit ( n - n')   6 >event    \ **falling \clk event to ...
         timer remains rest @ umin rest ! ( set timeout & display time)
         then ;

\ =========================================================================
\ IOCS access vectors
\ =========================================================================

: \iocs   \clk ign ;
: /iocs   /clk commit ( n - n')
   adrs @ psel 2@ on? if  1+
      1 ns> timer !  timer remains rest !   ( set timeout & display time)
      \clk commit ( n - n')
         timer remains  dup rest !
         0= if  r-w @ 1- if
               (ios) data !  then
            \iocs  1+ then  then ;   \ ** timer not getting reset?

\ =========================================================================
\ Memory access vectors
\ =========================================================================

create mtimes  ( table of memory access times. index-bits= rom,bank1,read)
   ( w,r ram0) 3 c, 3 c,  ( w,r ram1) 3 c, 3 c,
   ( w,r rom0) 3 c, 3 c,  ( w,r rom1) 3 c, 3 c,
   
: @mem   adrs @ ta @ data ! ;
: !ram   data @ adrs @ ta ! ;
4 s" Store to rom" logger !rom
create xmem  ' !ram , ' @mem ,  ' !ram , ' @mem ,
             ' !rom , ' @mem ,  ' !rom , ' @mem ,

: \mem   \clk ign ;
: /mem   /clk commit ( n - n')
   adrs @ psel 2@ on? if  1+
      adrs @ 32 / 6 and  r-w @ 2/ +   ( build index to access times)
      dup local !  mtimes + c@   ( save index, get delay)
      ns> timer !  timer remains rest !   ( set timeout & display time)
      \clk commit ( n - n')
         timer remains  dup rest !
         0= if  local @ cells  xmem + @ execute
            \mem  1+ then  then ;   \ ** timer not getting reset?

\ =========================================================================
\ Initialize port associations
\ =========================================================================

\ **Ports that are illegally "paired" here are never assigned clock behaviours.
\
: initport   0 r-w !  0 rest !  0 timer !  0 0 remote 2! ;
: initports   #nodes 0 do  i node !
      1 port !  .r--- psel 2!  /port  \port         \ These two are
         i 1 xor  pair# !  initport
      2 port !  .-d-- psel 2!  /port  \port         \  safe defaults.
         i #cols /mod 1 xor  #cols * + pair# !
         initport
      3 port !  .--l- psel 2!  /clk ign  \clk ign   \ These must be custom
         i 1+ 1 xor  1- pair# !  initport
      4 port !  .---u psel 2!  /clk ign  \clk ign   \  part of chip spec
         i #cols /mod 1+ 1 xor  1- #cols * + pair# !
         initport
      5 port !  .iocs psel 2!  /iocs  \iocs         \  look to "spec" area.
         initport
      6 port !  .memy psel 2!  /mem  \mem           \ 
         initport
   loop  0 node ! ;
\ **Someone above must co-ordinate with /ports on catching adrs-decode conflicts.

\ =========================================================================
\ Initialize exception port associations
\ =========================================================================

: connect ( n)   port !  /port  \port ;
: yourself ( n)   port !  node @ pair# ! ;
: =center ( n)   node !  3 connect  4 connect ;
: =corner ( n)   node !  3 yourself  4 yourself ;
: =edge ( n)   node !  3 connect  4 yourself ;
: =side ( n)   node !  3 yourself  4 connect ;

\ finish node neighbor connections.
\
: connections
 0 =corner   6 =side    12 =side    18 =corner
 1 =edge     7 =center  13 =center  19 =edge
 2 =edge     8 =center  14 =center  20 =edge
 3 =edge     9 =center  15 =center  21 =edge
 4 =edge    10 =center  16 =center  22 =edge
 5 =corner  11 =side    17 =side    23 =corner ;
