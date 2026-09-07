@H(Comparison of instruction sets:)
@h(System/360,  System/370,  370-XA)


@s(1. New instructions introduced in System/370, compared to System/360)

    @b(Opcode    Mnemonic   Operation        Ref in 370-XA Princs of Op)

    0D        BASR       Branch and save register                7-10
    0E        MVCL       Move long                               7-27
    0F        CLCL       Compare logical long                    7-17

    4D        BAS        Branch and save                         7-10

    AC        STNSM      Store then AND system mask             10-44
    AD        STOSM      Store then OR system mask              10-44
    AE        SIGP       Signal processor                       10-41
    AF        MC         Monitor call                            7-26

    B1        LRA        Load real address                      10-18
    B2xx                 Channel set, Clock, Timer
                         PURGE TLB, PREFIX, Ref bit,
                         PTE instructions, Cross-memory service
                         instructions

    B6        STCTL      Store control                          10-42
    B7        LCTL       Load control                           10-17

    BA        CS         Compare and swap                        7-14
    BB        CDS        Compare double and swap                 7-14
    BD        CLM        Compare logical characters under mask   7-16
    BE        STCM       Store characters under mask             7-38
    BF        ICM        Insert characters under mask            7-23

    D9        MVCK       Move with key                          10-20
    DA        MVCP       Move to primary                        10-19
    DB        MVCS       Move to secondary                      10-19

    E500      LASP       Load address space parameters          10-10
    E501      TPROT      Test protection                        10-47
    E8      + MVCI       Move inverse

    F0        SRP        Shift and round decimal                 8-10


The action of the following instruction is modified in System/370 depending on
the address mode bit in the PSW:

    41        LA         Load  address.   In  24-bit mode, the
                         top byte of the destination  register
                         is set to zero.   In 31-bit mode, the
                         destination  register  contains   the
                         31-bit address.

Likewise the BAS and BASR instructions also depend on the current address mode.
In 24-bit mode they behave exactly as BAL, BALR respectively, but in 31-bit
mode the link register is set to contain the 31-bit address. The instruction
length code, condition code and program mask provided by BAL, BALR may be
obtained instead using the new instruction IPK Insert program mask.

THERE IS THEREFORE NO CASE for using BAL, BALR in the future, at least for
their branch function (they can still be used to get CC and PM into the top
byte of the operand-1 register) since BAS and BASR provide the necessary
forward and backward compatibility.

Most of the XA instructions are now implemented on the  370-XA simulator on
EMAS 2900, apart from those relating to key and PSW manipulation and dual
address space. The MVCI instruction marked + is not perpetuated in 370-XA.


@s(2. New instructions for 370-XA)


    0B        BSM        Branch and set mode                     7-11
    0C        BASSM      Branch and save and set mode            7-11

    99        TRACE      Trace                                  10-48

    B222      IPK        Insert program key                      7-23
    B22D      DXR        Divide (extended)                       9-8


And the following instructions
are withdrawn:

    08        SSK        Set storage key
    09        ISK        Insert storage key

    84                   Write direct
    85                   Read direct

    B200-B201            Connect, disconnect channel set
    B213                 Reset reference bit (use extended form)

    E8        MVCI       Move inverse(!)



                                                              K Yarwood
                                                                10/1/84
