         TITLE 'EMAS 370/XA tape IPL code'
*
* R.D. Eager   University of Kent   MCMLXXXVI
*
BASE     LA    12,X'228'     * set up base address
         SLL   12,4          * generates x2280
         USING BASE,12       * set up base register
*
         L     1,184(0)      * get IPL subsystem ID
*
         LA    2,8           * make upper half of EC mode PSW
         SLL   2,16          * generates x80000
         LA    3,X'18'       * make address of interrupt handler
         SLL   3,8           * will go to x1800
         STM   2,3,120(0)    * set up I/O interrupt address
*
         LA    2,SCHIB       * get subchannel information
         DC    X'B2342000'   * STSCH 0(2)
         L     3,4(2)        * get word with enable bit
         O     3,ENBIT       * set it
         ST    3,4(2)        * put back in SCHIB
         DC    X'B2322000'   * MSCH 0(2) - enable subchannel
*
         DC    X'B766C144'   * LCTL 6,6,CR6 - enable interrupts
         LA    2,ORB         * point to ORB for start
         DC    X'B2332000'   * SSCH 0(2) - start subchannel
         DC    X'8200C148'   * LPSW WPSW - wait for interrupt
*
         DS    46F           * Padding
*
ORB      DC    F'0'          * Interruption parameter (not used)
         DC    X'0000FF00'   * Flags; set all LPM bits
         DC    X'00002018'   * Address of first CCW
ENBIT    DC    X'00800000'   * Bit to enable subchannel
SCHIB    DS    13F           * SCHIB to enable subchannel
CR6      DC    X'FF000000'   * Value for control register 6
         DS    0D            * Following PSW must be on double word
WPSW     DC    X'020A0000'   * EC mode, allow I/O ints, wait
         DC    F'0'          * Irrelevant
*
         END
