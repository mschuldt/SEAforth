( $Id: interface.f,v 1.20.2.22 2006-09-23 05:27:32 randy Exp $ ) 
\ user interface words

host

defer record-stepset \ mark after stepping through all nodes
' noop is record-stepset

: 5.u 0 <# # # # # # #> type ;
: 3.u 0     <# # # # #> type ;
: 2.u 0       <# # # #> type ;
: 1.u 0         <# # #> type ;

\ display all c18 registers

: .cregs1 ( -- ) 
\   ?.sleep cr
   ." bp=" bp @ 6 .r ."  pc=" pc @ 6 .r
   ."  iw=" iw @ 6 .r ."  slot=" slot @ 2 .r cr ;

: .ops   ." opcode=" opcode . ."  instruction=" .opcode cr ;

: .regline ( -- )
   ."         t     r     a     b     sp    rp" cr
;
: .cregs2 ( -- )
   5 spaces
   t @ 6 .r   r @ 6 .r   a @ 6 .r   b @ 6 .r 
   sp @  4 /  5 .r   rp @  4 /  6 .r   cr
;

: ?.sp ( n -- )  \ print "<- sp = n" at location n
   sp @  4 /  =  if  ." SP-->"  else  5 spaces  then
;

: ?.rp ( n -- )  \ print "<- rp = n" at location n
   rp @  4 /  =  if  ." <-- RP "  then
;

: .stacks ( -- )
   0 ?.sp   s @ 6 .r   r cell+ @ 6 .r    0 ?.rp  cr
   1 ?.sp   s cell+ @ 6 .r   r 2 cells + @ 6 .r   1 ?.rp  cr
   #stk 2 do 
      i ?.sp   s i cells +  @  6 .r   r i 1+  cells +  @  6 .r   i ?.rp  cr
   loop
 \  #stack ?.sp  s #stack cells + @ 6 .r    cr
;

: .c ( -- )
   cr  .cregs1  .ops  .regline  .cregs2  .stacks
;

: .adr ( target-adr -- )              \ it should display ports
   dup symbol? dup if
     cr ." : " 2dup type
   then 2drop
   cr dup 3.u space dup ta @ 5.u space .inst ;

: .adrs ( t-adr count -- )
   over + swap do i .adr loop ;

: .symbols ( -- )                  \ display the symbol table ** rewrite
   *symbol @ symtable
   2dup = if 2drop exit then
   begin
     cr dup @ dup 5 rshift 7 .r  $1f and 3 .r
     1 cells + dup @ count space type
     1 cells + 2dup =
   until
   drop symtable - 2 cells / cr . ."  symbols" ;

                           
: .x   \ display a core on a line
   ."  node=" node @ 2.u
   ."  pc=" pc @ 3.u
   ."  iw=" iw @ 5.u
   ."  slot=" slot @ 1 .r
   ."  s="   s @ 5.u
   ."  t="   t @ 5.u
   ."  r="   r @ 5.u
   ."  b="   b @ 5.u
   ."  a="   a @ 5.u
   space .opcode ;
                          
$5 value /column

: .node#  ( -- )   node @  base @ >r  decimal  2.u  r> base ! ;

: .columnop ( -- )
   (.opcode)
   /column over - 0 max  ( addr len #spaces )
   >r  type r> spaces
;

: .step  ( n1 -- n1 )   dup  base @ >r  decimal  4 u.r  r> base !  space ;

variable visible-nodes
-1 visible-nodes !

: show-node ( n -- )   \ set bit n in visible-nodes
   1 swap lshift  visible-nodes @  or  visible-nodes !
;
: -show-node ( n -- )   \ clear bit n in visible-nodes
   1 swap lshift  invert  visible-nodes @  and  visible-nodes !
;

: show-node? ( n -- flag) \ return bit n from visible-nodes
   1 swap lshift  visible-nodes @  and
;

: .visible-nodes #nodes 1+  0 do i show-node? if i . then loop ;

: ?bright   rest @ -1 = if  normal  else  bright  then ;

: .coreline ( -- )
   #nodes  0 do 
      i show-node? if  i node!  ?bright .columnop  then
   loop
;

$08 constant /x  \ was $14
$09 constant /y  \ was $0a
\ $18 constant y-off
/y 1- #rows * constant y-off
$1b constant y-off

: >xy ( node -- x y ) 
   #cols /mod  swap /x *  swap /y *  y-off swap - 
;

: .2d-reg ( reg $ offset -- )
   node @ >xy +  at-xy  type  ." = "  ?
;

: >node-xy ( n -- x y )
   node @  >xy  rot +  at-xy
;
variable next-nodeline  0 next-nodeline !

: +nodeline ( -- ) \ compile refs to >node-xy, inc y each time.
   next-nodeline @  postpone literal  
   1 next-nodeline +!
   postpone >node-xy
; immediate

: .creg7 ( addr -- )   @  7 u.r ;
: .creg5 ( addr -- )   @  5.u ;
: .creg3 ( addr -- )   @  $1ff and 3.u ;

: ."|"   rest @  case
      3 of  ." |"  endof
      2 of  ." :"  endof
      1 of  ." ."  endof
      -1 of  ." *" endof
     space
   endcase ;

: .2d-op ( -- )
   base @ hex
   +nodeline  .node#
   +nodeline  slot @ 1 u.r  ."|" .columnop
   +nodeline  ." a=" a @ 5.u
   +nodeline  ."   b=" b  .creg3 
   +nodeline  ."   p=" pc .creg3		
   +nodeline  ." r=" r  .creg5 
   +nodeline  ." t=" t  .creg5
   +nodeline  ." s=" s  .creg5 
   base !
;
: np?   5 1 do  i port !  local ? other remote ?  
   other space timer remains .  space space loop ;
: anp?   cr $18 0 do ." N" i . i node! np? space  rest ?  space space  cr loop ;

: .ns   base @  decimal  ." time = " @ns .  base !  .s  ( anp?) ;

: .2d-cores ( -- )
   #nodes 0 do 
      i show-node? if  i node !  ?bright  .2d-op  then
   loop
   0 >xy next-nodeline @  +  at-xy
   normal .ns  ( .slog)
;

: .cores ( n1 -- n2 )
   cr .coreline cr   \ display 1, then, step+display
   begin
   key $20 = while
      step  .coreline cr
   repeat
;

: .core-loop ( -- )
\   set-short-display
   cr .coreline cr   \ display 1, then, step+display
   begin
   key? 0= while
      step  .coreline cr
   repeat
;

1 value max-cnt
: max-cnts? ( -- flag ) 
   max-cnt ?dup if  @ns > 0=  else  false  then
;
: go2d ( n1 -- n2 )
   postpone host
   page  bright .2d-cores    \ display 1, then, step+display
   begin
      max-cnt if  
         max-cnts?  key? or  0=
      else
         key? 0=
      then 
   while
      step  .2d-cores
   repeat
   begin
      key $20 = 
   while
      step  .2d-cores
   repeat
;

: go 
   begin
     #nodes 0 do  i node!  cr .x  loop
     .ns     
     key $20 = while
     step
   repeat ;

: go+ 
   begin
     #nodes 0 do  i node!  cr .x  loop
     .ns     
   key? 0= while  step  repeat
   key drop
;
