###-------------------------------------------------------------------------###
### CMakeList.txt for examples using pio
###-------------------------------------------------------------------------###

# Include PIO include and lib directories
INCLUDE_DIRECTORIES(${PIO_INCLUDE_DIRS} "${CMAKE_BINARY_DIR}")
include_directories("${CMAKE_SOURCE_DIR}/examples/c")
LINK_DIRECTORIES(${PIO_LIB_DIR})

set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -g -O0")
# Compiler-specific compiler options
if ("${CMAKE_C_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "PGI")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "Intel")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
elseif ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c99")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c99")
endif()
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O0")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0")

ADD_EXECUTABLE(examplePio EXCLUDE_FROM_ALL examplePio.c)
TARGET_LINK_LIBRARIES(examplePio pioc)
add_dependencies(tests examplePio)

ADD_EXECUTABLE(example1 example1.c)
TARGET_LINK_LIBRARIES(example1 pioc)
add_dependencies(tests example1)

ADD_EXECUTABLE(darray_no_async darray_no_async.c)
TARGET_LINK_LIBRARIES(darray_no_async pioc)
add_dependencies(tests darray_no_async)

# ADD_EXECUTABLE(darray_async darray_async.c)
# TARGET_LINK_LIBRARIES(darray_async pioc)
# add_dependencies(tests darray_async)

if (PIO_USE_MPISERIAL)
  add_test(NAME examplePio COMMAND examplePio)
  add_test(NAME example1 COMMAND example1)
else ()
  add_mpi_test(examplePio EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/examplePio NUMPROCS 4 TIMEOUT 60)
  add_mpi_test(example1 EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/example1 NUMPROCS 4 TIMEOUT 60)
  #add_mpi_test(darray_async EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/darray_async NUMPROCS 5 TIMEOUT 60)
  add_mpi_test(darray_no_async EXECUTABLE ${CMAKE_CURRENT_BINARY_DIR}/darray_no_async NUMPROCS 4 TIMEOUT 60)
endif ()


#===== MPE =====
find_package (MPE "2.4.8" COMPONENTS C)
if (PIO_ENABLE_FORTRAN)
  if (MPE_C_FOUND)
    SET(SRC example2.c)
    ADD_EXECUTABLE(example2 ${SRC})
    TARGET_LINK_LIBRARIES(example2 pioc)
    target_include_directories (example2
      PUBLIC ${MPE_C_INCLUDE_DIRS})
    target_compile_definitions (example2
      PUBLIC HAVE_MPE)
    target_link_libraries (example2 pioc lmpe mpe pthread m)
  endif ()
endif ()
