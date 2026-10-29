add_executable(f22_radar_interleave "${CMAKE_CURRENT_LIST_DIR}/radar_interleave.cpp"
    "${PROJECT_SOURCE_DIR}/EFM/source/AesaRadar.cpp")
target_compile_features(f22_radar_interleave PRIVATE cxx_std_23)
target_include_directories(f22_radar_interleave PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_radar_interleave PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_radar_interleave PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_interleave PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests/$<CONFIG>")
add_test(NAME replacement_radar_interleave COMMAND f22_radar_interleave)
