cmake_minimum_required(VERSION 3.30)
project(f22)

include(CTest)

add_subdirectory("${CMAKE_SOURCE_DIR}/EFM" "${CMAKE_BINARY_DIR}/efm")
