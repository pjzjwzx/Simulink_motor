#include "angle_lut_harness_capi_host.h"
static angle_lut_harness_host_DataMapInfo_T root;
static int initialized = 0;
__declspec( dllexport ) rtwCAPI_ModelMappingInfo *getRootMappingInfo()
{
    if (initialized == 0) {
        initialized = 1;
        angle_lut_harness_host_InitializeDataMapInfo(&(root), "angle_lut_harness");
    }
    return &root.mmi;
}

rtwCAPI_ModelMappingInfo *mexFunction(){return(getRootMappingInfo());}
