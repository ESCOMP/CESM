#if defined(_NETCDF4) && defined(LOGGING)
#include <netcdf.h>

int nc_set_log_level2_(int *il)
{
    int i;
    i = nc_set_log_level( *il );
    return(i);
}
#endif
