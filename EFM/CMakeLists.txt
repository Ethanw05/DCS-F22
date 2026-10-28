cmake_minimum_required(VERSION 3.30)

project(f22_efm LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE f22_sources CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp")
file(GLOB_RECURSE f22_identity_headers CONFIGURE_DEPENDS
    "${CMAKE_CURRENT_SOURCE_DIR}/source/*.h" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.h")
set(f22_identity "${CMAKE_BINARY_DIR}/identity/$<CONFIG>/BuildIdentity.cpp")
add_custom_target(f22_native_identity
    COMMAND "${CMAKE_COMMAND}"
        "-DNATIVE_ROOT=${CMAKE_CURRENT_SOURCE_DIR}"
        "-DOUTPUT=${f22_identity}"
        "-DBUILD_CACHE=${CMAKE_BINARY_DIR}/CMakeCache.txt"
        "-DCOMPILER=${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}"
        "-DCONFIGURATION=$<CONFIG>"
        -P "${CMAKE_SOURCE_DIR}/tools/build_identity.cmake"
    BYPRODUCTS "${f22_identity}"
    DEPENDS ${f22_sources} ${f22_identity_headers} "${CMAKE_CURRENT_LIST_FILE}"
        "${CMAKE_SOURCE_DIR}/tools/build_identity.cmake" "${CMAKE_BINARY_DIR}/CMakeCache.txt"
    VERBATIM)

set_source_files_properties("${f22_identity}" PROPERTIES GENERATED TRUE)
add_library(f22 SHARED ${f22_sources} "${f22_identity}")
add_dependencies(f22 f22_native_identity)
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
