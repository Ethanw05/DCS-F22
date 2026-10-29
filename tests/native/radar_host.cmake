add_executable(f22_radar_host_profile "${CMAKE_CURRENT_LIST_DIR}/radar_host_profile.cpp")
target_compile_features(f22_radar_host_profile PRIVATE cxx_std_23)
if(MSVC)
    target_compile_options(f22_radar_host_profile PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_host_profile PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests/$<CONFIG>")
add_test(NAME replacement_radar_host_profile COMMAND f22_radar_host_profile)
