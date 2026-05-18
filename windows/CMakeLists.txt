# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
project(dipsmanagment LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "dipsmanagment")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
# firebase_core's Windows CMake script skips extraction when the destination
# directory exists. If a previous build leaves an empty extracted directory,
# configuration fails because firebase targets are missing. Clean this stale
# state proactively before loading generated plugins.

# One-shot recovery from LNK1127 (corrupt firebase_*.lib): set environment
# variable FIREBASE_FORCE_SDK_REDOWNLOAD=1, run flutter run / build once, then unset.
if(DEFINED ENV{FIREBASE_FORCE_SDK_REDOWNLOAD})
  if(NOT "$ENV{FIREBASE_FORCE_SDK_REDOWNLOAD}" STREQUAL "0")
    message(STATUS "FIREBASE_FORCE_SDK_REDOWNLOAD: purging Firebase SDK cache (extracted + zip)")
    if(EXISTS "${CMAKE_BINARY_DIR}/extracted")
      file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
    endif()
    file(GLOB _firebase_force_zips "${CMAKE_BINARY_DIR}/firebase_cpp_sdk_windows_*.zip")
    foreach(_fz IN LISTS _firebase_force_zips)
      file(REMOVE "${_fz}")
    endforeach()
  endif()
endif()

# Determine the Firebase C++ SDK version expected by the firebase_core Windows
# plugin. We'll remove cached extracted contents if they don't match, because
# a version mismatch can lead to compile/link failures (e.g. missing
# Storage::UseEmulator).
set(firebase_core_windows_cmake
  "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks/firebase_core/windows/CMakeLists.txt")
set(firebase_expected_sdk_version "")
if(EXISTS "${firebase_core_windows_cmake}")
  file(READ "${firebase_core_windows_cmake}" _firebase_core_windows_cmake_content)
  string(REGEX MATCH "set\\(FIREBASE_SDK_VERSION \"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\)" _ ${_firebase_core_windows_cmake_content})
  if(CMAKE_MATCH_1)
    set(firebase_expected_sdk_version "${CMAKE_MATCH_1}")
  endif()
endif()

# If extracted exists, verify the SDK version inside it. If it differs from
# the version expected by firebase_core, force a re-download/re-extract.
set(firebase_extracted_version_h "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows/include/firebase/version.h")
if(EXISTS "${firebase_extracted_version_h}" AND NOT "${firebase_expected_sdk_version}" STREQUAL "")
  file(READ "${firebase_extracted_version_h}" _firebase_version_h_content)
  string(REGEX MATCH "FIREBASE_VERSION_MAJOR ([0-9]+)" _ ${_firebase_version_h_content})
  set(_major "${CMAKE_MATCH_1}")
  string(REGEX MATCH "FIREBASE_VERSION_MINOR ([0-9]+)" _ ${_firebase_version_h_content})
  set(_minor "${CMAKE_MATCH_1}")
  string(REGEX MATCH "FIREBASE_VERSION_REVISION ([0-9]+)" _ ${_firebase_version_h_content})
  set(_revision "${CMAKE_MATCH_1}")

  set(_firebase_extracted_sdk_version "${_major}.${_minor}.${_revision}")

  if(NOT "${_firebase_extracted_sdk_version}" STREQUAL "${firebase_expected_sdk_version}")
    message(STATUS "Firebase SDK version mismatch: extracted=${_firebase_extracted_sdk_version} expected=${firebase_expected_sdk_version}. Purging cached extracted/zip.")
    file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
    file(GLOB _cached_firebase_zips "${CMAKE_BINARY_DIR}/firebase_cpp_sdk_windows_*.zip")
    foreach(_zip IN LISTS _cached_firebase_zips)
      file(REMOVE "${_zip}")
    endforeach()
  endif()
endif()

if(EXISTS "${CMAKE_BINARY_DIR}/extracted")
  file(GLOB extracted_children "${CMAKE_BINARY_DIR}/extracted/*")
  list(LENGTH extracted_children extracted_children_count)
  if(extracted_children_count EQUAL 0)
    message(STATUS "Removing stale empty Firebase extracted directory")
    file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
  endif()
endif()
# If any cached firebase_cpp_sdk_windows_*.zip is incomplete/corrupted,
# firebase_core will still extract it and linking fails with LNK1127 on
# firebase_*.lib. Validate every matching zip in the build dir (version is in
# the filename and changes with firebase_core).
file(GLOB _firebase_sdk_zips "${CMAKE_BINARY_DIR}/firebase_cpp_sdk_windows_*.zip")
set(firebase_zip_min_bytes 150000000) # ~150MB; full SDK is much larger
foreach(_zip IN LISTS _firebase_sdk_zips)
  file(SIZE "${_zip}" firebase_zip_size)
  if(firebase_zip_size EQUAL 0 OR firebase_zip_size LESS firebase_zip_min_bytes)
    message(STATUS "Removing invalid Firebase SDK zip (${firebase_zip_size} bytes): ${_zip}")
    file(REMOVE "${_zip}")
    if(EXISTS "${CMAKE_BINARY_DIR}/extracted")
      file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
    endif()
  endif()
endforeach()

# Also ensure extracted content is actually present.
set(firebase_version_h "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows/include/firebase/version.h")
if(EXISTS "${CMAKE_BINARY_DIR}/extracted" AND NOT EXISTS "${firebase_version_h}")
  message(STATUS "Removing Firebase extracted dir missing version.h")
  file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
endif()

# Partial or truncated extraction leaves tiny or missing firebase_firestore.lib
# (LNK1127). If version.h exists, require plausible static lib sizes.
set(_firebase_fs_dbg "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MD/x64/Debug/firebase_firestore.lib")
set(_firebase_fs_rel "${CMAKE_BINARY_DIR}/extracted/firebase_cpp_sdk_windows/libs/windows/VS2019/MD/x64/Release/firebase_firestore.lib")
set(_firebase_lib_min_bytes 5242880) # 5 MB — real libs are much larger
if(EXISTS "${firebase_version_h}")
  set(_firebase_fs_bad FALSE)
  if(EXISTS "${_firebase_fs_dbg}")
    file(SIZE "${_firebase_fs_dbg}" _fs_dbg_sz)
    if(_fs_dbg_sz LESS _firebase_lib_min_bytes)
      set(_firebase_fs_bad TRUE)
    endif()
  endif()
  if(EXISTS "${_firebase_fs_rel}")
    file(SIZE "${_firebase_fs_rel}" _fs_rel_sz)
    if(_fs_rel_sz LESS _firebase_lib_min_bytes)
      set(_firebase_fs_bad TRUE)
    endif()
  endif()
  if(NOT EXISTS "${_firebase_fs_dbg}" AND NOT EXISTS "${_firebase_fs_rel}")
    set(_firebase_fs_bad TRUE)
  endif()
  if(_firebase_fs_bad)
    message(STATUS "Firebase firebase_firestore.lib missing or too small; purging extracted/zip for a clean extract.")
    file(REMOVE_RECURSE "${CMAKE_BINARY_DIR}/extracted")
    file(GLOB _firebase_bad_zips "${CMAKE_BINARY_DIR}/firebase_cpp_sdk_windows_*.zip")
    foreach(_bz IN LISTS _firebase_bad_zips)
      file(REMOVE "${_bz}")
    endforeach()
  endif()
endif()

# Offline / no-DNS builds: if firebase_cpp_sdk is extracted under
# <project>/.firebase_cpp_sdk/firebase_cpp_sdk_windows and its version matches
# firebase_core's FIREBASE_SDK_VERSION, use it instead of downloading from dl.google.com.
set(_firebase_local_sdk_root "${CMAKE_CURRENT_SOURCE_DIR}/../.firebase_cpp_sdk/firebase_cpp_sdk_windows")
set(_firebase_local_version_h "${_firebase_local_sdk_root}/include/firebase/version.h")
if(EXISTS "${_firebase_local_version_h}" AND NOT "${firebase_expected_sdk_version}" STREQUAL "")
  file(READ "${_firebase_local_version_h}" _firebase_local_version_h_content)
  string(REGEX MATCH "FIREBASE_VERSION_MAJOR ([0-9]+)" _ ${_firebase_local_version_h_content})
  set(_firebase_local_major "${CMAKE_MATCH_1}")
  string(REGEX MATCH "FIREBASE_VERSION_MINOR ([0-9]+)" _ ${_firebase_local_version_h_content})
  set(_firebase_local_minor "${CMAKE_MATCH_1}")
  string(REGEX MATCH "FIREBASE_VERSION_REVISION ([0-9]+)" _ ${_firebase_local_version_h_content})
  set(_firebase_local_revision "${CMAKE_MATCH_1}")
  set(_firebase_local_combined
    "${_firebase_local_major}.${_firebase_local_minor}.${_firebase_local_revision}")
  if("${_firebase_local_combined}" STREQUAL "${firebase_expected_sdk_version}")
    message(STATUS "Using local Firebase C++ SDK (offline): ${_firebase_local_sdk_root}")
    set(ENV{FIREBASE_CPP_SDK_DIR} "${_firebase_local_sdk_root}")
  else()
    message(WARNING
      "Local Firebase SDK at ${_firebase_local_sdk_root} is version ${_firebase_local_combined}, "
      "but firebase_core expects ${firebase_expected_sdk_version}. CMake will try to download.")
  endif()
endif()

include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
