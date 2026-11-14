cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided by the Flutter tool
include("${EPHEMERAL_DIR}/generated_config.cmake" OPTIONAL)

# Wrapper library
add_library(flutter_wrapper_app INTERFACE)
target_include_directories(flutter_wrapper_app INTERFACE
  "${EPHEMERAL_DIR}/cpp_client_wrapper/include"
  "${EPHEMERAL_DIR}"
)

# Flutter engine library
add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}"
)
