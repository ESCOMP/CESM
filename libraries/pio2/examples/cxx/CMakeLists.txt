###-------------------------------------------------------------------------###
### CMakeList.txt for examples using pio
###-------------------------------------------------------------------------###

# Adding PIO definitions - defined in the root directory
ADD_DEFINITIONS(${PIO_DEFINITIONS})

INCLUDE_DIRECTORIES(${PIO_INCLUDE_DIRS})
LINK_DIRECTORIES(${PIO_LIB_DIR})

SET(SRC examplePio.cxx)
ADD_EXECUTABLE(examplePio_cxx ${SRC})
