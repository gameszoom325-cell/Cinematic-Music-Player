cmake_minimum_required(VERSION 3.14)
project(cinematic_music_player LANGUAGES CXX)

set(BINARY_NAME "cinematic_music_player")

cmake_policy(SET CMP0079 NEW)

# Flutter CMake build configuration
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Flutter build system integration
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Add runner executable
add_subdirectory("runner")

# Generated plugin build rules
include(flutter/generated_plugins.cmake OPTIONAL)
