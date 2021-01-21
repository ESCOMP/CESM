## This file should be placed in the root directory of your project.
## Then modify the CMakeLists.txt file in the root directory of your
## project to incorporate the testing dashboard.
##
## # The following are required to submit to the CDash dashboard:
##   ENABLE_TESTING()
##   INCLUDE(CTest)

set (CTEST_PROJECT_NAME "PIO")
set (CTEST_NIGHTLY_START_TIME "00:00:00 EST")

set (CTEST_DROP_METHOD "http")
if (DEFINED ENV{PIO_DASHBOARD_DROP_SITE})
    set (CTEST_DROP_SITE "$ENV{PIO_DASHBOARD_DROP_SITE}")
else ()
    set (CTEST_DROP_SITE "my.cdash.org")
endif ()
if (DEFINED ENV{PIO_DASHBOARD_PROJECT_NAME})
    set (CTEST_DROP_LOCATION "/submit.php?project=$ENV{PIO_DASHBOARD_PROJECT_NAME}")
else ()
    set (CTEST_DROP_LOCATION "/submit.php?project=PIO")
endif ()
set (CTEST_DROP_SITE_CDASH TRUE)
