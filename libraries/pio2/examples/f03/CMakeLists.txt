###-------------------------------------------------------------------------###
### CMakeList.txt for examples using pio
###-------------------------------------------------------------------------###

# Adding PIO definitions - defined in the root directory
ADD_DEFINITIONS(${PIO_DEFINITIONS})

# Include PIO include and lib directories
INCLUDE_DIRECTORIES(${PIO_INCLUDE_DIRS})
LINK_DIRECTORIES(${PIO_LIB_DIR})

set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -g -O0")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O0")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0")
if(${PIO_BUILD_TIMING})
  SET(TIMING_LINK_LIB timing)
endif()
SET(SRC examplePio.F90)
ADD_EXECUTABLE(examplePio_f90 ${SRC})
TARGET_LINK_LIBRARIES(examplePio_f90 piof pioc ${TIMING_LINK_LIB})
