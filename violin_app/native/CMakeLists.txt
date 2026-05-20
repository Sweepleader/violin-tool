cmake_minimum_required(VERSION 3.22)
project(violin_audio CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(COMMON_SOURCES
    src/ring_buffer.cpp
    src/audio_bridge.cpp
)

if(WIN32)
    set(PLATFORM_SOURCES src/platform/audio_windows.cpp)
elseif(ANDROID)
    set(PLATFORM_SOURCES src/platform/audio_android.cpp)
else()
    set(PLATFORM_SOURCES src/platform/audio_windows.cpp)
endif()

add_library(violin_audio SHARED ${COMMON_SOURCES} ${PLATFORM_SOURCES})

target_include_directories(violin_audio PUBLIC include/)

if(WIN32)
    target_compile_options(violin_audio PRIVATE /utf-8)
    target_link_libraries(violin_audio PRIVATE ole32 uuid)
endif()
