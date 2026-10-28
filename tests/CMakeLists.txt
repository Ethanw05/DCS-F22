# Only independently rebuilt tests are registered. Legacy sources are assigned
# in TEST-RETIREMENT.json and await their accountable owner's replacement.
add_executable(f22_parameter_host native/parameter_host.cpp)
target_compile_features(f22_parameter_host PRIVATE cxx_std_23)
target_include_directories(f22_parameter_host PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_parameter_host PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_parameter_host PRIVATE /W4 /WX /analyze)
endif()
set_target_properties(f22_parameter_host PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests/$<CONFIG>")
add_test(NAME replacement_parameter_transport COMMAND f22_parameter_host)

add_executable(f22_altimetry_requests native/altimetry_requests.cpp)
target_compile_features(f22_altimetry_requests PRIVATE cxx_std_23)
target_include_directories(f22_altimetry_requests PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_altimetry_requests PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_altimetry_requests PRIVATE /W4 /WX /analyze)
endif()
add_test(NAME replacement_altimetry_request_status COMMAND f22_altimetry_requests)

add_executable(f22_altitude_snapshot native/altitude_snapshot.cpp)
target_compile_features(f22_altitude_snapshot PRIVATE cxx_std_23)
target_include_directories(f22_altitude_snapshot PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_altitude_snapshot PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_altitude_snapshot PRIVATE /W4 /WX /analyze)
endif()
add_test(NAME replacement_altitude_snapshot COMMAND f22_altitude_snapshot)

# Reviewed Chat 1 replacement callback ports; no legacy fixture registration.
include(native/flight.cmake)
include(native/weapons.cmake)

add_executable(f22_navigation_inputs native/navigation_inputs.cpp)
target_compile_features(f22_navigation_inputs PRIVATE cxx_std_23)
target_compile_definitions(f22_navigation_inputs PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_navigation_inputs PRIVATE /W4 /WX /analyze)
endif()
add_dependencies(f22_navigation_inputs f22 f22_flight_cockpit f22_flight_world)
add_test(NAME replacement_navigation_input_status COMMAND f22_navigation_inputs
    "$<TARGET_FILE:f22_flight_cockpit>" "$<TARGET_FILE:f22_flight_world>" "$<TARGET_FILE:f22>")
add_test(NAME replacement_native_late_host COMMAND f22_navigation_inputs
    "$<TARGET_FILE:f22_flight_cockpit>" "$<TARGET_FILE:f22_flight_world>" "$<TARGET_FILE:f22>" --late-host)

add_executable(f22_native_control_reads native/native_control_reads.cpp)
target_compile_features(f22_native_control_reads PRIVATE cxx_std_23)
target_include_directories(f22_native_control_reads PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_native_control_reads PRIVATE NOMINMAX _USE_MATH_DEFINES)
if(MSVC)
    target_compile_options(f22_native_control_reads PRIVATE /W4 /WX /analyze)
endif()
add_test(NAME replacement_native_control_read_status COMMAND f22_native_control_reads)

add_executable(f22_datalink_controls native/datalink_controls.cpp)
target_compile_features(f22_datalink_controls PRIVATE cxx_std_23)
target_include_directories(f22_datalink_controls PRIVATE "${PROJECT_SOURCE_DIR}/EFM/include")
target_compile_definitions(f22_datalink_controls PRIVATE NOMINMAX)
if(MSVC)
    target_compile_options(f22_datalink_controls PRIVATE /W4 /WX /analyze)
endif()
add_test(NAME replacement_datalink_control_status COMMAND f22_datalink_controls)

# Reviewed independently rebuilt owner tests. No installed simulator operation.
include(native/radar_admission.cmake)
include(native/radar_ground.cmake)
include(native/radar_model.cmake)
include(native/radar_coordination.cmake)
