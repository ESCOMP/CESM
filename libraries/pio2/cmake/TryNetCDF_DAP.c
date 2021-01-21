/*
 * NetCDF C Test for DAP Support
 */
#include "netcdf_meta.h"

int main()
{
#if NC_HAS_DAP==1
	return 0;
#else
	XXX;
#endif
}
