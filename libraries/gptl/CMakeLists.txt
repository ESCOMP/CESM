INCLUDE(FortranCInterface)
FortranCInterface_HEADER(cmake_fortran_c_interface.h
                         MACRO_NAMESPACE  "FCI_")

ADD_DEFINITIONS(${PIO_DEFINITIONS})

SET(TIMING_INCLUDE_DIRS   ${CMAKE_CURRENT_SOURCE_DIR}
                          ${CMAKE_CURRENT_BINARY_DIR}
    CACHE STRING "")
INCLUDE_DIRECTORIES(${TIMING_INCLUDE_DIRS})

ADD_DEFINITIONS(-DINCLUDE_CMAKE_FCI -DHAVE_MPI)

SET(SRCS_C  GPTLget_memusage.c
            GPTLprint_memusage.c
            GPTLutil.c
            f_wrappers.c
            gptl.c
            gptl_papi.c)

SET(SRCS_F90  perf_mod.F90
              perf_utils.F90)

ADD_LIBRARY(timing ${SRCS_F90} ${SRCS_C})
