cmake_minimum_required(VERSION 3.30)
project(f22)

# Building never installs into the checkout or the user's DCS mod.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_BINARY_DIR)
    message(FATAL_ERROR "Use an external build directory: cmake -S . -B <build-dir>")
endif()

include(CTest)

add_subdirectory("${CMAKE_SOURCE_DIR}/EFM" "${CMAKE_BINARY_DIR}/efm")

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()
