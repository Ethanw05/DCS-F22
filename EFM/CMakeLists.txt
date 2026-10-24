cmake_minimum_required(VERSION 3.30)

project(f22_efm LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE f22_sources "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp")

add_library(f22 SHARED ${f22_sources})
target_include_directories(f22 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_definitions(f22 PRIVATE _USE_MATH_DEFINES NOMINMAX)

set_target_properties(f22 PROPERTIES 
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin/$<0:>" 
    DEBUG_POSTFIX "" 
    RELWITHDEBINFO_POSTFIX "" 
    RELEASE_POSTFIX "" 
    OUTPUT_NAME "f22" 
    MSVC_RUNTIME_LIBRARY "MultiThreadedDLL"
)
# Small standalone numerical tests; no DCS SDK or host process is required.
include(CTest)
if(BUILD_TESTING)
    add_executable(f22_high_alpha_test "${CMAKE_SOURCE_DIR}/tests/test_high_alpha.cpp")
    target_include_directories(f22_high_alpha_test PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/source")
    add_test(NAME high_alpha_continuity COMMAND f22_high_alpha_test)
endif()
