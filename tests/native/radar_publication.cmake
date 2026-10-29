# Integrator includes this fragment only with the paired publication source patch.
# The explicit gate prevents diagnostic failures on the current unpatched owner
# from being advertised as replacement acceptance.
option(F22_RADAR_PUBLICATION_REVIEWED "Enable the reviewed AESA publication replacement" OFF)
if(NOT F22_RADAR_PUBLICATION_REVIEWED)
    return()
endif()

set(radar_publication_root "${CMAKE_CURRENT_LIST_DIR}/../..")
file(READ "${radar_publication_root}/EFM/source/NativeAesaRadar.cpp" radar_publication_source)
string(FIND "${radar_publication_source}" "void invalidate_publication_cache() noexcept"
    radar_publication_patch_marker)
if(radar_publication_patch_marker LESS 0)
    message(FATAL_ERROR "Apply and review the paired AESA publication patch before enabling this test")
endif()

add_executable(f22_radar_publication "${CMAKE_CURRENT_LIST_DIR}/radar_publication.cpp"
    "${radar_publication_root}/EFM/source/AesaRadar.cpp")
target_compile_features(f22_radar_publication PRIVATE cxx_std_23)
target_include_directories(f22_radar_publication PRIVATE
    "${radar_publication_root}/EFM/source" "${radar_publication_root}/EFM/include")
target_compile_definitions(f22_radar_publication PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_radar_publication PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_publication PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
add_test(NAME replacement_radar_publication COMMAND f22_radar_publication)
