#
# Program to generate Pi using the Spigot Algorithm from
#
# http://web.archive.org/web/20110716080608/http://www.mathpropress.com/stan/bibliography/spigot.pdf
#
#

MACRO   CLC()
        c.add r0,r0
ENDMACRO

MACRO   SEC()
        nc.ror     r0,r0,1
ENDMACRO

MACRO   ASL( _reg_ )
        add     _reg_, _reg_
ENDMACRO

MACRO   ROL( _reg_ )
        adc     _reg_, _reg_
ENDMACRO

MACRO   RTS ()
        mov     pc,r13
ENDMACRO


MACRO   SINGLE_DIGIT_CORRECTION()
        # r11 = Q
        # r8  = mypi pointer (pointing at next free digit)
        # r2 = predigit pointer
        # r1 = temp store/predigit value
        cmp     r11,r0,10               # check if Q==10 and needing correction?
        nz.sto  r11,r8                  # Save digit if Q <10
        nz.inc  pc,SDCL5-PC             # if no correction needed then continue else start corrections
        sto     r0,r8                   # overwrite 0 if Q=10
        ld      r1,r8,-1                # get predigit
        inc     r1,1                    # increment it
        cmp     r1,r0,10                # is it 10 ?
        z.mov   r1,r0                   # zero it if yes (preserve Z)
        sto     r1,r8,-1                # store it

SDCL5:  inc     r8,1                    # incr pi digit pointer
        ld      r1,r8,-2                # Get digit 2 places back from latest
        jsr     r13,r0,oswrdig          # Print it

SDCL6:  dec     r9,1                    # dec loop counter
        nz.mov  pc,r0,L3                # jump back into main program
        # empty the buffer

SDCL7:  ld      r1,r8,-1
        jsr     r13,r0,oswrdig
ENDMACRO

MACRO   MULTI_DIGIT_CORRECTION()
        # Pre-digit correction loop
        # r11 = Q
        # r8  = mypi pointer (pointing at next free digit)
        # r2 = predigit pointer
        # r1 = temp store/predigit value
        #
        cmp     r11,r0,10               # check if Q==10 and needing correction?
        nz.sto  r11,r8                  # Save digit if Q <10
        nz.inc   pc,MDCL5-PC            # if no correction needed then continue else start corrections
        sto     r0,r8                   # overwrite 0 if Q=10
        mov     r2,r8                   # r2 is predigit pointer, start at current digit
pdcloop:
        dec     r2,1                    # update pointer to next predigit
        ld      r1,r2                   # get next predigit
        cmp     r1,r0,9                 # is predigit=9 (ie would it overflow if incremented?)
        z.sto   r0,r2                   # store 0 to predigit if yes (preserve Z)
        z.dec   pc,PC-pdcloop           # loop again to correct next predigit
        inc     r1,1                    # if predigit wasnt 9 fall thru to here and add 1
        sto     r1,r2                   # store it and return to execution

MDCL5:  inc     r8,1                    # incr pi digit pointer
        cmp     r8,r0,4+mypi            # allow buffer of 4 chars for corrections
        nc.inc  pc,MDCL6-PC
        ld      r1,r8,-4                # Get digit 3 places back from latest
        jsr     r13,r0,oswrdig
        cmp     r8,r0,4+mypi            # Emit decimal point after first digit
        nz.inc  pc,MDCL6-PC
        mov     r1,r0,46
        jsr     r13,r0,oswrch
MDCL6:
        dec     r9,1                    # dec loop counter
        nz.mov  pc,r0,L3                # back to main program

        # empty the buffer
        mov     r9,r8,-3
MDCL7:  ld      r1,r9
        jsr     r13,r0,oswrdig
        inc     r9,1
        cmp     r9,r8
        nz.dec  pc,PC-MDCL7
ENDMACRO


# r14 = stack pointer
# r13 = link register
# r12 = inner loop counter
# r11 = Q
# r10 = denominator
# r9  = outer loop counter
# r8  = next pi output digit pointer
# r7  = remainder pointer
# r3..r5 = local registers
# r1,r2  = temporary registers, parameters and return registers

        EQU     digits,   6
        EQU     cols,     1+(6*10//3)            # 1 + (digits * 10/3)

# preamble for a bootable program
# remove this for a monitor-friendly loadable program
    	ORG 0
    	mov r14, r0, 0xFFFF
    	mov pc, r0, start

        ORG 0x2000
start:
        mov     r8,r0,mypi

        ;; trivial banner
        mov     r1, r0, 0x4f
        jsr     r13,r0,oswrch
        mov     r1, r0, 0x6b
        jsr     r13,r0,oswrch
        mov     r1, r0, 0x20
        jsr     r13,r0,oswrch

                                        # Initialise remainder/denominator array using temp vars
        mov     r2,r0,2                 # r2=const 2 for initialisation, used as data for rem[] and increment val
        mov     r3,r0,cols              # loop counter i starts at index = 1
L1:     sto     r2,r3,remain-1          # store remainder value to pointer
        dec     r3,1                    # increment loop counter
        nz.dec  pc,PC-L1

        mov     r9,r0,digits            # set up outer loop counter
L3:     mov     r11,r0                  # r11 = Q
        #
        # All loop counters count down from
        # RHS of the arrays in this loop
        #
        mov     r12,r0,cols-1           # r4 inner loop counter
        mov     r7,r0,remain+cols-1
        mov     r2,r12,1                # r2 = i+1
        mov     r10,r0,(cols-1)*2 + 1     # initial denominator at furthest colum
L4:
        jsr     r13,r0,mul16s           # r11=Q * i+1 -> result in r11
        ld      r2,r7                   # r2 <- *remptr
        ASL     (r2)                    # Compute 16b result for r2 * 10
        mov     r1,r2
        ASL     (r2)
        ASL     (r2)
        add     r1,r2
        add     r11,r1                  # add it to Q as second term
        jsr     r13,r0,udiv16           # r11/r10; r11 <- quo, r2 <- rem, r10 preserved
        sto     r2, r7                  # rem[i] <- r2
        dec     r7,1                    # dec rem ptr
                                        # denom <- denom-2, but denom[0]=10
        dec     r10,3                   # oversubtract by 1
        z.inc   r10,9                   # correct by 9 if zero
        inc     r10,1                   # and always correct oversubtraction
        mov     r2,r12                  # get loop ctr into r2 before decr so it's r12+1 on next iter
        dec     r12,1                   # decr loop counter
        c.mov   pc,r0,L4                # loop if >=0

        SINGLE_DIGIT_CORRECTION()
        halt    r0,r0


        # --------------------------------------------------------------
        #
        # udiv16 - special Pi version - rejig input/output registers to
        # save cycles shuffling them around compared with the generic
        # version in math16.s
        #
        # Divide a 16 bit number by a 16 bit number to yield a 16 b quotient and
        # remainder
        #
        # Entry:
        # - r11 16 bit dividend (A)
        # - r10 16 bit divisor (B)
        # - r13 holds return address
        # Exit
        # - r3 upwards preserved (except r11)
        # - r2 = quotient
        # - r11 = remainder
        # --------------------------------------------------------------
udiv16:
        mov     r2,r0                   # Get dividend/quotient into double word r1,2
        mov     r1,r0,-16               # Setup a loop counter
udiv16_loop:
        ASL     (r11)                   # shift left the quotient/dividend
        ROL     (r2)                    #
        cmp     r2,r10                   # check if quotient is larger than divisor
        c.sub   r2,r10                   # if yes then do the subtraction for real
        c.adc   r11,r0                  # ... set LSB of quotient using (new) carry
        inc     r1,1                    # increment loop counter zeroing carry
        nz.dec  pc,PC-udiv16_loop       # loop again if not finished (r5=udiv16_loop)
        RTS     ()                      # and return with quotient/remainder in r1/r2

        # --------------------------------------------------------------
        #
        # mul16s
        #
        # Multiply 2 16 bit numbers to yield only a 16b result
        #
        # Entry:
        #       r11    16 bit multiplier (A)
        #       r2    16 bit multiplicand (B)
        #       r13   holds return address
        #       r14   is global stack pointer
        # Exit
        #       r6    upwards preserved
        #       r3,r5 uses as workspace registers and trashed
        #       r11   holds 16b result
        # --------------------------------------------------------------
mul16s:
        lsr     r3,r11                 # shift right multiplier into r3
        mov     r11,r0
mul16s_loop0:
        c.add   r11,r2                  # add copy of multiplicand into accumulator if carry
        ASL     (r2)                    # shift left multiplicand
        lsr     r3, r3                  # shift right multiplier
        nz.dec  pc,PC-mul16s_loop0      # no need for loop counter - just stop when r1 is empty
        c.add   r11,r2                  # add last copy of multiplicand into accumulator if carry
        RTS     ()

        # --------------------------------------------------------------
        #
        # oswrch
        #
        # output a single ascii character to the uart
        #
        # entry:
        # - r1 is the character to output
        #
        # exit:
        # - r2 used as temporary
oswrdig: mov     r1,r1,48                # Convert digit number to ASCII
oswrch:
oswrch_loop:
        in      r2, r0, 0xfe08
        and     r2, r0, 0x8000
        nz.dec  pc, PC-oswrch_loop
        out     r1, r0, 0xfe09
        RTS     ()


mypi:      WORD 0                         # Space for pi digit storage

         ORG mypi + digits + 8
remain:  WORD 0                          # Array space for remainder/denominator data interleaved
