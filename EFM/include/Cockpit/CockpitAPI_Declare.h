#pragma once
#include "ccParametersAPI.h"
#include <limits>

class EDPARAM
{
public:
		EDPARAM()
		{
			ed_param_api = {};
		}
		cockpit_param_api ed_param_api;

		void* getParamHandle(const char* name)
		{
			if (!ed_param_api.pfn_ed_cockpit_get_parameter_handle)
				ed_param_api = ed_get_cockpit_param_api();
			return ed_param_api.pfn_ed_cockpit_get_parameter_handle
				? ed_param_api.pfn_ed_cockpit_get_parameter_handle(name) : nullptr;
		}

		void setParamNumber(void* handle, double value)
		{
			if (handle && ed_param_api.pfn_ed_cockpit_update_parameter_with_number)
				ed_param_api.pfn_ed_cockpit_update_parameter_with_number(handle, value);
		}

		void setParamString(void* handle, const char* string)
		{
			if (handle && ed_param_api.pfn_ed_cockpit_update_parameter_with_string)
				ed_param_api.pfn_ed_cockpit_update_parameter_with_string(handle, string);
		}

		double getParamNumber(void* handle)
		{
			double res = std::numeric_limits<double>::quiet_NaN();
			if (handle && ed_param_api.pfn_ed_cockpit_parameter_value_to_number)
				ed_param_api.pfn_ed_cockpit_parameter_value_to_number(handle, res, false);
			return res;
		}

		inline void getParamString(void* ptr, char* buffer, unsigned int bufferSize) const
		{
			if (ptr && ed_param_api.pfn_ed_cockpit_parameter_value_to_string)
				ed_param_api.pfn_ed_cockpit_parameter_value_to_string(ptr, buffer, bufferSize);
			else if (bufferSize) buffer[0] = '\0';
		}

		int compareParams(void* handle1, void* handle2)
		{
			return handle1 && handle2 && ed_param_api.pfn_ed_cockpit_compare_parameters
				? ed_param_api.pfn_ed_cockpit_compare_parameters(handle1, handle2) : 0;
		}
};

