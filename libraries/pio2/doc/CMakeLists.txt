#==============================================================================
#
#  API documentation with Doxygen
#
#==============================================================================

find_package(Doxygen)

if(DOXYGEN_FOUND)
  # This supports the build with/witout internal documentation.
  if (PIO_INTERNAL_DOC)
    SET(C_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/../src/clib")
  else ()
    SET(C_SRC_FILES
      "${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pioc.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_nc4.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_darray.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_get_nc.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_put_nc.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_varm.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_file.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio.h \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pio_nc.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/topology.c \\
${CMAKE_CURRENT_SOURCE_DIR}/../src/clib/pioc_sc.c" )
  endif ()

  # Process the Doxyfile using options set during configure.
  configure_file(${CMAKE_CURRENT_SOURCE_DIR}/Doxyfile.in
    ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile @ONLY)

  # Copy necessary files.
  add_custom_target(doc
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/customdoxygen.css
    ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/DoxygenLayout.xml
    ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/doxygen.sty
    ${CMAKE_CURRENT_BINARY_DIR}
    COMMAND ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Generating API documentation with Doxygen" VERBATIM)
endif(DOXYGEN_FOUND)
