@h[Compiler Standards for EMAS(3)]

@b[1. @u[Introduction]]


   Unlike 2900 series, IBM 370-XA provides no facilities or assistance for
executing stack-based procedures. To provide cross language calling and
advanced facilities like dynamic loading a carefully thought-out set of
conventions must be followed. The conventions proposed here follow those of
EMAS(1) with slight changes to permit array slicing and cross memory (i.e.
inward) calls.


@b[2. @u[Register Conventions]]


   When any EMAS(3) program is executing, GR11 is used as the stack top and it
is kept 8-byte-aligned (for efficient fetching). The stack may be multi-segment
- segment boundaries have no significance (unlike 2900). GR12 points to the head
of the shareable (pure) part of the program and is used to provide
addressibility. Program sharing requires that code executes correctly at
different virtual addresses; hence branches etc. must be made relative to GR12
or suitable subsidiary base registers. Since it is necessary to have branches
beyond the 4095 addressing limit the first part of the code is normally a table
of multiples of 4096 starting at zero and sufficient in extent to allow branches
to the last  part of the program. GR13 points to the head of the unshared or
linkage area of the program (the GLA). This area is copied from the program
file at load time and may be fixed up. There can be no fix-ups to the shared
area. No other register uses are mandatory, although GR14 and GR15 are used
in the external procedure-calling sequences. Most compilers therefore use GR10
downward for display purposes and GRs 0-3 and 15 for temporary and arithmetic
results. GR14 is a minor problem, best used to address permanent subroutines
or constant areas that are not required at procedure calls.


@b[3. @u[Calling Sequences]]


@b[3a. Normal calling sequence.]


   The normal sequence is built around a 64-byte save area which is used by the
calling and called sequence. Only 48 bytes are used for saving registers.

      The calling routine

      (a) plants the parameters starting 64 bytes beyond the stack pointer
          GR11. It may have to advance GR11 to protect the parameters if
          further procedure calls are required to evaluate the parameters.

      (b) store registers 4-14 (or such lesser number as it requires to be
          saved) in the save area.

      (c) loads registers 12-14 from the GLA with information set by the
          loader and then enters with a BASR 15,14.


      The called routine

      (a) stores GR15 (the return address) in the save area.

      (b) copies GR11 into a register selected as LNB.

      (c) advances GR11 to protect the save area and parameters.

      (d) does its business.

      (e) returns by loading 4-15 from the save area and exiting with a
          BCR 15,15



      Thus:


      @b[Calling:]                               @b[Called:]


      ST    PARM, 64(11)
      STM   4,14,16(11)
      LM    12,14,EP(GLA)
      BASR  15,14         --------+
                                  |
                  <-------+       |
                          |       +--------> ST   15,60(11)
                          |                  LR   LNB,11
                          |                  LA   11,256(11)
                          |                  ...
                          |
                          |                  LM   4,15,16(LNB)
                          +----------------- BCR  15,15



@b[Notes:]

    (a)  The exit sequence is mandatory - the called routine is entitled to
         assume GR15 is usable as a code base register on return.

    (b)  The calling sequence can be improved for routines with 1-4 32-bit
         parameters by using the "wrap-round" effect of STM to save GRs 4-14
         and plant the parameters from GR0 to GR3 in a single instruction.

    (c)  The save area layout is:

               @b[Words]               @b[Use]

               0-1                 Diagnostic information for called routine.
               2                   Reserved for use by cross memory call.
               3                   "Reach-back" pointer for languages that
                                   need it.
               4-14                Copies of GRs 4-14 to be restored at exit.
               15                  Return address

    Since the parameter descriptor for reach-back is language dependent,
    it cannot be defined. For mixed language calls there is no obligation
    on languages that do not need reach-back to set this word. Reach-back
    languages will need to validate this parameter by checking the
    language flag of the calling routine or otherwise. A value of zero
    means no reach-back information supplied.


@b[3b. Cross-Memory (System) Calls]


   The cross memory calling sequence is the same as the normal calling sequence
except that the BASR 15,14 is replaced by a PC 0(14). The loader has to
identify cross-memory calls and put unusual information into the three words
that normally contain code, GLA and EP addresses. The sequence means
(regrettably) that the compiler must be told that  a routine is a CM call and IMP
will use @b[system] @b[routine] @b[spec] for this purpose. Other languages can invent
a spec e.g. EXTERNAL/SYSTEM/ or can use IMP interface routines. System
routines will be used by Director and Supervisor but not by Subsystem. The entry
sequence for the called routine and the return sequence will be much slower
than for a normal routine and will only be used where protection is essential.
These entry and exit sequences are a matter of concern to the IMP compiler only
and are not detailed here.


@b[3c. Dynamic Calling Sequence]


   For the calling routine, the dynamic sequence is the same as the normal
calling sequence. The loader will set the three words to ID, loader GLA,
loader dynamic entry respectively so that the calling sequence enters the
loader. The loader performs the following steps:

   Step A     Store the return address and advance GR11 past the parameters.
              These are unknown and 4/75 used a parameter size of 1024 bytes(!)
              (Note A).

   Step B     The loader stores GR12 into an @b[own] integer and resets GR12 from
              the first word of the GLA.

   Step C     The loader calls itself passing the returned ID as parameter to
              load the relevant file.

   Step D     The dynamic loading sequence sets GRs 12-14 to the correct
              values - retrieves the original value of GR15, resets GR11 and
              enters with a BCR 15,14. The return goes direct to the original
              caller.

Note A

   The problem of checking for correct parameters was never solved in 4/75. An
   advisory scheme is suggested later. It is the loader's responsibility not to
   allow dynamic loading if the size of the parameter(s) is inconveniently
   large - or else to use a special escape sequence.
@N()
@b[4. @u[Mixed Language Parameter and Result Passing]]


   The following scheme defines the parameters that may be passed to external
procedures. An important aim of EMAS(3) is to allow the published Director and
Subsystem interfaces to be open to all other languages. These routines should
restrict themselves to integer and reals passed by reference together with
strings and one-dimensional arrays passed by reference. A record by reference is
sometimes essential but should be avoided if at all possible. [To ease the pain
of this for the EMAS team, IBM IMP will allow integer and real expressions to be
passed by reference via a suitable temporary].


@b[4a. Function Results]


   Integer functions and maps leave their result in GR1 (for 64-bit precision use
GR0 and GR1). Real functions use FR0 (FR0 and FR2 for 128-bit precision). String
and record functions leave the result on the stack and set GR1 to point to it.
The calling routine must copy the result before any use is made of the stack.


@b[4b. Value Parameters]


   Integer and real parameters are stacked starting 64 bytes beyond GR11 and are
32-bit aligned. 8 and 16-bit quantities are right-aligned in the 32-bit word.
String values are stacked byte-aligned in IMP form, i.e. length byte followed
by characters. This suits IMP and is efficient, which is important - the
published system interface should not include string values. Record values are
stacked 32-bit aligned.

   There has never been an EMAS standard for arrays by value - I propose that
value arrays be passed by reference with the onus on the called routine to copy
the array. This permits the copy to be omitted when safe to do so.


@b[4c. Reference Parameters]


   Except for strings and arrays, a reference parameter is the 31-bit address
of the low address end of the variable being passed. All reference parameters
are 32-bit aligned. A procedure reference is the 31-bit address of a 128-bit
quantity as follows:

     @b[bits]                   @b[contents]
     0-31                   The head of code of the module containing the
                            procedure.
     32-63                  The head of the GLA for the procedure.
     64-95                  The procedure entry address.
     96-127                 The address of a suitable environment.

   A procedure environment consists of a 64-byte save area as for procedure
calling; one-level languages must provide a suitable dummy value. The calling
sequence for a procedure reference is:
@n()
                 .......                Plant any parameters
                 STM   4,14,16(11)
                 L     15,RTREF         Pick up parameter
                 LM    12,15,0(15)      Load the four words
                 LM    4,10,16(15)      Load environment
                 BASR  15,14

   A string reference consists of a 64-bit quantity as follows:

     @b[bit]                     @b[contents]
     0-15                    Flags.
     16-31                   The maximum (or only) length of the string.
     32-63                   The address of the lowest byte.

   String flags are as follows:

     0      IMP (i.e. variable length - length on front)
     1      reserved for possible @b[long] IMP string
     2      FORTRAN (ASCII) (fixed length, space-filled)
     3      FORTRAN (EBCDIC) (fixed length, space-filled)
     4      'C' string (variable length, zero-terminated)
     5...   to be defined on request

   Compilers are entitled to assume that the correct type of string is passed
in; however, routines at the system interface are expected to accept all
defined string references and convert. Two IMP routines will be provided for
conversion:

     @b[string](255) @b[fn] EXTRACT VALUE(@b[string] @b[name] REF)

     @b[routine] ASSIGN VALUE(@b[string name] REF, @b[string](255) VALUE)

Other languages may elect to provide similar service routines.

   An array reference consists of a 4-word (128-bit) array head - see section on
array storage.



@b[5. @u[Array Access and Storage]]


   Historically, EMAS has insisted on its arrays being stored as FORTRAN - this
has been possible only because most languages do not define how arrays are
stored. However, array standards must now permit array "slicing" for FORTRAN 8X,
ADA and ALGOL68; these revised standards are designed to allow languages that
insist on storing arrays by rows to co-exist. The full generality, to cope with
both sorts of storage and pathological slices is expensive. This is discussed
further in section 5c - Array Access and Optimisation. Compiler-writers who
have freedom of choice should store arrays by columns [A(1,1) is followed by
A(2,1), not A(1,2)]. All system utilities will page better for column rather
than row array storage.

@n()
@b[5a. Array Dope Vector]


   All the information required to access an array is collected into a dope
vector. Dope vectors can often be generated at compile-time and once generated
are read-only items. Several arrays may use the same dope vector. An EMAS(3)
dope vector is 32-bit aligned and consists of three words followed by a set of
triples for each dimension. Thus:

      @b[Word]         @b[Information]
      0            N   the number of dimensions of the array.
      1            T   the total size of the array in bytes - for
                       discontiguous slices T is set to zero.
      2            E   the size in bytes of a single element.
      3            L1  the lower bound for the first dimension.
      4            U1  the upper bound for the first dimension.
      5            S1  the stride (in bytes) for the first dimension.
      6-8          L2, U2, S2 if N>1
      9-11         L3, U3, S3 if N>2    ... etc.


@b[5b. Array Heads]


   An array head consists of four 32-bit words:

      @b[Word]         @b[Information]
      0            Addr(A0)      the address of the (possibly hypothetical)
                                 zero-th element.
      1            Addr(Afirst)  the address of the first actual element.
      2            Addr(DV)      the address of the dope vector.
      3            S             a stride.

   For 1-dimensional arrays, S is the only stride S1.
   For 2-dimensional arrays, S is the upper stride S2.
   S is undefined for arrays of more than two dimensions.


@b[5c. Array Access and Optimisation]


   Array access on IBM 370-XA architecture is complicated by the existence of
two multiply instructions, neither of which is suitable for array access.
Multiply (Opcode X4C) requires an even-odd register pair and produces a 63-bit
result which must be contracted. Multiply half (X5C) produces a 32-bit result
but uses only a 16-bit signed operand and does not check for overflow(!). In
the general case of A(L1,L2,...Ln) the element is found at

         AddrA0 + {SIGMA j=1 to n} of L[j] * S[j]

where * is a 32-bit operation. However, in languages that do not permit slicing,
one-dimensional arrays can use MH for the multiplication - and make further
optimisation for 1, 2 and 4-byte items. Similarly 2-dimensional unsliced arrays
stored by columns can use the multiplier from the array head S2 and assume S1
to be the known element-size. It seems unreasonable to prohibit such
optimisations, merely to allow slicing in as yet unimplemented languages. IMP
will make such optimisations and thus "slices" will not be acceptable at the
system interface. A compiler option will be introduced later to force fully
general subscripts, and thus support software for "slicing" languages could be
written in IMP.


@b[6. @u[Object File Format]]

   Minor changes are required to the EMAS object files format for EMAS(3).
Traditionally, no standards at all have been imposed on the code area. However,
all programs will need a table of multiples of 4096 for addressing, and I
propose this is always placed at the head of the code (i.e. GR12 points at the
4096*0 multiple). Any compiler which wishes to use LPUT's forward-jump
optimising facility must provide such a table of adequate size to enable
branches to the back of the program.

   The  first six words of the GLA are defined for diagnostic purposes as
follows:

     @b[bits]                   @b[use]
     0-31                   reserved (upper half of entry descriptor on 2900).
     32-63                  Addr of head of code.
     64-95                  Addr of GLA symbol tables.
     96-127                 Addr of shared symbol tables.
     128-159                Language flag and compiler versions (as 2900).
     160-191                Addr of diagnostic tables.

   On 2900 the diagnostic tables were in the SST but this is a mistake for
programs which use a lot on @b[const] @b[arrays].

   A program entry is defined entirely in the load data four words (plus the
link and the name).

         W0     Offset of head of code from head of code for module.
         W1     Offset of head of GLA from head of GLA for module.
         W2     Offset of entry point from head of code.
         P      Parameter word (number of parameters << 16 ! bytes of
                parameters) (-1 means omit checking).

W0 and W1 are normally zero unless the file has been linked with other
modules.

   A program external reference consists of the load data of two
words:

         W0     Offset from head of GLA of a four-word area to be filled at
                load-time.
         P      Parameter word (as above).

   The loader fills the four words with code, GLA and EP addresses and dummy
environment. FOUR WORDS must be provided, otherwise passing a dynamic procedure
as a formal parameter fails! (Learned the hard way on 4/75!).

   Data references etc. as present 32-bit relocations. There will be no 16 or
24-bit data relocations on EMAS(3).

@B(P@. Stephens, 1st January 1984)
