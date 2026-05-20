cmake_minimum_required(VERSION 3.22)
enable_testing()

add_executable(ring_buffer_test ring_buffer_test.cpp)
target_include_directories(ring_buffer_test PRIVATE ../include)
add_test(NAME ring_buffer COMMAND ring_buffer_test)
