# Integrator includes this only after reviewing/applying the paired actual Api.
# The old source is an expected-failure diagnostic, not passing acceptance.
option(F22_RADAR_VIDEO_API_PROFILE_REVIEWED "Enable reviewed actual video Api profile tests" OFF)
if(NOT F22_RADAR_VIDEO_API_PROFILE_REVIEWED)
    return()
endif()

add_executable(f22_radar_video_api_profile
    "${CMAKE_CURRENT_LIST_DIR}/radar_video_api_profile.cpp")
target_compile_features(f22_radar_video_api_profile PRIVATE cxx_std_23)
target_compile_definitions(f22_radar_video_api_profile PRIVATE NOMINMAX)
target_include_directories(f22_radar_video_api_profile PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}/../../EFM/include")
if(MSVC)
    target_compile_options(f22_radar_video_api_profile PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_video_api_profile PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
add_test(NAME replacement_radar_video_api_profile COMMAND f22_radar_video_api_profile)

add_executable(f22_radar_video_host_profile "${CMAKE_CURRENT_LIST_DIR}/radar_video_host_profile.cpp")
target_compile_features(f22_radar_video_host_profile PRIVATE cxx_std_23)
if(MSVC)
    target_compile_options(f22_radar_video_host_profile PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_radar_video_host_profile PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/radar/$<CONFIG>")
add_test(NAME replacement_radar_video_host_profile COMMAND f22_radar_video_host_profile)
