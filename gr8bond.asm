.text
ci $r0, 0x0001
ci $r1, 0x0101
ci $r2, 0x0001
ci $r3, 0x0001
ci $r4, 0x1100
ci $r5, 0x0011
ii2pp $r0
ii2pp $r2
pp2ii $r0
pp2f $r2
i2f $r0
f2i $r2
f2pp $r2
pp2ii $r2
trap
