@Make(Article)
@Heading(Extended object file format for EMAS 370)

@Section(General)

The format described in these notes extends the EMAS 2900 object file format
to allow greater flexibility and compatibility with other ERCC Compiler Group
compilers, produced for other operating systems. This should increase the
commonality of code in all ERCC Compiler Group products, improving maintenance
and portability.

At the level of the Put interface (see Description of EMAS 370 Put Code
Generating Interface), which represents the common code generating interface for
all ERCC Compiler Group's compilers on EMAS 370, the extended set of areas
already appears to exist, being mapped onto the old restricted set. The purpose
of these notes is to allow other object file manipulating software, particularly
the loader, linker and Modify, to use the extended set and for these areas to
exist physically in an object file with an extended definition.

The new set of areas is almost a superset of the EMAS 2900 definition, except
that the old common area (area 6) is removed and area 6 used as the new Diagnostic
table Area, with read only, shareable properties. As ERCC's Fortran compilers no
longer make use of the old single common, using instead multiple commons numbered
from 11 upwards, this presents no conflicts with existing compiler needs.

A further proposed change, which is not a simple extension, is the use of a more
compact representation of common areas. Although all other areas would still be
laid out fully, common areas would now be held as a list of initialisation
records. This should not impose a significant loading overhead, but would greatly
reduce the size of unloaded object files for some large Fortran programs.

The types of areas defined by such records is extended beyond common areas,
allowing, at first, additional static areas to be defined. The possibility of
additional areas with other properties is left open for future development.
@Heading(Area summary)


                  EMAS 2900        !     EMAS 370
   -----------------------------------------------------------------
    1 ! Code                       ! Code
   -----------------------------------------------------------------
    2 ! GLA-Read/write/relocate    ! GLA-Read/write/relocate
   -----------------------------------------------------------------
    3 ! PLT - Never used           ! Unused
   -----------------------------------------------------------------
    4 ! SST - Read only            ! SST - Read only
   -----------------------------------------------------------------
    5 ! UST - Read/writeelocate    ! UST - Read/write/relocate
   -----------------------------------------------------------------
    6 ! Common                     ! Diagnostics - Read only
   -----------------------------------------------------------------
    7 ! Init Stack                 ! Statics - Read/write/relocate
   -----------------------------------------------------------------
    8 ! Not used                   ! IO Tables - Read/write/relocate
   -----------------------------------------------------------------
    9 ! Not used                   ! Zero UST - Read/write
   -----------------------------------------------------------------
   10 ! Multiple common 1          ! Constants - read only
   -----------------------------------------------------------------
   11+! Multiple commons           ! Compiler defined areas

@Heading(Table 1)
@Section(Area properties)

~Code~

Unchanged from EMAS 2900. Now used almost exclusively for machine instructions,
as PC relative addressing is not supported by 370 architectures. Read only,
shareable.

~GLA~

Unchanged from EMAS 2900. Should only be needed for linkage, as extra areas are
provided for statics. IO Tables also allow separation of some linkages.
Read, write, unshared, relocatable, initialisable.

~SST~

Unchanged from EMAS 2900. SHould have more specialised role, as extra areas are
provided for constants and diagnostic records. Read only, shareable.

~UST~

Unchanged from EMAS 2900.  Should have more specialised role, as extra areas are
provided for statics and zeroed statics. Read, write, shareable, relocatable.

~Diagnostics~

New read only area. Removes diagnostic records from SST, reducing run time paging.
Allows interleaved generation of diagnostics and constants without such overheads.

~Statics~

New read/write area. Currently relocatable. Unshared. Initialisable.

~IO Tables~

New second GLA, for specialised purposes. Read, write, relocatable, unshared.

~Zero UST~

Zeroed static area. Read, write, unshared, unrelocatable.

~Constants~

New read only area. Shareable.
@Section(Compiler Defined Areas)

Areas 11 upwards are definable by individual compilers. This extends the EMAS
2900 use of them for multiple commons. Their properties are defined in records 
whose format is given below. These replace the records on list LDATA(13)
(single word references) of EMAS 2900 object files.

These extended areas may be laid out or merely described in their records. The
area definition records may contain pointers to a laid out area, assume complete
initialisation to zero or the unassigned pattern or be multiply initialised by
records in the list headed by LDATA(13).

The format of an area definition record is

   @b{integer Link, Area, Len, Props, Disp, %string(31) Name)}.

   @b(Link) is the link to the next in the list.

   @b(Area) is the number ( >=11 ) given to this area.

   @b(Len) is the length in bytes of this area.

   @b(Props) defines the properties, including initialisation, of this area.

      Bit value = 1<<0      Property defined = Blank common - no initialisation
                  1<<1                         Named common
                  1<<2                         Local (static) area
                  1<<3                         Reserved for future use
                  1<<4                             "     "     "    "
                  1<<5                             "     "     "    "
                  1<<6                             "     "     "    "
                  1<<7                             "     "     "    "
                  1<<8                         Zero filled
                  1<<9                         Unassigned pattern filled
                  1<<10                        Multiple initialisation
                  1<<11                        Laid out
                  1<<12                        Reserved for future use
                  1<<13                            "     "     "    "
                  1<<14                            "     "     "    "
                  1<<15                            "     "     "    "
          1<<16 - 1<<31                            "     "     "    "

   @b(Disp) is the offset from the start of the file of any laid out area.

   @b(Name) is the name of this area, where appropriate.
@Heading(Physical layout of object files)

The current layout of loaded object files, with new areas mapped onto old, is shown in
figure 1. This shows the order as all read only areas, followed by all read/write
areas, followed by all common areas.

A new layout is shown in figure 2. This would be the order in which they would be loaded.
This makes Diagnostic Tables a completely separate area, not fused to the other
read only areas, bringing more frequently accessed read only areas closer together
and so reducing paging. Diagnostics are only normally accessed following a
program error or a %monitor.

@Section(The unloaded object file)

It is anticipated that all object files on EMAS 370 will be generated through the
Put interface. LPUT will be maintained unchanged for utilities which have yet to
make the change to Put, but the extended format will only be available through
Put. This will require a means of distinguishing the old and new formats and the
object file map is extended accordingly.

The general form of Put generated object files, prior to loading, is shown in
Figure 3.

The file header contains the locations of the object file map and the LDATA
table. These in turn contain the locations of the other parts of the file.

The LDATA lists are linked lists containing linkage and initialisation
details, plus the history records for the file. The headers of these lists are
held in the LDATA tables.

@Section(The file header)

The file header is unchanged from EMAS 2900. It consists of eight words, used as
follows:

      word 0  Offset of end of data from start of file.
           1  Offset of start of data from start of file, usually 32.
           2  Physical file size.
           3  File type = 1 for object file.
           4  Sum check, not used by Put.
           5  Packed date and time last changed.
           6  Offset of LDATA from start of file.
           7  Offset of object file map from start of file.

@Section(The file map)

The object file map is extended by four entries from EMAS 2900, to allow old and
new formats to be distinguished.

The new format is:

     (%integer N, %record(AreaFmt)%array Area(1:N))

where N is the number of areas defined (7 for old format, 11 for new) and Area 
is a table of records for each area. The new format uses entry 11 to define the
diagnostic table area, i.e. area 6, to avoid confusion with old uses of the area
6 common.

Each record in Area has the following format:

      (%integer Start, Len, Props)

where Start is the offset of the start of the area from the start of the file,
      Len is the length of the area,
      Props defines the properties of the area.

Currently the most significant bit in Props defines a non-shareable area.

@Section(LDATA)

The LDATA table is a sequence of integers with the following meanings:

     LDATA                Meaning

      0    The number of entries following, initially 14.
      1    Offset of start of list of procedure entry records.
      2    Total number of entries and references.
      3    Total number of relocations.
      4    Offset from start of file of list of data entries.
      5    Load address of code for bound files.
      6    Load address of gla for bound files.
      7    Offset from start of file of list of static procedure references.
      8    Offset from start of file of list of dynamic procedure references.
      9    Offset from start of file of list of data references.
     10    Load address of initialised stack for bound files.
     11    Offset from start of file of list of compiler defined areas.
     12    Offset from start of file of history records.
     13    Offset from start of file of list of multiple initialisation records. 
     14    Offset from start of file of list of relocation requests.

Note that the use of LDATA(11) is changed from EMAS 2900, since single word
references were only needed for VME compatibility. Similarly LDATA(15) is no
longer present, as OMF diagnostics have no meaning on EMAS 370.

@Section(LDATA list record types)

In the record formats given, all displacements are in bytes and are relative to
the start of the area specified in that record. The links are relative to the
start of the object file. All strings have a maximum length of 31
characters and are held with their actual length, rounded up to a word boundary.

~Procedure entries~ - listhead LDATA(1)

The format of each record is

      (%integer Link, CodeOffset, GlaOffset, EPOffset, ParamW, %string(31) Iden)

where CodeOffset is the offset of the head of code from the head of code for
      the module,

      GlaOffset is the offset of the head of GLA from the head of GLA for
      the module,

      EPOffset is the offset of the entry point from the head of code given in
      CodeOffset. Where the most signficannt bit is set this is a main entry,

      ParamW is (number of parameters<<16)!(bytesize of parameters). If ParamW
      is -1, this indicates no parameter checking.

      Iden is the name of the entry point.

~Data entries~ - listhead

The format of each record is

      (%integer Link, Disp, Len, Area, %string(31) Iden)

where

   Disp is the offset of the entry from the start of Area;
   Len is the (minimum) length of the data item.
   Area is the area containing the item.
   Iden is the name of the item.

~Procedure references~ - listhead LDATA(7) and LDATA(8)

The format of each record is

      (%integer Link, RefLoc, %string(31) Iden)

where
   Refloc is (Area<<24)!RefAd)
   RefAd is the displacement from the start of Area of a procedure reference
         which is to be filled in by the loader.
   Iden is the name of the procedure being referenced.

~Data references~ - listhead LDATA(9)

The format of each record is

      (%integer Link, RefArray, Len, %string(31) Iden)

where

   RefArray is the offset from the start of the file of a record of the form

      (%integer N, %integerarray RefLoc(1:N))

   and each item in RefLoc has the form (Area<<24)!RefAd, where
      RefAd is the offset from the start of Area, of a word which is to have the
            address of data item Iden added to it by the loader.
      Area is the area containing the references.

   Len is the expected, minimum, length of the item.
   Iden is the name of the item.


~Compiler defined areas~ - listhead LDATA(11)

Areas 11 upwards are definable by individual compilers.
Their properties are defined in records 
whose format is given below.

These extended areas may be laid out or merely described in their records. The
area definition records may contain pointers to a laid out area, assume complete
initialisation to zero or the unassigned pattern or be multiply initialised by
records in the list headed by LDATA(13).

The format of each record is

   @b((%integer Link, Area, Len, Props, Disp, %string(31) Name)).

   @b(Link) is the link to the next in the list.

   @b(Area) is the number ( >=11 ) given to this area.

   @b(Len) is the length in bytes of this area.

   @b(Props) defines the properties, including initialisation, of this area.

      Bit value = 1<<0      Property defined = Blank common
                  1<<1                         Named common
                  1<<2                         Local (static) area
                  1<<3                         Reserved for future use
                  1<<4                             "     "     "    "
                  1<<5                             "     "     "    "
                  1<<6                             "     "     "    "
                  1<<7                             "     "     "    "
                  1<<8                         Zero filled
                  1<<9                         Unassigned pattern filled
                  1<<10                        Multiple initialisation
                  1<<11                        Laid out
                  1<<12                        Reserved for future use
                  1<<13                            "     "     "    "
                  1<<14                            "     "     "    "
                  1<<15                            "     "     "    "
          1<<16 - 1<<31                            "     "     "    "

   @b(Disp) is the offset from the start of the file of any laid out area.

   @b(Name) is the name of this area, where appropriate.

~Object file history~ - listhead LDATA(12)

Currently history records are not linked, but form a contiguous sequence. Each
sub-type has a fixed or determinable length and chaining is by incrementing an
offset by this length. It might be sensible to consider the chaining of these
records as for all other types. Currently they are defined as the following
sub-types.

 0 - end of history records          (%byteinteger Type)
 1 - source file name                (%byteinteger Type, %string(*) S)
 2 - parms                           (%byteinteger Type, %longinteger Parms)
 3 - start of linked object          (%byteinteger Type)
 4 - object file name                (%byteinteger Type, %string(*) S)
 5 - date linked                     (%byteinteger Type, %integer PackedDate)
 6 - date compiled                   (%byteinteger Type, %integer PackedDate)
 7 - end of linked object            (%byteinteger Type)
 8 - general text                    (%byteinteger Type, %string(*) Text)
 9 - compiler                        (%byteinteger Type, %string(*) Utility)

In addition it has proved desirable to be able to identify included source files
and the depth and structure of inclusion. Thus a new record might be included.

 10 - included source file            (%byteinteger Type, Depth, %string(*) S)

~Initialisation data~ - listhead LDATA(13)

The format of each record is

      (%integer Link, Area, Disp, Len, Rep, Addr)

where

   Area is the area to be initialised (1-10 or specified by an LDATA(11) record)
   Disp is th offset within Area where the initialisation is to start.
   Len is the length of initialisation data.
   Rep is the number of copies to be added consecutively.
   Addr is the offset from the start of the file of the initialisation data or
        (where Len is one) a value with Rep bytes are to be filled.

~Relocation request blocks~ - listhead LDATA(14)

The format of each record is

      (%integer Link, N, %recordarray Relocs(1:N))

where

   N is the number of relocation requests in this block.
   R has the following format
      (%integer AreaLoc, BaseLoc)
   where
      AreaLoc is (Area<<24)!AreaDisp
      BaseLoc is (Base<<24)!BaseDisp

      Area identifies the area containing the item to be relocated.
      AreaDisp is the offset of a word within Area to be relocated.

      Base is an area whose base will be used in the relocation.
      BaseDisp is an offset within Base which will be used in the relocation.

Note that BaseDisp is always zero currently, because of the limitations of LPUT.
This will no longer be guaranteed by Put, which will use BaseDisp to avoid work
for itself.

@Section(Implementation)

It is proposed that the definitions given in this set of notes form the basis
for the object file formats in EMAS 370, as released for a user service. The
changes are mostly trivial and should reduce work for most software affected.
The major changes will involve extending the loader to cope with additional
area definitions and more general user defined areas. For other software,
notably Link and Modify, the changes are simpler. The abandonment of LPUT and
the move to Put should be largely a matter of spec changes. Analyse will also
need to be slightly extended.

@b(Rob Pooley, March 25th 1985)
