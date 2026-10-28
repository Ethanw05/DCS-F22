# Include from tests/CMakeLists.txt after the integrator reviews this fragment.
# Actual owner/adapter tests; no old fixture, DLL loading or DCS operation.
set(radar_admission_sources "${CMAKE_CURRENT_LIST_DIR}")
set(radar_admission_root "${CMAKE_CURRENT_LIST_DIR}/../..")
add_executable(f22_radar_packet "${radar_admission_sources}/radar_packet_admission.cpp"
    "${radar_admission_root}/EFM/source/AesaRadar.cpp")
add_executable(f22_radar_camera "${radar_admission_sources}/radar_camera_admission.cpp")
add_executable(f22_radar_tactical_packet "${radar_admission_sources}/radar_tactical_packet.cpp")
foreach(radar_target IN ITEMS f22_radar_packet f22_radar_camera f22_radar_tactical_packet)
    target_compile_features(${radar_target} PRIVATE cxx_std_23)
    target_include_directories(${radar_target} PRIVATE
        "${radar_admission_root}/EFM/include" "${radar_admission_root}/EFM/source")
    target_compile_definitions(${radar_target} PRIVATE NOMINMAX)
    if(MSVC)
        target_compile_options(${radar_target} PRIVATE /W4 /WX /analyze)
    endif()
    set_target_properties(${radar_target} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
endforeach()
add_test(NAME replacement_radar_packet_admission COMMAND f22_radar_packet)
add_test(NAME replacement_radar_camera_admission COMMAND f22_radar_camera)
add_test(NAME replacement_radar_tactical_packet COMMAND f22_radar_tactical_packet)
