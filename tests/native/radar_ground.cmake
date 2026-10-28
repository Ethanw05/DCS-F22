# Chat3: independently rebuilt owned ground association/callback cases.
# Integrator includes this fragment from tests/CMakeLists.txt.
foreach(radar_ground_case IN ITEMS tracks callbacks)
    add_executable(f22_radar_ground_${radar_ground_case}
        "${CMAKE_CURRENT_LIST_DIR}/radar_ground_${radar_ground_case}.cpp")
    target_compile_features(f22_radar_ground_${radar_ground_case} PRIVATE cxx_std_23)
    target_include_directories(f22_radar_ground_${radar_ground_case} PRIVATE
        "${PROJECT_SOURCE_DIR}/EFM/include")
    target_compile_definitions(f22_radar_ground_${radar_ground_case} PRIVATE NOMINMAX _USE_MATH_DEFINES)
    if(MSVC)
        target_compile_options(f22_radar_ground_${radar_ground_case} PRIVATE /W4 /WX /analyze)
    endif()
    set_target_properties(f22_radar_ground_${radar_ground_case} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests/$<CONFIG>")
    add_test(NAME replacement_radar_ground_${radar_ground_case}
        COMMAND f22_radar_ground_${radar_ground_case})
endforeach()
