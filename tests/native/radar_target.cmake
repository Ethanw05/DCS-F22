# New checked target consumer only; no real payload launch or legacy fixture.
add_executable(f22_radar_ground_target "${CMAKE_CURRENT_LIST_DIR}/radar_ground_target.cpp")
target_compile_features(f22_radar_ground_target PRIVATE cxx_std_23)
target_compile_definitions(f22_radar_ground_target PRIVATE NOMINMAX)
target_include_directories(f22_radar_ground_target PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../../EFM/include")
if(MSVC)
    target_compile_options(f22_radar_ground_target PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_ground_target PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
add_test(NAME replacement_radar_ground_target COMMAND f22_radar_ground_target)
