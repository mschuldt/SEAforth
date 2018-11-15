\ Error log capture for Simulator
decimal
\ During a given "step" a program may cause a log to be created.
\ During the processing of the step, log entries are saved in a table.
\ At the end of the step log entries are displayed, (if they meet a criterion),
\ Then all log entries for that step are written to a log file.

\ Make a Defining word for creating log words.

\ ( log-level $ ) logger <name>
\ When invoked create a word which contains the above strings.
\ The behavior of the child word is to write a log entry to the step-log-table 
\ The step-log-table is called slog
\ At the end of each step the Step-log-table is processed (display and write to file).

\ step-log-table
\ During the processing of one "step", a table is maintained containing all error-log
\ records associated with that step. Each log record will contain:

\ log format: global-ns, node, port, '(Severity-number, String)
\ '(Severity-number, String) is a pointer to the body of the child word,
\ where the severity level and the string can be found.

\ Make the step log an array of fixed length entries in a pre-allocated area.
\ The pre-allocation is to allow easy and safe re-use.
\ Invoke resetSlog at the beginning of each step to reset the pointer.
\ The table is not cleared because the pointer indicates the end.

\ test support words

: field ( a n - a+n)   over constant  + 
   does> @ + ;

0 
4 field >time
4 field >node 
4 field >port
4 field >level
constant /slog

$8000 constant max-entries
max-entries /slog * constant /slogs
variable 'slog
create slog  /slogs allot  \ 1st pass at table size

variable step-errs  0 step-errs !
variable total-errs  0 total-errs !

: reset-slog ( - )   slog 'slog !  0 step-errs ! ;
reset-slog

: logfull? ( - flag )   'slog @  slog /slogs +  >= ;

: add-log ( addr - ) 
   logfull? abort" Simulator Error Log Full"
   'slog @  @ns over >time !  node @ over >node !
   port @ over >port !  >level !  
   /slog 'slog +!  1 step-errs +!  1 total-errs +!
;

: logger ( n $) \ <log-name>
   create  rot ,  dup c,  here over allot  swap move
   does> add-log ;
: -logr   logger  does> ( n)   add-log drop ; \ do drop for use in port machine

: "levels ( - a)   s" Dead!DangrWarngCautnInfo:Zzz.." drop ;
: "ports ( - a)   s"  rdlusm " drop ;
: .log-entry ( a)   dup >level @  dup cell+ >r
   @ 5 * "levels + 5 type  ."  @" dup >time ?
   ." n" dup >node @ 0 u.r  >port @  dup "ports + 1 type
   if space  then r> count type ;

: .slog ( - )
   cr ." Total Error logs: " total-errs ?
   cr ." Error logs in this step: " step-errs ?  cr
   'slog @ slog ?do 
      i .log-entry cr
   /slog +loop
;

reset-slog

: replace-file ( addr size c-adr len -- ) cr ." saving " 2dup type space
   R/W CREATE-FILE          ( a u fid ior)  abort" open failed"
   >R 0 0 R@ REPOSITION-FILE  ( a u ior)  abort" reposition failed"
   R@ WRITE-FILE                  ( ior)  abort" write failed"
   R> CLOSE-FILE                  ( ior)  abort" close failed"
;

: savelog-raw ( - )   
   slog 'slog @  slog -   
   s" ../testdata/slog.bin"  replace-file ;

0 value lfid ( log file handle)

: $>file ( $ - )   lfid WRITE-FILE  abort" write failed" ;
: (.) ( n - $ )   dup abs 0  <# #s rot sign #> ;

: fspace ( n - )   s"  " $>file ;
: .f ( n - )   (.)  $>file ;   \ print n to file 

create 'cr  $0a c,

: fcr ( - )   'cr 1 $>file ;

: .f-log-entry ( a1 - ) 
   s" log level: "  $>file  fspace  dup >level @ dup @ .f ( a1 'level )  
   s" '" $>file  cell+ count $>file  s" '" $>file  fspace fspace ( a1)
   s" ns: " $>file  dup >time @ .f  fspace
   s" node: " $>file  dup >node @ .f  fspace
   s" port: " $>file  >port @ .f  fcr
;

: savelog ( - )
   s" ../testdata/slog.txt"
   R/W CREATE-FILE          ( a u fid ior)  abort" open failed"
   to lfid
   0 0 lfid REPOSITION-FILE  ( a u ior)  abort" reposition failed"
   s" Total Error logs: "  $>file
   total-errs @ .f  fcr
   s" Error logs in this step: "  $>file 
   step-errs @  .f fcr
   'slog @ slog ?do 
      i .f-log-entry
   /slog +loop
;

0 [if]  \ Examples:

4 s" bad hair day" logger hair
3 s" dentist appt" logger ouch
2 s" root canal" logger cj
1 s" double bypass" logger McD
23 node !  0 port !
hair
ouch
hair
cj
McD
1 node!  5 port !
500 2* time +!
cj
1 port !
Mcd
4 port !
hair
6 port !
hair
.slog
\ hair causes a level 4 " bad hair day" log to be created containing the
\ current values of ns node and port. step err cnt and tot err cnt increment.

[then]
