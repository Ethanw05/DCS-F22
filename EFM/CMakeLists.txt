cmake_minimum_required(VERSION 3.30)

project(f22_efm LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE f22_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp")

add_library(f22 SHARED ${f22_sources})
target_include_directories(f22 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_compile_definitions(f22 PRIVATE _USE_MATH_DEFINES NOMINMAX)

set_target_properties(f22 PROPERTIES 
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts/$<CONFIG>"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts/$<CONFIG>"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/artifacts/$<CONFIG>"
    DEBUG_POSTFIX "" 
    RELWITHDEBINFO_POSTFIX "" 
    RELEASE_POSTFIX "" 
    OUTPUT_NAME "f22" 
    MSVC_RUNTIME_LIBRARY "MultiThreadedDLL"
)
# Flight models use the declared MSVC/C++23 ABI. Strong warnings on the DLL
# retain a recorded legacy baseline; new standalone owner code is warning-clean.
if(MSVC)
    target_compile_options(f22 PRIVATE /W4)
    set_source_files_properties("${CMAKE_CURRENT_SOURCE_DIR}/source/RAPTOR.cpp"
        PROPERTIES COMPILE_OPTIONS /analyze)
endif()
