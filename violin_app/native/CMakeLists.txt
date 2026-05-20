cmake_minimum_required(VERSION 3.22)
project(violin_audio CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(COMMON_SOURCES
    src/ring_buffer.cpp
    src/audio_bridge.cpp
    src/yin_pitch.cpp
)

if(WIN32)
    set(PLATFORM_SOURCES src/platform/audio_windows.cpp)
elseif(ANDROID)
    set(PLATFORM_SOURCES src/platform/audio_android.cpp)
else()
    message(FATAL_ERROR "Unsupported platform — only Windows and Android are supported")
endif()

add_library(violin_audio SHARED ${COMMON_SOURCES} ${PLATFORM_SOURCES})

target_include_directories(violin_audio PUBLIC include/)

# ── RingBuffer unit test ──────────────────────────────────────
add_executable(ring_buffer_test test/ring_buffer_test.cpp)
target_include_directories(ring_buffer_test PRIVATE include)
set_target_properties(ring_buffer_test PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/test")

# ── YIN pitch detection test ─────────────────────────────────
add_executable(yin_pitch_test test/yin_pitch_test.cpp src/yin_pitch.cpp)
target_include_directories(yin_pitch_test PRIVATE include)
set_target_properties(yin_pitch_test PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/test")

if(WIN32)
    target_compile_options(violin_audio PRIVATE /utf-8)
    target_link_libraries(violin_audio PRIVATE ole32 uuid)
endif()
