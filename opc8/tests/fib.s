# Simple Fibonacci number program ported from earlier machines
MACRO   CLC()
        c.add r0,r0
ENDMACRO

MACRO   PUSH( _data_)
        sto     _data_, r14
        mov    r14, r14, 0xffffff
ENDMACRO

MACRO   POP( _data_ )
        mov    r14, r14, 0x01
        ld     _data_, r14
ENDMACRO
        
MACRO   SEC()
        nc.ror     r0,r0,1
ENDMACRO

MACRO   ASL( _reg_ )
        add     _reg_, _reg_
ENDMACRO

MACRO   ROL( _reg_ )
        rol   _reg_, _reg_
ENDMACRO

MACRO   RTS ()
        mov     pc,r13
ENDMACRO

        ORG 0x0000
        lmov    r10,r0,RSLTS      # initialise the results pointer
        lmov    r14,r0,RETSTK     # initialise the return address stack
        mov     r5,r0             # Seed fibonacci numbers in r5,r6
        mov     r6,r0,1

        sto     r5,r10            # save r5 and r6 as first resultson results stack
        sto     r6,r10,1
        add     r10,r0,2

        mov     r4,r0,-10         # set up a counter in R4
        lmov    r8,r0,FIB
LOOP:   jsr     r13,r8
CONT:   add     r4,r0,1          # inc loop counter
        nz.sub  pc,r0,PC-LOOP    # another iteration if not zero

END:    halt    r0,r0,00         # Finish simulation


FIB:    PUSH (r13,r14)           # Push return address on stack

        mov     r2,r5            # Fibonacci computation
        add     r2,r6
        sto     r2,r10           # Push result in results stack
        add     r10,r0,1         # incrementing stack pointer

        mov     r5,r6            # Prepare r5,r6 for next iteration
        mov     r6,r2

        POP     (pc,r14)         # and return

        ORG 0x100

# 8 deep return address stack and stack pointer
RETSTK: WORD 0,0,0,0,0,0,0,0

# stack for results with stack pointer
RSLTS:  WORD 0