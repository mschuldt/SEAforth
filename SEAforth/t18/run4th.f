( run4th.f ) \ user-modifiable file to load forth simulator and application
decimal

0 [if] \ -----------------------------------------------------------------------

  This file assumes it is loaded while in the .../t18
directory.  All directory changes and file operations are done relative to that
directory.

[then] \ =======================================================================

include ../t18/compatibility.f
cd ../t18
include t18x.f       \ load compiler and simulator

cd ../bios
include rombios.mf   \ 1/24/06 load ROM BIOS code

\ use some testbed words to set up the Forth simulation environment

\ nospiboot          \ to put + on data in on spi to prevent spi boot

\ ---------------- include application code and forthlets here -----------------
\ cd ../apps

\ ================ end with optional boot forthlet at 0 in xram ================

hex
cd ../t18            

cr .( T18 Simulation Environment loaded )
init                 \ initialize the t18 simulator

\ init-serial   \ needed for serial sim
