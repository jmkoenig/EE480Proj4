.text
ci $r0, 0x0001
ci $r1, 0x0001
ci $r2, 0x0000
ci $r3, 0x1010
ci $r4, 0x1100
ci $r5, 0x0011
ii2pp $r0
dup $r1, $r0
pp2ii $r0
pp2f $r1
f2i $r1
f2pp $r1
pp2ii $r1
trap
