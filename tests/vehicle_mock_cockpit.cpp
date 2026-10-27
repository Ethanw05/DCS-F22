// Local callback fixture only. This library is never installed in a DCS folder.
#include <map>
#include <string>
#include <cstring>
#include <algorithm>
static std::map<std::string,double> values;
#define API extern "C" __declspec(dllexport)
API void* ed_cockpit_get_parameter_handle(const char* name) { return &values[name]; }
API void ed_cockpit_update_parameter_with_number(void* h,double v) { if(h)*static_cast<double*>(h)=v; }
API bool ed_cockpit_parameter_value_to_number(const void* h,double& out,bool) {
    if(!h)return false;out=*static_cast<const double*>(h);return true;
}
API void ed_cockpit_update_parameter_with_string(void*,const char*) {}
API bool ed_cockpit_parameter_value_to_string(const void*,char* b,unsigned n) {if(n)b[0]=0;return false;}
API int ed_cockpit_compare_parameters(void* a,void* b) {
    double av=a?*static_cast<double*>(a):0,bv=b?*static_cast<double*>(b):0;
    return av==bv?0:(av<bv?-1:1);
}
