###-------------------------------------------------------------------------###
### CMakeList.txt for examples using pio
###-------------------------------------------------------------------------###

if (PIO_ENABLE_FORTRAN)
  if ("${PLATFORM}" STREQUAL "goldbach" )
    ADD_SUBDIRECTORY(f03)
  elseif ("${PLATFORM}" STREQUAL "yellowstone" )
    ADD_SUBDIRECTORY(f03)
    ADD_SUBDIRECTORY(c)
  else()
#    ADD_SUBDIRECTORY(f03)
    ADD_SUBDIRECTORY(c)
    #    ADD_SUBDIRECTORY(cxx)
  endif()
else()
  ADD_SUBDIRECTORY(c)
endif()
