# Reviewed owning coordinator status/context checks; explicit host callbacks.
add_executable(f22_radar_ground_coordination "${CMAKE_CURRENT_LIST_DIR}/radar_ground_coordination.cpp")
target_compile_features(f22_radar_ground_coordination PRIVATE cxx_std_23)
target_include_directories(f22_radar_ground_coordination PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_radar_ground_coordination PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_radar_ground_coordination PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_ground_coordination PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
add_test(NAME replacement_radar_ground_coordination COMMAND f22_radar_ground_coordination)
