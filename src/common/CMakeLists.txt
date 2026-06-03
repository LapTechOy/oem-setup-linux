add_library(oem_setup_common STATIC
    Validation.cpp
    Validation.h
)

target_link_libraries(oem_setup_common
    PUBLIC Qt6::Core
)

target_include_directories(oem_setup_common
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
)
