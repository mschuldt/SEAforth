forth definitions

[defined] cd 0= [IF] [defined] fpath= [IF] : cd fpath= ; [ELSE] abort [THEN] [THEN]
[defined] bold    0= [IF] : bold    27 emit ." [1m" ;     [THEN]
[defined] bright  0= [IF] : bright  27 emit ." [41;37m" ; [THEN]
[defined] normal  0= [IF] : normal  27 emit ." [0m" ;     [THEN]
[defined] inverse 0= [IF] : inverse 27 emit ." [7m" ;     [THEN]
