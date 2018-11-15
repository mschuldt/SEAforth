( $Id: t18.f,v 1.19.2.21 2006-09-23 05:27:32 randy Exp $ )

\ T18 compiler
decimal

: org ( adr)   dup h !  ip !  0 slot ! ;

0 org

\ part of the initialization is in init and part in clear
\ clear clears memory and regs before compiling
\ init is used after compilation before simulation

: clear   0 org
   symtable *symbol !  symarray sym* !
   #nodes 0 do  i node !
      registers ram/rom do   \ "clear" memory only, not regs
         $15555 i !  cell +loop
   loop  0 node ! ;
clear

: here ( - ta)   h @ ;
: realign   here 1 +adr org ;         \ move h & ip to next word
: align   slot @ if  realign then ;   \ already aligned if in slot 0!

: nodebad? ( n - f )   #nodes u<  0= ;
: node! ( n -- )   \ set node and associated state
   0 to global-search
   dup nodebad? abort" Node number must be bettween 0 and #nodes"
   node !  @node-wid set-current ;

: .node! ( n -- )   \ set node and display
   dup node!  . ( $d emit  ."  compiling node "  .  cr) ;

: n>port   ( n -- port )  or  5 xor   4 lshift $105 or ;      \ 1d5 or 175

: 'east ( node - port ) \ return port addr of east node
   dup  1 and  1 xor  3 lshift  \  8 if odd
   swap  1 and 2*               \  2 if even
   n>port
;

: 'west ( node - port ) \ return port addr of west node
   dup  1 and    3 lshift      \  8 if even
   swap  1 and 1 xor  2*       \  2 if odd
   n>port
;
 
: 'north ( node - port )   
   #cols /  
   dup  1 and  1 xor  2* 2*
   swap  1 and
   n>port ;

: 'south ( node - port )   
   #cols /  
   dup  1 and  2* 2*
   swap  1 and  1 xor
   n>port ;

: ntest ( - )   cr  #nodes 1+  0 do  decimal i .  hex i 'north . cr loop ;
: stest ( - )   cr  #nodes 1+  0 do  decimal i .  hex i 'south . cr loop ;

\ ************************************************************
\       assembler words start here
\       The assembling state is now called target

0 node !
target               \ target host forth   def: target

\ m! is an assembler word now and belongs with the first assembler word
\ in this file -  which is  ,
: m@ ( a -- n )   ta @ ;
: m! ( n a -- )   swap $3ffff and  swap ta ! ;

: , ( n -- )
   slot @ if                        \ not slot 0: inc h before storing lit
      here 1 +adr  dup h !  m!      \ phase 3 uses flag with @!
   else
      here m! realign               \ slot 0: inc h & ip after storing lit
   then ;

: s0 ( op -- op' )   $3e000 and ;     \ mask out opcode bits in other slots
: s1 ( op -- op' )   $01f00 and ;
: s2 ( op -- op' )   $000f8 and ;
: s3 ( op -- op' )
   dup $18 and $10 = if      \ if bottom 2 bits in slot 2 are 10, the opcode will go into slot 3
      7 and exit then        \ just use the 3 bits from the opcode
   ip @ m@ 2 or              \ doesn't go: top 3 bits of nop opcode in slot 3
   ip @ m! realign s0 ;      \ store nop in slot 3, go on to next word

: i! ( op -- )
   slot @ case
     0 of s0 endof
     1 of s1 endof
     2 of s2 endof
     3 of s3 endof
   endcase
   slot @ if                 \ will have changed if opcode doesn't fit in slot 3
     ip @ m@ or
   then ( op )
   ip @ m! ;                 \ clears out rest of opcode in slot 0

: nexti ( -- )
   slot @ 3 = if                   \ slots 0-3 for compiling, advance on last slot
     realign exit                  \ exit 4.02?
   then
   1 slot +! ;

: i, ( op -- ) i! nexti ;

: nop ( -- ) $2c9b2 i, ;               \ 1c 39ce7p

: nops ( -- )
   begin slot @ while nop repeat ;     \ pad with nop

: branch ( op -- ip.slot h )            \ leave src to resolve
   c18-optimize  0= if  slot @ 1 > if nops then  then
   i! ip @ 2* 2* slot @ or
   nexti realign here ;

forth
false value verbose-resolve 
\ true to verbose-resolve
target

: resolve ( dest ip.slot h -- )         \ resolve branch or err
   verbose-resolve  forth  if cr ." resolve 1 " .s order then  target
   over 2/ 2/ ta >r >r                  \ dest ip.slot         h aip (absolute ip)
   3 and case                           \ dest slot            h aip
     0 of $00000 endof
     1 of $01f00 endof
     2 of $01ff8 endof
   endcase ( dest mask)
   2dup and  over r> and xor            \ dest mask dest&mask mask&h
   abort" branch/call op & dest not on same page"
   invert and r@ @ or r> ! 
   verbose-resolve  forth  if cr ." resolve 2" .s order then target
;

host
variable calledadr
variable calledslot

target

: ,east ( - )   node @  'east  , ;
: ,west ( - )   node @  'west  , ;
: ,north ( - )   node @  'north  , ;
: ,south ( - )   node @  'south  , ;
 
: -; ( -- )                            \ explicit tail recursion
   calledadr @ ta dup @ ( a opcode )   \ 4.06 last call compiled at calladr
   calledslot @ ?dup if
     1 xor if
       $00008 or                       \ s2   7.00 change
     else
       $3feff and                      \ s1
     then
   else
       $02000 or                       \ s0
   then swap !                         \ change call to jump
;

\ : t; ( -- ) $15555 i, nops ;        \ 0p opcode fills slots after ; with nops

: call ( dest -- )
   slot @ ?dup if
      over $1f00 and                  \ adr bits 12-8, or
      over 3 = or if                  \  slot 3 calls, move to slot 0
         drop nops
      else                            \ only to memory in slots 1 & 2
         2 xor if
            $3ff00                    \ s1  8-bit simulator page
         else
            $3fff8                    \ s2  3-bit hardware page
         then
         2dup and  swap here 1 +adr and  xor if
            nops                          \ force slot 0 if not same page as pc
         then
      then
   then
   slot @ calledslot !                 \ 4.06
   ip @ calledadr !                    \ 4.06 -; fix
   $11745 branch resolve ;             \  2 4210p

: unext  ( dest -- )                   \ 6.00 addition
   slot @ 3 xor abort" unext must be in slot 3"
   $1d174 i, drop ;         \  4 08421p
: zif   ( ip.slot h )   $1d174 branch ;
: next   ( dest -- )   zif resolve ;  \  4 08421p

: jump   ( -- ip.s h ) $1364d branch ; \  3 06318p
: if     ( -- ip.s h ) $19364 branch ; \  6 0c631p
: -if    ( -- ip.s h ) $1b26c branch ; \  7 0e739p

: while  ( dest -- dest ip.s h ) if ;
: -while ( dest -- dest ip.s h ) -if ;

: begin  ( -- dest )             nops here ;
: then   ( ip.s h -- )           begin -rot resolve ;
: else   ( ip.s h -- ip.s' h' )  jump 2swap then ;

: until  ( dest -- )             if   resolve ;
: -until ( dest -- )             -if  resolve ;
: again  ( dest -- )             jump resolve ;
: repeat ( dest ip.s h -- )      else resolve ;

: exit ( -- ) $15555 i, ;
: @p+  ( -- ) $05d17 i, ;              \  8 10842p
: @a+  ( -- ) $07c1f i, ;              \  9 1294ap
: @b   ( -- ) $01f07 i, ;              \  a 14a52p
: @a   ( -- ) $03e0f i, ;              \  b 16b5ap

: !p+  ( -- ) $0d936 i, ;              \  c 18c63p 00 1101 1001 0011 0110   00110 11001 00110 110..
: !a+  ( -- ) $0f83e i, ;              \  d 1ad6bp                                  19
: !b   ( -- ) $09b22 i, ;              \  e 1ce77p
: !a   ( -- ) $0ba2e i, ;              \  f 1ef7bp

: +*   ( -- ) $345d1 i, ;              \ 10 21084p
: 2*   ( -- ) $364d9 i, ;              \ 11 2318cp
: 2/   ( -- ) $307c1 i, ;              \ 12 25294p
: not  ( -- ) $326c9 i, ;              \ 13 2739cp

: +    ( -- ) $3c1f0 i, ;              \ 14 294a5p
: and  ( -- ) $3e0f8 i, ;              \ 15
: xor  ( -- ) $383e0 i, ;              \ 16 2d6b5p
: drop ( -- ) $3a2e8 i, ;              \ 17 2f7bdp

: dup  ( -- ) $24d93 i, ;              \ 18 318c6p
: pop  ( -- ) $26c9b i, ;              \ 19 339cep
: over ( -- ) $20f83 i, ;              \ 1a 35ad6p
: a@   ( -- ) $22e8b i, ;              \ 1b 37bdep

: .    ( -- ) $2c9b2 i, ;              \ 1c 39ce7p
: push ( -- ) $2e8ba i, ;              \ 1d 3bdefp
: b!   ( -- ) $28ba2 i, ;              \ 1e 3def7p
: a!   ( -- ) $2aaaa i, ;              \ 1f 3ffffp

: for    ( -- dest )    push begin ;

\ replaced previous names

: n    ( -- ) $05d17 i, ;              \  8 10842p
: !+   ( -- ) $0f83e i, ;              \  d 1ad6bp

\ Most assembler (target) words are done. 

forth
: [[ ( -- )   postpone [ ; immediate 
: ]] ( -- )   ] ;

\ ******************* host ****************************************
host

: +node ( a -- a.n )           \ combine node and address for table lookup
   $1fff and  node @ global-search or  13 lshift or ;

: (symbol?) ( a -- c-adr len )   \ symbol lookup; not found if len = 0
   +node >r                    \ combine t-a and node
   symtable *symbol @
   begin 2dup xor while        \ search symbol table backwards for node address
     2 cells -
     dup @ r@ = if
       nip r> drop
       1 cells + @ count exit
     then
   repeat
   2drop r> drop s" " ;

: symbol? ( a -- c-adr len )
   dup (symbol?) ?dup if rot drop exit else drop then
   global-search >r  -1 to global-search (symbol?)  r> to global-search ;

: sym!+ ( n -- )                    \ store symbol table entry and incr pointer
   *symbol @ ! 1 cells *symbol +! ;

: name, ( -<name>- )                \ copy name to symbol array
   >in @ >r
   bl parse ( name-a len )
   sym* @ 2dup + 1+ sym* ! ( name-a len array-a )
   2dup c! 1+ swap cmove            \ copy to symarray
   r> >in ! ;

: symbol, ( a - ) \ <name>
   dup +node  sym!+                 \ [0] target address and node combined
   sym* @ sym!+                     \ [1] address of name string in symarray
   name,                            \ add <name> to symbol table
   create , ;                       \ created word with t-a stored at pfa

\ Check fwd references.
\ return true if already defined, else false. abort if defined word does
\ not return the current here
: fwd? ( -- flag  )  \ -<name>-   
   get-order
   global-search if  (global-node) 1  else  0  then
   @node-wid swap 1+  set-order
   bl word find if 
       >body @  here 
         2dup <>  if 
            .s abort" fwd reference to bad address"
         else 
            2drop
         then
      true
   else
      drop false
   then
   >r  set-order  r>
;

: fwd ( a ) \ -<name>-              \ define absolute forward reference calls
   get-current swap over  ( cur n cur )
   (global-node) <> if  @node-wid set-current  then
   >in @  >r  fwd? if  r> 2drop  set-current exit  then
   r> >in !  symbol,  set-current
   does> @  target call  host ;

target 
: fwd ( a ) \ -<name>-
   host fwd ;

: equ ( n ) \ -<name>-                   \ define named non-address literals
   fwd  does> @
   target  @p+ ,  host
;

target
: equ ( n )   host equ ;  \ -<name>-

: +fwd ( n ) \ -<name>-   \ define relative forward reference calls
   here +  fwd ;

target
: +fwd ( n )   host +fwd ;  \ -<name>-

target
: create ( - ) \ -<name>-           \ define named address compiling words
   here equ ;                       \ compile lit and literal value

host
: allot ( n -- )
   here swap +adr org ;                   \ also sets slot 0   adr & org are now in host

: fill ( data adr count -- )
   over + swap do dup i ta ! loop
   drop ;

: erase ( adr count -- )
   0 rot rot fill ;

: t' ( -<name>- adr )               \ return target address of called word
   postpone compiling
   ['] ' catch 
   postpone c18  throw 
   >body @ ;

: ?setbase ( addr len -- addr' len' )
   over c@ [char] $ =  if  1- swap 1+ swap  hex  then
;

: ?neg ( addr len -- addr' len' neg? )
   over c@ [char] - =  if
      1- swap 1+ swap  true  
   else  
     false
   then
;

: number ( cnted$ - n ) \ convert to unsigned single or abort
   base @ >r
   count       ( addr len )
   ?neg  -rot  ( neg?  addr len)
   ?setbase 
   0 0 2swap  >number            ( neg?  ud addr #unconverted )
   r> base !
   ?dup abort" ?"                ( neg?  ud addr )
   drop  abort" Number conversion overflow"               \ abort if double
   swap if negate  $3ffff and  then
;

\ for testing the number words
: num-test  ( -- n ) bl word find if ." xt = " . else number then ;

0 [if]
 *************** target *******************************************
  create target versions of   :   ;  ] [

  Consider this system to have 5 Modes, or States.
  Forth   Host  C18 target and compiling
  These states are implemented in terms of wordlists.

  The individual wordlists are:  
     forth-wordlist  (c18) (host) target) and (global-node)
  There are also 24 (i.e. #-of-nodes) unnamed wordlists into which
  node specific definitions go.

  A given state is entered by calling a word which sets a search order
  consisting of a collection of these wordlists.

  There is a special wordlist called the (global-node)  wordlist.
  It contains definitions which will be common to all targets (such as equates
  that are used to specify port addresses). These will be visible during compilation,
  and identical for all nodes. There are no target-executable defs in the 
  (global-node) wordlist. In rombios.mf where we want to place a group of equ's
  into the global node, we invoke global-node. machine-forth is not invoked until
  after these equ's have been created. 

  There is a variable called node which is used to select the node to which we are
  compiling.  This varible is tyically set with the word node! ( node -- )
  or with  .node! ( node -- ) which calls node!

  node! will set node, and cause new definitions to be entered into the 
  node-specific wordlist.

  Whenever compiling is invoked, the wordlist associated with the current node will
  be added to the search-order, in a position subordinate to (target).

  If the node number passed to node! is -1 then node! will place the global-target-node
  in the search-order and select it for definitions.
  
The words  forth  c18  host  target compiling  and global-node invoke search-orders.

  forth  yields:    forth              Def: forth
  host   yields:    host forth         Def: host
  C18    yields:    C18 host forth     Def: c18
  target yields:    target host forth  Def:target
  global-node yeilds: forth-wordlist (host) (target) (global-node)
  compiling yields: target current-node global-node   Def: current-node

  In C18, The word  ]  starts a compiling loop.
  It is intended that within the context of loading a machine-forth file, 
  (i.e. with the suffix  .mf ) the compiler loop ( meaning ] ) will be the
  normal state. 
  Each machineForth file will need to enter C18 in order to find the c18 ]
  and then invoke it.
  The word machine-forth has been provided to accomplish both of these tasks.
  A .mf file will typically start with the word machine-forth and end with the
  word [
  
  ]
    ] is a compiling loop, and switches to compiling mode. It runs
    forever, until [ or abort  breaks out of the loop.
    It sets definitions to the node-specific wordlist of the
    current node. ] finds and executes words, and make 
    literals from numbers.

  [
    [ exits the compiling loop and returns to c18 mode. This is for things 
    like compile time stack manipulation;   [ swap ]
    Note that  ] returns to compiling.
    Things like 1 +fwd allow the 1 to be in brackets.
    [ 1 ] +fwd fred
    alternatively the whole phrase may be in brackets.
    [ 1 +fwd fred ]

    groups of bracketed phrases may be combined.
    [ $0b2  equ NSEW
      $000  fwd ram0 ]   

    The node selection phrase  should be enclose in square brackets.
    [ 1 .node! ]

  :
    After entering compiling mode ( using ] ) there is a new version of :
    This : just creates a label. It is ] that does the
    compiling. Since : just makes a label, multiple entry points can be
    created using :

  Literals
    Literals are automatically created by ]
    The literals are signed single precision, and may be prefaced with
    a juxtaposed $ or - .  $ for hex, or - for negative.
    Literals are truncated to 18 bits by the target version of ,
    Literals which overflow 1 host cell will abort.
    This ought to change to aborting on 18bit overflow.
    [ 5 ]#  may now be expresses as just   5   within a : definition.
    [ 5 ]# still works, but this form will typically only be used when
    some compile-time operation is needed.
    e.g.   [ route EAST 2 's x0 >njump order ]#

  ]#
    ]# creates a target literal and calls ]
    Using ]# compiles @p+ to return the literal to the stack
    at runtime.
    [ route EAST 2 's x0 >njump ]#  
    Is an example of performing run time work and making a literal
    with the result.

  ], Like ]#, but instead of making a literal, which will return to the
     target stack at runtime, ], uses the target version of , to place the
     number into the target space, and the return to compiling (  e.g. ] )

  's
    N 's <name>  
    retrieves the address of <name> in the context of node N. e.g.
    2 's x0     retrieves the address of x0 from node 2.
    's needs to be used between [  and  ]

  ; and -;
    ; compiles exit, and performs nops to fill the remaining slots in the
    current word with noops.
    -; converts the last call to a jump. 
    Neither exit the compiling loop. 
    ; or -;  may  be used in the middle of a word to  create mutiple 
    run-time exit points.  

[then]

target 
: [  ( -- )   postpone c18  forth  r> drop ;  \   ] resumes compiling
target
: } ( -- )   postpone c18  forth  r> drop ;
target
: }machine ( -- )   postpone c18  forth  r> drop ;

target

: ; ( -- )                          \ and lastly define ; for assembler wordlist
   exit nops  ;      \  0 00000p   

\ Preserve the following forth words in target
: \ ( -- )   forth postpone \ ;  immediate 
target

: ( ( -- )   forth postpone ( ; immediate 
target

: [if]  forth  postpone [if] ; immediate
target

: [else] ( -- ) forth  postpone [else] ; immediate
target
: [then] ( -- ) forth  postpone [then] ; immediate

target

: : ( -<name>- )                    \ now we can define : for assembler wordlist
   nops 0 +fwd  forth ;

\ *********************** c18 ************************************
\ All entries into compiling mode will funnel through ] which  
\ will catch the compiling word ( do-] ) and return to c18
\ [ is the normal exit from the compiling loop

c18

\ make C18 ' and ,  use the target versions
: ' ( -- addr )  t' ;
: , ( u -- )  target , c18 ;
   
\ This is the c18 ]   search-order = c18 host forth  def:= c18

: do-]
   postpone compiling
   begin
      bl word  dup c@ 0= if 
            drop refill  0= abort" Error refilling input stream"
      else
         find  if  
            execute 
         else
            number  target  @p+ ,  c18 
         then
      then
   again
;

: ] ( -- )   ['] do-] catch  postpone c18  throw ;
: ]# ( u -- )   target  @p+ ,  c18 ]  ;   \ lit w/target @p+ , resume ]
: ], ( u -- )   target  ,  c18 ]  ;       \ compile number w/target , resume ]

\ Bury the following forth words while in C18
: [ ( -- )   ." ******* using [ from C18 state " ;

forth
\ Three alternatives to consider
: machine-forth ( -- )  postpone c18  c18 ] ;  \ enter compiling state from forth
forth
: machine ( -- )  postpone c18  c18 ] ;  \ enter compiling state from forth
forth
: machine{ ( -- )  postpone c18  c18 ] ;  \ enter compiling state from forth
host


