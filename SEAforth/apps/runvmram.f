\ Load and run the VM app in RAM
\ This is intended to show move data from node to node to demonstrate
\ breaking a serial algorithm into parallel pieces.
\ It is not intended to implement anything particularly mathamatically interesting.
\ The data flow is:
\ create data samples
\ send to a node 
\ pass to the next node
\ calculate the difference in the last two samples
\ make a running average of the differences
\ ( Subsequent versions will add some random noise to be filtered out )

include ../t18/compatibility.f
cd ../t18
include t18x.f       \ load compiler and simulator
cd ../bios
decimal
include rombios.mf   \ 1/24/06 load ROM BIOS code
hex
init

\ ******* node 12  sp-data ***************************************
decimal

12 node!  
$0 org  
machine

: send-data
   'r--- a! . .   \ point reg a to right node
   begin
      31 for
         @p+ !a . unext
         [  0 ,  8 , 16 , 24 , 32 ,  40 ,  48 ,  56 , 
           64 , 72 , 80 , 88 , 96 , 104 , 112 , 120 ,
          128 , 136 , 144 , 152 , 160 , 168 , 176 , 184 , 
          192 , 200 , 208 , 216 , 224 , 232 , 240 , 248 , ]
   again
[

\ ******* node 13 *********************************************
\ pass the data stream through
\ just to show how to pass it through.

decimal
13 node !  
0 org  
machine

'r---  a! . .  \ point reg a to right node
'--l-  b! . .  \ point reg b to left node

\ read right neighbor, pass data on to left neighbor
begin
   $3ffff for 
   @a !b . unext
again
[

\ ******* node 14 *********************************************
\ differentiator
\ pass "difference" between current and previous to the next node

decimal
14 node !
0 org  
machine

'--l-  a! . .   \ point reg a to left node
'r---  b! . .   \ point reg b to right node
dup xor         \ init t to zero
begin  
  @a over over .  ( curr prev curr )
  + not ( curr curr-prev )  !b .  ( curr ) \ will become prev
  4  drop . .
again  
[

\ ******* node 15 *********************************************
\ Moving average filter
\ Average of last 8 words from port.
\ We need three registers. One to point to the right neighbor,
\ ( for reading data ), one to point to the left neighbor ( for
\ writing data ) and one to point to a memory array for calulating.
\ Reg a will point to memory, and auto increment.
\ Reg b will point the both the left and right ports.
\ When the read is done using b , the node will attempt to read both
\ the left and right ports. We will make sure that data is present
\ on the right port, and not on the left port.
\ When the write is done using b, the node will attempt to write
\ to both the left and right ports. We will make sure that only the
\ left neighbor is reading, and the right neighbor is not writing.

decimal
15 node !
0 org  
machine

\ 'r-l-  b! . .     \ point reg b to right and left nodes
$1f5 b! . .         \ $1f5 points to the left and right ports
$20 a! . .          \ start of ram array
dup xor             \ init t to zero

\ now do running average; subract oldest, add newest
begin
  $20 a! . .       \ return to start of ram
  $4 for           \ for length of array
    @a over not .  \ get oldest value, start -
    + not @b dup   \ finish - from running total, @ from right
    !a+ . + dup    \ save new val, & accumulate it
    !b next        \ store to left port
again
[

\ ******* Node 16 *********************************************
\ Catch data and store in a buffer

decimal
16 node!
32 org  \ start compiling at address 32. data will be at 0
machine
: catch-data
   '--l- b! . .                   \ point reg b to left node
   31 dup a! dup
   begin
     a@ and a! dup
     @b !a+
   again
[ $aa org ] catch-data -;

[
0 to bootadr  \ these sample programs run from RAM at zero
decimal
: myinit
   16 12 do i node!  initnode  loop ;
myinit

\ The other examples here load to simulated RAM and run from 
\ the simulated RAM. Node 16 uses the simulator to change the
\ content of the simulated ROM so that the reset vector contains
\ a jump to this code. 
16 node!  $aa to bootadr  initnode
host
