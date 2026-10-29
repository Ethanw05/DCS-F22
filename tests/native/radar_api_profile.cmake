# Register only after the exact paired current-host source/Query ABI is reviewed.
# An unregistered test is not a passing test. Shared tests/CMakeLists stays owned
# by the integrator; this fragment does not change a runtime capability flag.
if(F22_RADAR_CURRENT_HOST_REVIEWED)
    add_executable(f22_radar_api_profile
        "${CMAKE_CURRENT_LIST_DIR}/radar_api_profile.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/../../EFM/source/AesaRadar.cpp")
    target_compile_features(f22_radar_api_profile PRIVATE cxx_std_23)
    target_compile_definitions(f22_radar_api_profile PRIVATE NOMINMAX RADAR_CURRENT_HOST_REVIEWED)
    target_include_directories(f22_radar_api_profile PRIVATE
        "${CMAKE_CURRENT_LIST_DIR}/../../EFM/include")
    if(MSVC)
        target_compile_options(f22_radar_api_profile PRIVATE /W4 /WX /analyze)
    endif()
    set_target_properties(f22_radar_api_profile PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
    add_test(NAME replacement_radar_api_profile COMMAND f22_radar_api_profile)
else()
    message(STATUS "Actual radar Api profile fixture unregistered: paired host source review pending")
endif()
