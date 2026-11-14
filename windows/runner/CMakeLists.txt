cmake_minimum_required(VERSION 3.14)
project(runner LANGUAGES CXX)

set(BINARY_NAME "cinematic_music_player")

add_executable(${BINARY_NAME} WIN32
  "flutter_window.cpp"
  "main.cpp"
  "utils.cpp"
  "win32_window.cpp"
  "Runner.rc"
)

apply_standard_settings(${BINARY_NAME})
target_compile_definitions(${BINARY_NAME} PRIVATE "_HAS_EXCEPTIONS=0")
target_compile_definitions(${BINARY_NAME} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
