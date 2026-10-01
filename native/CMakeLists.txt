cmake_minimum_required(VERSION 3.18)
project(gba_core_flutter LANGUAGES C CXX)

# Embed mGBA as a static library only (no Qt/SDL frontends).
set(LIBMGBA_ONLY ON CACHE BOOL "Build only libmgba" FORCE)
set(M_CORE_GBA ON CACHE BOOL "" FORCE)
set(M_CORE_GB OFF CACHE BOOL "" FORCE)
set(BUILD_STATIC ON CACHE BOOL "" FORCE)
set(BUILD_SHARED OFF CACHE BOOL "" FORCE)
set(BUILD_GL OFF CACHE BOOL "" FORCE)
set(BUILD_GLES2 OFF CACHE BOOL "" FORCE)
set(BUILD_GLES3 OFF CACHE BOOL "" FORCE)
set(USE_DEBUGGERS OFF CACHE BOOL "" FORCE)
set(USE_EDITLINE OFF CACHE BOOL "" FORCE)
set(USE_GDB_STUB OFF CACHE BOOL "" FORCE)
set(USE_FFMPEG OFF CACHE BOOL "" FORCE)
set(USE_LUA OFF CACHE BOOL "" FORCE)
set(USE_DISCORD_RPC OFF CACHE BOOL "" FORCE)
set(ENABLE_SCRIPTING OFF CACHE BOOL "" FORCE)
set(BUILD_QT OFF CACHE BOOL "" FORCE)
set(BUILD_SDL OFF CACHE BOOL "" FORCE)
set(BUILD_LIBRETRO OFF CACHE BOOL "" FORCE)
set(BUILD_EXAMPLE OFF CACHE BOOL "" FORCE)
set(DISABLE_FRONTENDS ON CACHE BOOL "" FORCE)
set(DISABLE_DEPS ON CACHE BOOL "" FORCE)

add_subdirectory(mgba)

add_library(gba_core SHARED
  bridge/gba_bridge.c
  bridge/gba_platform_android.c
)

target_include_directories(gba_core PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/bridge
  ${CMAKE_CURRENT_SOURCE_DIR}/mgba/include
  ${CMAKE_CURRENT_BINARY_DIR}/mgba/include
)

target_compile_definitions(gba_core PRIVATE
  GBA_BRIDGE_EXPORTS
  BUILD_STATIC
)

# With LIBMGBA_ONLY + BUILD_STATIC only, the target is named "mgba".
target_link_libraries(gba_core PRIVATE mgba)

if(ANDROID)
  find_library(log-lib log)
  find_library(android-lib android)
  find_library(egl-lib EGL)
  find_library(glesv2-lib GLESv2)
  find_library(aaudio-lib aaudio)
  target_link_libraries(gba_core PRIVATE ${log-lib} ${android-lib} ${egl-lib} ${glesv2-lib} ${aaudio-lib})
  # Keep a clean soname for dart:ffi DynamicLibrary.open
  set_target_properties(gba_core PROPERTIES OUTPUT_NAME "gba_core")
endif()

if(WIN32)
  set_target_properties(gba_core PROPERTIES OUTPUT_NAME "gba_core")
endif()
