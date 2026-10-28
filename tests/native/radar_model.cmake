# Chat3 independent replacements for six native-model/image legacy artifacts.
foreach(radar_model_case IN ITEMS filter service image)
    add_executable(f22_radar_model_${radar_model_case}
        "${CMAKE_CURRENT_LIST_DIR}/radar_model_${radar_model_case}.cpp")
    target_compile_features(f22_radar_model_${radar_model_case} PRIVATE cxx_std_23)
    target_compile_definitions(f22_radar_model_${radar_model_case} PRIVATE NOMINMAX)
    if(MSVC)
        target_compile_options(f22_radar_model_${radar_model_case} PRIVATE /W4 /WX /analyze)
    endif()
    set_target_properties(f22_radar_model_${radar_model_case} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/tests/$<CONFIG>")
    add_test(NAME replacement_radar_model_${radar_model_case}
        COMMAND f22_radar_model_${radar_model_case})
endforeach()
target_sources(f22_radar_model_service PRIVATE "${PROJECT_SOURCE_DIR}/EFM/source/AesaRadar.cpp")
