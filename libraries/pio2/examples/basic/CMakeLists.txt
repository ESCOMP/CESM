SET(TEMPSRCF90 alloc_mod.F90)
FOREACH(tempfile IN LISTS TEMPSRCF90)
ADD_CUSTOM_COMMAND(
	OUTPUT ${tempfile}
	COMMAND ${GENF90_PATH}/genf90.pl ${CMAKE_CURRENT_SOURCE_DIR}/${tempfile}.in > ${tempfile}
	DEPENDS  ${tempfile}.in
)
ENDFOREACH()

SET(SRC check_mod.F90  gdecomp_mod.F90  kinds_mod.F90  namelist_mod.F90  
            testpio.F90  utils_mod.F90 ${TEMPSRCF90})
SET(WSSRC wstest.c)

INCLUDE_DIRECTORIES(${PIO_INCLUDE_DIRS})
LINK_DIRECTORIES(${PIO_LIB_DIR})
ADD_EXECUTABLE(testpio ${SRC})
ADD_EXECUTABLE(wstest ${WSSRC})
if(${PIO_BUILD_TIMING} MATCHES "ON") 
  SET(TIMING_LINK_LIB timing)
endif()

if(NETCDF_FOUND)
  TARGET_LINK_LIBRARIES(testpio piof pioc ${NETCDF_Fortran_LIBRARY} ${TIMING_LINK_LIB})
else()
  TARGET_LINK_LIBRARIES(testpio piof pioc ${TIMING_LINK_LIB})
endif()
TARGET_LINK_LIBRARIES(wstest pioc ${TIMING_LINK_LIB})





