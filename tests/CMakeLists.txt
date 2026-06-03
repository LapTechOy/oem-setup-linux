find_package(Qt6 REQUIRED COMPONENTS Test)

add_executable(ValidationTest ValidationTest.cpp)
target_link_libraries(ValidationTest PRIVATE Qt6::Test oem_setup_common)
add_test(NAME ValidationTest COMMAND ValidationTest)

