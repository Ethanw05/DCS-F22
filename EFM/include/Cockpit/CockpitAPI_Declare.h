#pragma once
#include "ccParametersAPI.h"
#include <cmath>
#include <cstdint>

class EDPARAM
{
public:
		EDPARAM() = default; // Host discovery belongs to explicit lifecycle initialization.
		cockpit_param_api ed_param_api{};

        // Staged I-INT-003 port. Explicit initialization/invalidation is used by
        // migrated callers; legacy value-only callers remain tracked until cutover.
        bool initialize() noexcept
        {
            invalidate();
            ed_param_api = ed_get_cockpit_param_api();
            return numericReady() && publicationReady();
        }

        void invalidate() noexcept
        {
            ed_param_api = {};
            ++epoch_;
        }

        std::uint64_t epoch() const noexcept { return epoch_; }

        bool numericReady() const noexcept
        {
            return ed_param_api.pfn_ed_cockpit_get_parameter_handle &&
                ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
        }
        bool publicationReady() const noexcept
        {
            return ed_param_api.pfn_ed_cockpit_get_parameter_handle &&
                ed_param_api.pfn_ed_cockpit_update_parameter_with_number;
        }

        bool getParamNumber(void* handle, double& value) const noexcept
        {
            const auto read = ed_param_api.pfn_ed_cockpit_parameter_value_to_number;
            if (!handle || !read) return false;
            double candidate = 0;
            if (!read(handle, candidate, false) || !std::isfinite(candidate)) return false;
            value = candidate;
            return true;
        }

		void* getParamHandle(const char* name)
		{
			if (!name || !name[0] || !ed_param_api.pfn_ed_cockpit_get_parameter_handle) return nullptr;
			return ed_param_api.pfn_ed_cockpit_get_parameter_handle(name);
		}

		bool setParamNumber(void* handle, double value)
		{
			if (!handle || !std::isfinite(value) || !ed_param_api.pfn_ed_cockpit_update_parameter_with_number) return false;
			ed_param_api.pfn_ed_cockpit_update_parameter_with_number(handle, value);
			return true; // Invocation, not acknowledgement of a physical effect.
		}

		bool setParamString(void* handle, const char* string)
		{
			if (!handle || !string || !ed_param_api.pfn_ed_cockpit_update_parameter_with_string) return false;
			ed_param_api.pfn_ed_cockpit_update_parameter_with_string(handle, string);
			return true;
		}

		inline bool getParamString(void* ptr, char* buffer, unsigned int bufferSize) const
		{
			if (!buffer || bufferSize == 0) return false;
			buffer[0] = '\0';
			const auto read = ed_param_api.pfn_ed_cockpit_parameter_value_to_string;
			if (!ptr || !read || !read(ptr, buffer, bufferSize)) {
				buffer[0] = '\0';
				return false;
			}
			buffer[bufferSize - 1] = '\0';
			return true;
		}

		bool compareParams(void* handle1, void* handle2, int& value) const noexcept
		{
			const auto compare = ed_param_api.pfn_ed_cockpit_compare_parameters;
			if (!handle1 || !handle2 || !compare) return false;
			const int candidate = compare(handle1,handle2);
			if (candidate < -1 || candidate > 1) return false;
			value = candidate;
			return true;
		}
private:
        std::uint64_t epoch_ = 0;
};

