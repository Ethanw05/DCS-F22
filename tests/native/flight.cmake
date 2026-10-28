# Include from the replacement test directory after integration review.
# An external fixture-only project may supply F22_FLIGHT_DLL explicitly.
set(flight_sources "${CMAKE_CURRENT_LIST_DIR}")
add_library(f22_flight_cockpit SHARED "${flight_sources}/flight_cockpit.cpp")
add_library(f22_flight_world SHARED "${flight_sources}/flight_world.cpp")
add_executable(f22_flight_callbacks "${flight_sources}/flight_callbacks.cpp")
set_target_properties(f22_flight_cockpit PROPERTIES OUTPUT_NAME CockpitBase)
set_target_properties(f22_flight_world PROPERTIES OUTPUT_NAME World)
foreach(flight_target IN ITEMS f22_flight_cockpit f22_flight_world f22_flight_callbacks)
    target_compile_features(${flight_target} PRIVATE cxx_std_23)
    target_compile_definitions(${flight_target} PRIVATE NOMINMAX)
    if(MSVC)
        target_compile_options(${flight_target} PRIVATE /W4 /WX /analyze)
    endif()
    set_target_properties(${flight_target} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/flight/$<CONFIG>"
        ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/flight/$<CONFIG>")
endforeach()
if(TARGET f22)
    set(flight_dll "$<TARGET_FILE:f22>")
    add_dependencies(f22_flight_callbacks f22)
elseif(F22_FLIGHT_DLL)
    set(flight_dll "${F22_FLIGHT_DLL}")
else()
    message(FATAL_ERROR "An explicit externally built aircraft DLL is required")
endif()
add_test(NAME replacement_flight_callbacks COMMAND f22_flight_callbacks
    "$<TARGET_FILE:f22_flight_cockpit>" "$<TARGET_FILE:f22_flight_world>" "${flight_dll}")
