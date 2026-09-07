         TITLE 'EMAS 370/XA tape IPL code'
*
* R.D. Eager   University of Kent   MCMLXXXVI
*
BASE     LA    12,X'24'      * set up base address
         SLL   12,8
         USING BASE,12       * set up base register
*
         L     1,184(0)      * get IPL subsystem ID
         N     1,SCHMASK     * lose top half
         O     1,SCHBIT      * make a legal value and save in GR1
*
         LA    2,8           * make upper half of EC mode PSW
         SLL   2,16          * generates x80000
         LA    3,X'18'       * make address of interrupt handler
         SLL   3,8           * will go to x1800
         STM   2,3,120(0)    * set up I/O interrupt address
*
         LA    2,SCHIB       * get subchannel information
         DC    X'B2342000'   * STSCH 2(0)
         LH    3,4(2)        * get halfword with enable bit
         O     3,ENBIT       * set it
         STH   3,4(2)        * put back in SCHIB
         DC    X'B2322000'   * MSCH 0(2) - enable subchannel
*
         LA    2,ORB         * point to ORB for start
         DC    X'B2332000'   * SSCH 0(2) - start subchannel
         DC    X'8200C160'   * LPSW WPSW - wait for interrupt
*
         DS    45F           * Padding
*
ORB      DC    F'0'          * Interruption parameter (not used)
         DC    X'0000FF00'   * Flags; set all LPM bits
         DC    X'00002018'   * Address of first CCW
SCHMASK  DC    X'0000FFFF'   * Mask for subchannel ID
SCHBIT   DC    X'00010000'   * Bit to make legal subchannel ID
ENBIT    DC    X'00000080'   * Bit to enable subchannel
SCHIB    DS    13F           * SCHIB to enable subchannel
         DS    0D            * Following PSW must be on double word
WPSW     DC    X'020A0000'   * EC mode, allow I/O ints, wait
         DC    F'0'          * Irrelevant
*
         END
