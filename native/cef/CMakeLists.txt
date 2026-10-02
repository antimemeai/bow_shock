cmake_minimum_required(VERSION 3.21)
project(BowShockNative LANGUAGES C CXX OBJCXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 20)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

if(NOT APPLE OR NOT CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64")
  message(FATAL_ERROR "This native spike currently requires macOS ARM64")
endif()
if(NOT DEFINED CEF_ROOT)
  message(FATAL_ERROR "Pass the acquired manifest's CEF_ROOT")
endif()
file(STRINGS "${CEF_ROOT}/include/cef_version.h" CEF_PIN_LINE REGEX "^#define CEF_VERSION ")
if(NOT CEF_PIN_LINE STREQUAL "#define CEF_VERSION \"154.0.32+g682c378+chromium-154.0.8037.58\"")
  message(FATAL_ERROR "CEF distribution differs from the adopted runtime pin")
endif()
set(PROJECT_ARCH "arm64")
set(USE_SANDBOX ON CACHE BOOL "CEF sandbox is required" FORCE)
set(api_version "15400" CACHE STRING "Explicit stable matched CEF API" FORCE)
list(APPEND CMAKE_MODULE_PATH "${CEF_ROOT}/cmake")
find_package(CEF REQUIRED)
add_subdirectory("${CEF_LIBCEF_DLL_WRAPPER_PATH}" cef_wrapper)

add_executable(bow_shock MACOSX_BUNDLE main.mm controller_connection.mm observation.mm continuous_clock.mm)
SET_EXECUTABLE_TARGET_PROPERTIES(bow_shock)
target_compile_options(bow_shock PRIVATE -fobjc-arc -fobjc-exceptions -Werror)
target_link_libraries(bow_shock PRIVATE libcef_dll_wrapper ${CEF_STANDARD_LIBS})
set_target_properties(bow_shock PROPERTIES
  OUTPUT_NAME "Bow Shock"
  MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")
set(APP "${CMAKE_BINARY_DIR}/Bow Shock.app")
# The distribution macro's ln -sf follows pre-existing directory symlinks.
# Recreate this staged framework on relink; never modify the adopted source.
add_custom_command(TARGET bow_shock POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E rm -rf
    "${APP}/Contents/Frameworks/Chromium Embedded Framework.framework" VERBATIM)
COPY_MAC_FRAMEWORK(bow_shock "${CEF_BINARY_DIR}" "${APP}")

add_executable(bow_shock_clock_probe "../../tests/native_clock_probe.mm" continuous_clock.mm)
target_include_directories(bow_shock_clock_probe PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_options(bow_shock_clock_probe PRIVATE -fobjc-arc -Wall -Wextra -Werror)
target_link_libraries(bow_shock_clock_probe PRIVATE "-framework Foundation")
add_dependencies(bow_shock bow_shock_clock_probe)

# Independent control/expiry only; this target does not link CEF or input APIs.
add_executable(bow_shock_native_control "../control/main.mm" continuous_clock.mm)
target_include_directories(bow_shock_native_control PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_compile_options(bow_shock_native_control PRIVATE -fobjc-arc -fobjc-exceptions -Wall -Wextra -Werror)
target_link_libraries(bow_shock_native_control PRIVATE "-framework Foundation")
set_target_properties(bow_shock_native_control PROPERTIES OUTPUT_NAME "bow-shock-native-control")
add_dependencies(bow_shock bow_shock_native_control)

foreach(ENTRY IN LISTS CEF_HELPER_APP_SUFFIXES)
  string(REPLACE ":" ";" FIELDS "${ENTRY}")
  list(GET FIELDS 0 NAME_SUFFIX)
  list(GET FIELDS 1 TARGET_SUFFIX)
  list(GET FIELDS 2 HELPER_ID_SUFFIX)
  set(HELPER_NAME "Bow Shock Helper${NAME_SUFFIX}")
  set(HELPER_TARGET "bow_shock_helper${TARGET_SUFFIX}")
  configure_file(helper-Info.plist.in "${CMAKE_BINARY_DIR}/helper${TARGET_SUFFIX}.plist" @ONLY)
  add_executable(${HELPER_TARGET} MACOSX_BUNDLE helper.cc)
  SET_EXECUTABLE_TARGET_PROPERTIES(${HELPER_TARGET})
  target_compile_options(${HELPER_TARGET} PRIVATE -Werror)
  target_link_libraries(${HELPER_TARGET} PRIVATE libcef_dll_wrapper ${CEF_STANDARD_LIBS})
  set_target_properties(${HELPER_TARGET} PROPERTIES OUTPUT_NAME "${HELPER_NAME}"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_BINARY_DIR}/helper${TARGET_SUFFIX}.plist"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/helpers")
  add_dependencies(bow_shock ${HELPER_TARGET})
  add_custom_command(TARGET bow_shock POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_directory
      "${CMAKE_BINARY_DIR}/helpers/${HELPER_NAME}.app"
      "${APP}/Contents/Frameworks/${HELPER_NAME}.app" VERBATIM)
endforeach()

add_custom_command(TARGET bow_shock POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:bow_shock_native_control>"
    "${APP}/Contents/MacOS/bow-shock-native-control"
  COMMAND "${CMAKE_COMMAND}" -E copy "$<TARGET_FILE:bow_shock_clock_probe>"
    "${APP}/Contents/MacOS/bow_shock_clock_probe"
  COMMAND "${CMAKE_COMMAND}" -E copy
    "${CMAKE_CURRENT_SOURCE_DIR}/../../target/release/bow-shock-controller"
    "${APP}/Contents/MacOS/bow-shock-controller"
  COMMAND "${CMAKE_COMMAND}" -E make_directory "${APP}/Contents/Resources"
  COMMAND "${CMAKE_COMMAND}" -E copy "${CEF_ROOT}/LICENSE.txt" "${APP}/Contents/Resources/CEF-LICENSE.txt"
  COMMAND /usr/bin/codesign --force --deep --sign - "${APP}" VERBATIM)
