.text
ci8 $r0, 0x01;	Prime the registers
ci8 $r2, 0x90
cup $r2, 0x90
ci8 $r3, 0xa0
ci8 $r4, 0xb0
ci8 $r5, 0xc0
ci8 $r6, 0xd0
ci8 $r7, 0xe0
ci8 $r8, 0xf0
ci8 $r9, 0x00
ci8 $r10, 0x00

muli $r0, $r0;		Test the registers
muli $r2, $r0
;addi $r3, $r0
;addi $r4, $r0
;addi $r5, $r0
;addi $r6, $r0
;addi $r7, $r0
;addi $r8, $r0
;addi $r9, $r0
;addi $r10, $r0

trap
