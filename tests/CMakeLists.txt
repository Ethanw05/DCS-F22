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
