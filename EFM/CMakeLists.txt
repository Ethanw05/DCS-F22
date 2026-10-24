# Portable physics is independent of the Windows/DCS adapter.
add_library(f22_physics STATIC source/FlightModel/FlightModel.cpp)
target_include_directories(f22_physics PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/source")
target_compile_features(f22_physics PUBLIC cxx_std_17)
set_target_properties(f22_physics PROPERTIES CXX_EXTENSIONS OFF)
if(MSVC)
    target_compile_options(f22_physics PRIVATE /W4 /WX)
else()
    target_compile_options(f22_physics PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

if(WIN32)
    add_library(f22 SHARED source/RAPTOR.cpp source/dllmain.cpp)
    target_link_libraries(f22 PRIVATE f22_physics)
    target_include_directories(f22 PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
    target_compile_definitions(f22 PRIVATE NOMINMAX)
    set_target_properties(f22 PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin/$<0:>"
        OUTPUT_NAME "F22"
        DEBUG_POSTFIX ""
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
endif()

if(BUILD_TESTING)
    foreach(test physics callback scenario)
        add_executable(f22_${test}_tests tests/${test}_tests.cpp)
        target_link_libraries(f22_${test}_tests PRIVATE f22_physics)
        add_test(NAME ${test} COMMAND f22_${test}_tests)
    endforeach()
    target_sources(f22_callback_tests PRIVATE source/RAPTOR.cpp)
    target_include_directories(f22_callback_tests PRIVATE include)
    target_compile_definitions(f22_callback_tests PRIVATE F22_HOST_TEST NOMINMAX WIN32_LEAN_AND_MEAN)
    if(NOT WIN32)
        target_include_directories(f22_callback_tests PRIVATE tests/host_stub)
    endif()
endif()
