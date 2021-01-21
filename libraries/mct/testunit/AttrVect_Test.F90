!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
!    Math and Computer Science Division, Argonne National Laboratory   !
!-----------------------------------------------------------------------
!BOP -------------------------------------------------------------------
!
! !ROUTINE: AttrVectTest.F90  -- Unit tests for MCT Attribute Vector
!
! !DESCRIPTION:  Unit tests for all subroutines in mct/m_AttrVect.F90
! and a top level program to call them all.
!
! !REVISION HISTORY:
!       11Jan11 - Sheri Mickelson <mickelso@mcs.anl.gov> - Initial version.
!EOP ___________________________________________________________________

!####################################
!#
!# Call of of the tests for m_AttrVect
!#
!####################################

subroutine testAttrVect(mypid, AVui)

implicit none

integer mypid
integer AVui

call testAttrVect_lsize(mypid,AVui)

call testAttrVect_clean(mypid,AVui)

call testAttrVect_init(mypid,AVui)

call testAttrVect_zero(mypid,AVui)

call testAttrVect_nIAttr(mypid,AVui)

call testAttrVect_nRAttr(mypid,AVui)

call testAttrVect_indexIA(mypid,AVui)

call testAttrVect_indexRA(mypid,AVui)

call testAttrVect_getIList(mypid,AVui)

call testAttrVect_getRList(mypid,AVui)

call testAttrVect_exportIList(mypid,AVui)

call testAttrVect_exportRList(mypid,AVui)

call testAttrVect_exportIListToChar(mypid,AVui)

call testAttrVect_exportRListToChar(mypid,AVui)

call testAttrVect_appendIAttr(mypid,AVui)

call testAttrVect_appendRAttr(mypid,AVui)

call testAttrVect_exportIAttr(mypid,AVui)

call testAttrVect_exportRAttr(mypid,AVui)

call testAttrVect_importIAttr(mypid,AVui)

call testAttrVect_importRAttr(mypid,AVui)

call testAttrVect_copy(mypid,AVui)

call testAttrVect_sort(mypid,AVui)

call testAttrVect_permute(mypid,AVui)

call testAttrVect_unpermute(mypid,AVui)

call testAttrVect_sortPermute(mypid,AVui)

call testAttrVect_sharedAttrIndexList(mypid,Avui)

end subroutine

!####################################
!#
!# Test AttrVect_lsize
!#
!####################################
subroutine testAttrVect_lsize(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect

implicit none

integer mypid
integer AVui
integer length
integer returnedLength

type(AttrVect) :: av

length = 3

! initialize vector
call MCT_AtrVt_init(av,iList="lat:lon:time",lsize=length)

! get the size of the new vector
returnedLength = MCT_AtrVt_lsize(av)

! test to see if the size is correct
if(returnedLength == length) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_lsize",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_lsize","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_lsize",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_lsize","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_clean
!#
!####################################
subroutine testAttrVect_clean(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
integer ier, result

result = 0

! test the different optional args to make sure all combos work
! first initializes new vector
! second, clean the vector
! finally, check to make sure size is zero

call MCT_AtrVt_init(av,iList="lat:lon:time")
call MCT_AtrVt_clean(av, ier)
if(MCT_AtrVt_lsize(av) == 0 .AND. ier == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_clean",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_clean",1,"FAIL")
  result = 1
endif

call MCT_AtrVt_init(av,iList="lat:lon:time")
call MCT_AtrVt_clean(av)
if(MCT_AtrVt_lsize(av) == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_clean",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_clean",2,"FAIL")
  result = 1
endif

if (result == 0)then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_clean","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_clean","FAIL")
endif
end subroutine

!####################################
!#
!# Test AttrVect_init
!#
!####################################
subroutine testAttrVect_init(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
integer ier

! test all of the combinations of optional args
! first, try an initialization
! then write out a pass staement if returned successfully
! fianlly, clean the vector

call MCT_AtrVt_init(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",1,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,iList='index')
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",2,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,rList='value')
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",3,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,iList='index',rList='value')
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",4,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,iList='index',lsize=1)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",5,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,rList='value',lsize=1)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",6,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,iList='index',rList='value',lsize=1)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",7,"PASS")
call MCT_AtrVt_clean(av, ier)

call MCT_AtrVt_init(av,lsize=1)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_init",8,"PASS")
call MCT_AtrVt_clean(av, ier)

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_init","PASS")
end subroutine

!####################################
!#
!# Test AttrVect_zero
!#
!####################################
subroutine testAttrVect_zero(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_zero => zero
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_lsize => lsize
use m_AttrVect
use m_realkinds,only : SP,DP,FP

implicit none

integer mypid
integer AVui

integer result, localResult

type(AttrVect) :: av

integer i,x,y,totalSize

integer intSize,realSize,listTotal

real r

totalSize = 32
intSize = 3
realSize = 3
!listTotal = intSize+realSize
listTotal = 3

result = 0
localResult = 0
r = .09_FP
i = 4

call MCT_AtrVt_init(av,iList="lat:lon:time",rList="T:P:Q",lsize=totalSize)
av%iAttr=i
av%rAttr=r
call MCT_AtrVt_zero(av)
do x=1,listTotal
do y=1,totalSize
if(av%iAttr(x,y) /= 0 .OR. av%rAttr(x,y) /= 0._FP)then
  localResult = 1
endif
enddo
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",1,"FAIL")
  result = 1
  localResult = 0
endif
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,iList="lat:lon:time",rList="T:P:Q",lsize=totalSize)
av%iAttr=i
av%rAttr=r
call MCT_AtrVt_zero(av,zeroReals=.TRUE.,zeroInts=.TRUE.)
do x=1,listTotal
do y=1,totalSize
if(av%iAttr(x,y) /= 0 .OR. av%rAttr(x,y) /= 0._FP)then
  localResult = 1
endif
enddo
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",2,"FAIL")
  result = 1
  localResult = 0
endif
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,iList="lat:lon:time",rList="T:P:Q",lsize=totalSize)
av%iAttr=i
av%rAttr=r
call MCT_AtrVt_zero(av,zeroReals=.TRUE.,zeroInts=.FALSE.)
do x=1,listTotal
do y=1,totalSize
if(av%iAttr(x,y) == 0 .OR. av%rAttr(x,y) /= 0._FP)then
  localResult = 1
endif
enddo
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",3,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",3,"FAIL")
  result = 1
  localResult = 0
endif
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,iList="lat:lon:time",rList="T:P:Q",lsize=totalSize)
av%iAttr=i
av%rAttr=r
call MCT_AtrVt_zero(av,zeroReals=.FALSE.,zeroInts=.TRUE.)
do x=1,listTotal
do y=1,totalSize
if(av%iAttr(x,y) /= 0 .OR. av%rAttr(x,y) == 0._FP)then
  localResult = 1
endif
enddo
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",4,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",4,"FAIL")
  result = 1
  localResult = 0
endif
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,iList="lat:lon:time",rList="T:P:Q",lsize=totalSize)
av%iAttr=i
av%rAttr=r
call MCT_AtrVt_zero(av,zeroReals=.FALSE.,zeroInts=.FALSE.)
do x=1,listTotal
do y=1,totalSize
if(av%iAttr(x,y) == 0 .OR. av%rAttr(x,y) == 0._FP)then
  localResult = 1
endif
enddo
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",5,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_zero",5,"FAIL")
  result = 1
  localResult = 0
endif
call MCT_AtrVt_clean(av)

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_zero","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_zero","FAIL")
endif

end subroutine

!####################################
!#
!# Test AttrVect_nIAttr
!#
!####################################
subroutine testAttrVect_nIAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_nIAttr => nIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer length, argLength, returnedLength

type(AttrVect) :: av

length = 32
argLength = 3

! initialize vector
call MCT_AtrVt_init(av,iList="lat:lon:time",lsize=length)

returnedLength =  MCT_AtrVt_nIAttr(av)

if (argLength == returnedLength) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_nIAttr",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_nIAttr","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_nIAttr",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_nIAttr","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_nRAttr
!#
!####################################
subroutine testAttrVect_nRAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_nRAttr => nRAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer length, argLength, returnedLength

type(AttrVect) :: av

length = 32
argLength = 3

! initialize vector
call MCT_AtrVt_init(av,rList="T:Q:P",lsize=length)

returnedLength =  MCT_AtrVt_nRAttr(av)

if (argLength == returnedLength) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_nRAttr",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_nRAttr","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_nRAttr",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_nRAttr","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_indexIA
!#
!####################################
subroutine testAttrVect_indexIA(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_indexIA => indexIA
use m_AttrVect

implicit none

integer mypid
integer AVui

integer length, indexFound, index

integer result

character(len=4) var
character(len=18) variables

type(AttrVect) :: av

result = 0

length = 32
var = "date"
variables = "lat:lon:"//var//":time"
index = 3 !This must match the location of 'var' in above line

! initialize vector
call MCT_AtrVt_init(av,iList=variables,lsize=length)

indexFound = MCT_AtrVt_indexIA(av,var)
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",1,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexIA(av,var,perrWith="ERROR")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",2,"PASS")
else
 if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",2,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexIA(av,var,perrWith="ERROR",dieWith="KILLED JOB")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",3,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",3,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexIA(av,var,dieWith="KILLED JOB")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",4,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",4,"FAIL")
  result = 1
endif

! Check for a name that is not in the list.  With 'perrwith' it should
! return 0 as an index
indexFound = MCT_AtrVt_indexIA(av,"foo",perrWith="quiet")
if(indexFound == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",5,"PASS")
else
 if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexIA",5,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_indexIA","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_indexIA","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_indexRA
!#
!####################################
subroutine testAttrVect_indexRA(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_indexRA => indexRA
use m_AttrVect

implicit none

integer mypid
integer AVui

integer length, indexFound, index

integer result

character(len=1) var
character(len=8) variables

type(AttrVect) :: av

result = 0

length = 32
var = "U"
variables = "T:Q:"//var//":P"
index = 3 !This must match the location of 'var' in above line

! initialize vector
call MCT_AtrVt_init(av,rList=variables,lsize=length)

indexFound = MCT_AtrVt_indexRA(av,var)
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",1,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexRA(av,var,perrWith="ERROR")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",2,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexRA(av,var,perrWith="ERROR",dieWith="KILLED JOB")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",3,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",3,"FAIL")
  result = 1
endif

indexFound = MCT_AtrVt_indexRA(av,var,dieWith="KILLED JOB")
if(index == indexFound) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",4,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",4,"FAIL")
  result = 1
endif

! Check for a name that is not in the list.  With 'perrwith' it should
! return 0 as an index
indexFound = MCT_AtrVt_indexRA(av,"foo",perrWith="quiet")
if(indexFound == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",5,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_indexRA",5,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_indexRA","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_indexRA","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_getIList
!#
!####################################
subroutine testAttrVect_getIList(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_getIList => getIList
use m_AttrVect
use m_String,only      : String
use m_String,only      : ptr_chars

implicit none

integer mypid
integer AVui

integer result, length, index

type(String) returnVar
character(len=20)temp1
character(len=20) var
character(len=35) variables


type(AttrVect) :: av

result = 0

var = "date"
length = 32
variables =  "lat:lon:"//var//":time"
index = 3 !This must match the location of 'var' in above line

! initialize vector
call MCT_AtrVt_init(av,iList=variables,lsize=length)
call MCT_AtrVt_getIList(returnVar, index, av)
write(temp1,*)ptr_chars(returnVar)
if (verify(temp1,var)==0) then
   if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_getIList",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_getIList",1,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_getIList","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_getIList","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_getRList
!#
!####################################
subroutine testAttrVect_getRList(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_getRList => getRList
use m_AttrVect
use m_String,only      : String
use m_String,only      : ptr_chars

implicit none

integer mypid
integer AVui

integer result, length, index

type(String) returnVar
character(len=20)temp1
character(len=20) var
character(len=35) variables


type(AttrVect) :: av

result = 0

var = "P"
length = 32
variables =  "T:Q:"//var//":U"
index = 3 !This must match the location of 'var' in above line

! initialize vector
call MCT_AtrVt_init(av,rList=variables,lsize=length)
call MCT_AtrVt_getRList(returnVar, index, av)
write(temp1,*)ptr_chars(returnVar)
if (verify(temp1,var)==0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_getRList",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_getRList",1,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_getRList","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_getRList","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_exportIList
!#
!####################################
subroutine testAttrVect_exportIList(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportIList => exportIList
use m_AttrVect
use m_List,only        : List

implicit none

integer mypid
integer AVui

integer result, length

character(len=35) variables

type(AttrVect) :: av

type(List) vList

length = 32
write(variables,*) "lat:lon:time"

! initialize vector
call MCT_AtrVt_init(av,iList=variables,lsize=length)

call MCT_AtrVt_exportIList(av,vList,result)

if (result == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIList",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIList","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIList",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIList","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_exportRList
!#
!####################################
subroutine testAttrVect_exportRList(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportRList => exportRList
use m_AttrVect
use m_List,only        : List

implicit none

integer mypid
integer AVui

integer result, length

character(len=35) variables

type(AttrVect) :: av

type(List) vList

length = 32
write(variables,*) "T:P:Q"

! initialize vector
call MCT_AtrVt_init(av,rList=variables,lsize=length)

call MCT_AtrVt_exportRList(av,vList,result)

if (result == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRList",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRList","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRList",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRList","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_exportIListToChar
!#
!####################################
subroutine testAttrVect_exportIListToChar(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportIListToChar => exportIListToChar
use m_AttrVect
use m_List,only        : List

implicit none

integer mypid
integer AVui

integer result, length

character(len=35) variables
character(len=35) returnVariables

type(AttrVect) :: av

type(List) vList

length = 32
write(variables,*) "lat:lon:time"

! initialize vector
call MCT_AtrVt_init(av,iList=variables,lsize=length)

write(returnVariables,*) MCT_AtrVt_exportIListToChar(av)

result = verify(variables,returnVariables)

if (result == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIListToChar",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIListToChar","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIListToChar",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIListToChar","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_exportRListToChar
!#
!####################################
subroutine testAttrVect_exportRListToChar(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportRListToChar => exportRListToChar
use m_AttrVect
use m_List,only        : List

implicit none

integer mypid
integer AVui

integer result, length

character(len=35) variables
character(len=35) returnVariables

type(AttrVect) :: av

type(List) vList

length = 32
write(variables,*) "T:Q:P"

! initialize vector
call MCT_AtrVt_init(av,rList=variables,lsize=length)

write(returnVariables,*) MCT_AtrVt_exportRListToChar(av)

result = verify(variables,returnVariables)

if (result == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRListToChar",1,"PASS")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRListToChar","PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRListToChar",1,"FAIL")
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRListToChar","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_appendIAttr
!#
!####################################
subroutine testAttrVect_appendIAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_appendIAttr => appendIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=35) appendVariables

type(AttrVect) :: av

result = 0

length = 32
write(variables,*) "lat:lon"
write(appendVariables,*) "year:month:day"

call MCT_AtrVt_init(av,iList=variables,lsize=length)
call MCT_AtrVt_appendIAttr(av, appendVariables, localResult)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendIAttr",1,"PASS")
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,iList=variables,lsize=length)
call MCT_AtrVt_appendIAttr(av, appendVariables, localResult)
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendIAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendIAttr",2,"FAIL")
  result = 1
endif
call MCT_AtrVt_clean(av)

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_appendIAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_appendIAttr","FAIL")
endif

end subroutine

!####################################
!#
!# Test AttrVect_appendRAttr
!#
!####################################
subroutine testAttrVect_appendRAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_appendRAttr => appendRAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=35) appendVariables

type(AttrVect) :: av

result = 0

length = 32
write(variables,*) "T:Q:P"
write(appendVariables,*) "U:W"

call MCT_AtrVt_init(av,rList=variables,lsize=length)
call MCT_AtrVt_appendRAttr(av, appendVariables, localResult)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendRAttr",1,"PASS")
call MCT_AtrVt_clean(av)

call MCT_AtrVt_init(av,rList=variables,lsize=length)
call MCT_AtrVt_appendRAttr(av, appendVariables, localResult)
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendRAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_appendRAttr",2,"FAIL")
  result = 1
endif
call MCT_AtrVt_clean(av)

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_appendRAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_appendRAttr","FAIL")
endif


end subroutine

!####################################
!#
!# Test AttrVect_exportIAttr
!#
!####################################
subroutine testAttrVect_exportIAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportIAttr => exportIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=4) keyVar

integer, dimension(:),pointer :: out

integer size, i, y

type(AttrVect) :: av

result = 0
localResult = 0

length = 32
keyVar="date"
write(variables,*) "lat:",keyVar,":lon"

i = 4

call MCT_AtrVt_init(av,iList=variables,lsize=length)
av%iAttr=i

nullify(out)
call MCT_AtrVt_exportIAttr(av, keyVar,out)
do y=1,length
if(out(y) /= i)then
  localResult = 1
endif
out(y) = 0
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIAttr",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIAttr",1,"FAIL")
  localResult = 0
  result = 1
endif

deallocate(out)

call MCT_AtrVt_exportIAttr(av, keyVar,out,size)
do y=1,length
if(out(y) /= i)then
  localResult = 1
endif
out(y) = 0
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportIAttr",2,"FAIL")
  localResult = 0
  result = 1
endif

!!! bug? --> call MCT_AtrVt_exportIAttr(av, AttrTag="foo",outVect=out, perrWith="quiet")
if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportIAttr","FAIL")
endif
call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_exportRAttr
!#
!####################################
subroutine testAttrVect_exportRAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_exportRAttr => exportRAttr
use m_AttrVect
use m_realkinds,only : SP,DP,FP

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=1) keyVar

real, dimension(:),pointer :: out

integer size, y

real r

type(AttrVect) :: av

result = 0
localResult = 0

length = 32
keyVar="T"
variables = "P:"//keyVar//":Q"

r = .09_FP

call MCT_AtrVt_init(av,rList=variables,lsize=length)
av%rAttr=r

nullify(out)
call MCT_AtrVt_exportRAttr(av, keyVar,out)
do y=1,length
if(out(y) /= r)then
  localResult = 1
endif
out(y) = 0
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRAttr",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRAttr",1,"FAIL")
  localResult = 0
  result = 1
endif

deallocate(out)

call MCT_AtrVt_exportRAttr(av, keyVar,out,size)
do y=1,length
if(out(y) /= r)then
  localResult = 1
endif
out(y) = 0
enddo
if(localResult == 0)then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_exportRAttr",2,"FAIL")
  localResult = 0
  result = 1
endif

!!! bug? --> call MCT_AtrVt_exportRAttr(av, AttrTag="foo",outVect=out, perrWith="quiet")
if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_exportRAttr","FAIL")
endif
call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_importIAttr
!#
!####################################
subroutine testAttrVect_importIAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_importIAttr => importIAttr
use m_AttrVect,only    : MCT_AtrVt_exportIAttr => exportIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=12) keyVar

integer size, y, i, index

integer,pointer :: importVectP(:)
integer,target :: importVect(32)
integer, dimension(:),pointer :: out

type(AttrVect) :: av

result = 0
localResult = 0

length = 32
keyVar="date"
variables="lat:lon:"//keyVar

i=4
importVect = i
importVectP => importVect

call MCT_AtrVt_init(av,iList=variables,lsize=length)
call MCT_AtrVt_importIAttr(av,TRIM(keyVar),importVectP)

nullify(out)
call MCT_AtrVt_exportIAttr(av,TRIM(keyVar),out)
do y=1,length
if(out(y) /= i)then
  localResult = 1
endif
end do
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importIAttr",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importIAttr",1,"FAIL")
  localResult = 0
  result = 1
endif

deallocate(out)

i=6
importVect = i
importVectP => importVect

call MCT_AtrVt_importIAttr(av,TRIM(keyVar),importVectP,length)
call MCT_AtrVt_exportIAttr(av,TRIM(keyVar),out)
do y=1,length
if(out(y) /= i)then
  localResult = 1
endif
end do
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importIAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importIAttr",2,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_importIAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_importIAttr","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine


!####################################
!#
!# Test AttrVect_importRAttr
!#
!####################################
subroutine testAttrVect_importRAttr(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_importRAttr => importRAttr
use m_AttrVect,only    : MCT_AtrVt_exportRAttr => exportRAttr
use m_AttrVect
use m_realkinds,only : SP,DP,FP

implicit none

integer mypid
integer AVui

integer result, localResult, length

character(len=35) variables
character(len=12) keyVar

integer size, y, index
real r

real,pointer :: importVectP(:)
real,target :: importVect(32)
real, dimension(:),pointer :: out

type(AttrVect) :: av

result = 0
localResult = 0

length = 32
keyVar="T"
variables="Q:P:U:W:"//keyVar

r=0.04_FP
importVect = r
importVectP => importVect

call MCT_AtrVt_init(av,rList=variables,lsize=length)
call MCT_AtrVt_importRAttr(av,TRIM(keyVar),importVectP)
nullify(out)
call MCT_AtrVt_exportRAttr(av,TRIM(keyVar),out)
do y=1,length
if(out(y) /= r)then
  localResult = 1
endif
end do
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importRAttr",1,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importRAttr",1,"FAIL")
  localResult = 0
  result = 1
endif

deallocate(out)

r=0.06_FP
importVect = r
importVectP => importVect

call MCT_AtrVt_importRAttr(av,TRIM(keyVar),importVectP,length)
call MCT_AtrVt_exportRAttr(av,TRIM(keyVar),out)
do y=1,length
if(out(y) /= r)then
  localResult = 1
endif
end do
if (localResult == 0) then
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importRAttr",2,"PASS")
else
  if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_importRAttr",2,"FAIL")
  result = 1
endif

if (result == 0) then
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_importRAttr","PASS")
else
  if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_importRAttr","FAIL")
endif

call MCT_AtrVt_clean(av)

end subroutine

!####################################
!#
!# Test AttrVect_Copy
!#
!####################################
subroutine testAttrVect_copy(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_copy => copy
use m_AttrVect

implicit none

integer mypid
integer AVui

character(len=35) Rvariables, RvariablesOUT
character(len=35) Ivariables, IvariablesOUT

integer result,localResult,length

type(AttrVect) :: avIN, avOUT

result = 0

length = 32
Rvariables="Q:P:U:W"
RvariablesOUT="q:p:u:w"
Ivariables="date:lat:lon"
IvariablesOUT="DATE:LAT:LON"

call MCT_AtrVt_init(avIN,iList=Ivariables,rList=Rvariables,lsize=length)
call MCT_AtrVt_init(avOUT,iList=Ivariables,rList=Rvariables,lsize=length)

call MCT_AtrVt_copy(avIN,avOUT)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",1,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=IvariablesOUT,rList=RvariablesOUT,lsize=length)
call MCT_AtrVt_Copy(avIN,avOUT,iList=Ivariables,TiList=IvariablesOUT)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",2,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=IvariablesOUT,rList=RvariablesOUT,lsize=length)
call MCT_AtrVt_Copy(avIN,avOUT,rList=Rvariables,TrList=RvariablesOUT)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",3,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=IvariablesOUT,rList=RvariablesOUT,lsize=length)
call MCT_AtrVt_Copy(avIN,avOUT,iList=Ivariables,TiList=IvariablesOUT,rList=Rvariables,TrList=RvariablesOUT)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",4,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=IvariablesOUT,rList=RvariablesOUT,lsize=length)
call MCT_AtrVt_Copy(avIN,avOUT,iList=Ivariables,TiList=IvariablesOUT,rList=Rvariables,TrList=RvariablesOUT,vector=.false.)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",5,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=IvariablesOUT,rList=RvariablesOUT,lsize=length)
call MCT_AtrVt_Copy(avIN,avOUT,iList=Ivariables,TiList=IvariablesOUT,rList=Rvariables,TrList=RvariablesOUT,vector=.true.)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",6,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=Ivariables,rList=Rvariables,lsize=length)
call MCT_AtrVt_copy(avIN,avOUT,vector=.true.)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",7,"PASS")
call MCT_AtrVt_clean(avOUT)

call MCT_AtrVt_init(avOUT,iList=Ivariables,rList=Rvariables,lsize=length)
call MCT_AtrVt_copy(avIN,avOUT,vector=.false.)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_copy",8,"PASS")
call MCT_AtrVt_clean(avOUT)

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_copy","PASS")

end subroutine

!####################################
!#
!# Test AttrVect_sort
!#
!####################################
subroutine testAttrVect_sort(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_sort => sort
use m_AttrVect,only    : MCT_AtrVt_nIAttr => nIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
logical,dimension(:), pointer :: des
integer,dimension(:), pointer :: perm

character(len=35) Ivariables

integer result,length

result = 0

length = 32
Ivariables="date:lat:lon"

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",1,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
allocate(des(MCT_AtrVt_nIAttr(av)),stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not allocate des in the AttrVect_sort test."
endif
des = .true.
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,descend=des)
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",2,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .false.
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,descend=des)
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",3,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .true.
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,descend=des,perrWith="ERROR")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",4,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .true.
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,descend=des,perrWith="ERROR",&
                   dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",5,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .true.
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,descend=des,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",6,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,perrWith="ERROR")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",7,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",8,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm,perrWith="ERROR",dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_sort test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sort",9,"PASS")

deallocate(des,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate des in the AttrVect_sort test."
endif

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_sort","PASS")

end subroutine

!####################################
!#
!# Test AttrVect_permute
!#
!####################################
subroutine testAttrVect_permute(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_sort => sort
use m_AttrVect,only    : MCT_AtrVt_permute => permute
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
integer,dimension(:), pointer :: perm

character(len=35) Ivariables

integer result,length

result = 0

length = 32
Ivariables="date:lat:lon"

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_permute(av,perm)
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_permute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_permute",1,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_permute(av,perm,perrWith="ERROR")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_permute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_permute",2,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_permute(av,perm,perrWith="ERROR",dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_permute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_permute",3,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_permute(av,perm,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_permute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_permute",4,"PASS")

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_permute","PASS")

end subroutine


!####################################
!#
!# Test AttrVect_unpermute
!#
!####################################
subroutine testAttrVect_unpermute(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_sort => sort
use m_AttrVect,only    : MCT_AtrVt_unpermute => unpermute
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
integer,dimension(:), pointer :: perm

character(len=35) Ivariables

integer result,length

result = 0

length = 32
Ivariables="date:lat:lon"

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_unpermute(av,perm)
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_unpermute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_unpermute",1,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_unpermute(av,perm,perrWith="ERROR")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_unpermute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_unpermute",2,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_unpermute(av,perm,perrWith="ERROR",dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_unpermute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_unpermute",3,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sort(av=av,key_list=av%iList,perm=perm)
call MCT_AtrVt_unpermute(av,perm,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
deallocate(perm,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate perm in the AttrVect_unpermute test."
endif
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_unpermute",4,"PASS")

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_unpermute","PASS")

end subroutine

!####################################
!#
!# Test AttrVect_sortPermute
!#
!####################################
subroutine testAttrVect_sortPermute(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_sort => sort
use m_AttrVect,only    : MCT_AtrVt_sortPermute => SortPermute
use m_AttrVect,only    : MCT_AtrVt_nIAttr => nIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av
logical,dimension(:), pointer :: des

character(len=35) Ivariables

integer length, result

result = 0

length = 32
Ivariables="date:lat:lon"

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sortPermute(av,key_list=av%iList)
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",1,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
allocate(des(MCT_AtrVt_nIAttr(av)),stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not allocate des in the AttrVect_sortPermute test."
endif
des = .true.
call MCT_AtrVt_sortPermute(av,key_list=av%iList,descend=des)
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",2,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .false.
call MCT_AtrVt_sortPermute(av,key_list=av%iList,descend=des)
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",3,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .true.
call MCT_AtrVt_sortPermute(av,key_list=av%iList,descend=des,perrWith="ERROR")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",4,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sortPermute(av,key_list=av%iList,descend=des,perrWith="ERROR", &
                           dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",5,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sortPermute(av,key_list=av%iList,descend=des,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",6,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
des = .true.
call MCT_AtrVt_sortPermute(av,key_list=av%iList,perrWith="ERROR")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",7,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sortPermute(av,key_list=av%iList,perrWith="ERROR", &
                           dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",8,"PASS")

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_sortPermute(av,key_list=av%iList,dieWith="KILLED JOB")
call MCT_AtrVt_clean(av)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_SortPermute",9,"PASS")

deallocate(des,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate des in the AttrVect_sortPermute test."
endif

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_SortPermute","PASS")

end subroutine

!####################################
!#
!# Test AttrVect_sharedAttrIndexList
!#
!####################################
subroutine testAttrVect_sharedAttrIndexList(mypid,AVui)

use m_AttrVect,only    : MCT_AtrVt_init => init
use m_AttrVect,only    : MCT_AtrVt_clean => clean
use m_AttrVect,only    : MCT_AtrVt_sharedAttrIndexList => SharedAttrIndexList
use m_AttrVect,only    : MCT_AtrVt_nIAttr => nIAttr
use m_AttrVect

implicit none

integer mypid
integer AVui

type(AttrVect) :: av,av2
character(len=35) type
integer numShare
integer, dimension(:),pointer :: indx1,indx2

character(len=35) Ivariables,Ivariables2

integer result,length

result = 0

length = 32
Ivariables="date:lat:lon"
Ivariables2="lat:lon:month:day:year"

call MCT_AtrVt_init(av,iList=Ivariables,lsize=length)
call MCT_AtrVt_init(av2,iList=Ivariables2,lsize=length)
type="integer"
call MCT_AtrVt_sharedAttrIndexList(av,av2,type,numShare,indx1,indx2)
if(mypid .eq. 0) call outputTestStatus(AVui,"AttrVect_sharedAttrIndexList",1,"PASS")
deallocate(indx1,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate indx1 in the AttrVect_sharedAttrIndexList test."
endif
deallocate(indx2,stat=result)
if(result /= 0)then
if(mypid .eq. 0) write(AVui,*)"ERROR: Could not deallocate indx2 in the AttrVect_sharedAttrIndexList test."
endif
call MCT_AtrVt_clean(av)

if(mypid .eq. 0) call outputRoutineStatus(AVui,"AttrVect_sharedAttrIndexList","PASS")

end subroutine
