#
# Copyright (C) 2016+ AzerothCore <www.azerothcore.org>
# Copyright (C) 2021+ WarheadCore <https://github.com/WarheadCore>
#
# This file is free software; as a special exception the author gives
# unlimited permission to copy and/or distribute it, with or without
# modifications, as long as this notice is preserved.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY, to the extent permitted by law; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#

set(SCRIPTS_AVAILABLE_OPTIONS none static dynamic minimal-static minimal-dynamic)
set(MODULES_AVAILABLE_OPTIONS none static dynamic)
set(BUILD_APPS_AVAILABLE_OPTIONS none all auth-only world-only)
set(BUILD_TOOLS_AVAILABLE_OPTIONS none all db-only maps-only)

set(SCRIPTS "static" CACHE STRING "Build core with scripts")
set(MODULES "static" CACHE STRING "Build core with modules")
set(APPS_BUILD "all" CACHE STRING "Build list for applications")
set(TOOLS_BUILD "none" CACHE STRING "Build list for tools")

set_property(CACHE SCRIPTS PROPERTY STRINGS ${SCRIPTS_AVAILABLE_OPTIONS})
set_property(CACHE MODULES PROPERTY STRINGS ${MODULES_AVAILABLE_OPTIONS})
set_property(CACHE APPS_BUILD PROPERTY STRINGS ${BUILD_APPS_AVAILABLE_OPTIONS})
set_property(CACHE TOOLS_BUILD PROPERTY STRINGS ${BUILD_TOOLS_AVAILABLE_OPTIONS})

# Log a error when the value of the SCRIPTS variable isn't a valid option.
if(SCRIPTS)
  list(FIND SCRIPTS_AVAILABLE_OPTIONS "${SCRIPTS}" SCRIPTS_INDEX)
  if(${SCRIPTS_INDEX} EQUAL -1)
    message(FATAL_ERROR "The value (${SCRIPTS}) of your SCRIPTS variable is invalid! "
            "Allowed values are: ${SCRIPTS_AVAILABLE_OPTIONS}. Set static")
  endif()
endif()

# Log a error when the value of the MODULES variable isn't a valid option.
if(MODULES)
  list(FIND MODULES_AVAILABLE_OPTIONS "${MODULES}" MODULES_INDEX)
  if(${MODULES_INDEX} EQUAL -1)
    message(FATAL_ERROR "The value (${MODULES}) of your MODULES variable is invalid! "
            "Allowed values are: ${MODULES_AVAILABLE_OPTIONS}. Set static")
  endif()
endif()

# Log a fatal error when the value of the APPS_BUILD variable isn't a valid option.
if(APPS_BUILD)
  list(FIND BUILD_APPS_AVAILABLE_OPTIONS "${APPS_BUILD}" BUILD_APPS_INDEX)
  if(${BUILD_APPS_INDEX} EQUAL -1)
    message(FATAL_ERROR "The value (${APPS_BUILD}) of your APPS_BUILD variable is invalid! "
                        "Allowed values are: ${BUILD_APPS_AVAILABLE_OPTIONS}. Set default")
  endif()
endif()

# Log a fatal error when the value of the TOOLS_BUILD variable isn't a valid option.
if(TOOLS_BUILD)
  list(FIND BUILD_TOOLS_AVAILABLE_OPTIONS "${TOOLS_BUILD}" BUILD_TOOLS_INDEX)
  if(${BUILD_TOOLS_INDEX} EQUAL -1)
    message(FATAL_ERROR "The value (${TOOLS_BUILD}) of your TOOLS_BUILD variable is invalid! "
                        "Allowed values are: ${BUILD_TOOLS_AVAILABLE_OPTIONS}. Set default")
  endif()
endif()

# Build a list of all script modules when -DSCRIPT="custom" is selected
GetScriptModuleList(SCRIPT_MODULE_LIST)
foreach(SCRIPT_MODULE ${SCRIPT_MODULE_LIST})
  ScriptModuleNameToVariable(${SCRIPT_MODULE} SCRIPT_MODULE_VARIABLE)
  set(${SCRIPT_MODULE_VARIABLE} "default" CACHE STRING "Build type of the ${SCRIPT_MODULE} module.")
  set_property(CACHE ${SCRIPT_MODULE_VARIABLE} PROPERTY STRINGS default disabled static dynamic)
endforeach()

# Build a list of all modules script when -DMODULE="custom" is selected
GetModuleSourceList(SCRIPT_MODULE_LIST)
foreach(SCRIPT_MODULE ${SCRIPT_MODULE_LIST})
  ModuleNameToVariable(${SCRIPT_MODULE} SCRIPT_MODULE_VARIABLE)
  set(${SCRIPT_MODULE_VARIABLE} "default" CACHE STRING "Build type of the ${SCRIPT_MODULE} module.")
  set_property(CACHE ${SCRIPT_MODULE_VARIABLE} PROPERTY STRINGS default disabled static dynamic)
endforeach()

# Build a list of all applications when -DBUILD_APPS="custom" is selected
GetApplicationsList(APPLICATIONS_BUILD_LIST)
foreach(APPLICATION_BUILD_NAME ${APPLICATIONS_BUILD_LIST})
  ApplicationNameToVariable(${APPLICATION_BUILD_NAME} APPLICATION_BUILD_VARIABLE)
  set(${APPLICATION_BUILD_VARIABLE} "default" CACHE STRING "Enable build the ${APPLICATION_BUILD_NAME} application.")
  set_property(CACHE ${APPLICATION_BUILD_VARIABLE} PROPERTY STRINGS default enabled disabled)
endforeach()

# Build a list of all applications when -DBUILD_TOOLS="custom" is selected
GetToolsList(TOOLS_BUILD_LIST)
foreach(TOOL_BUILD_NAME ${TOOLS_BUILD_LIST})
  ToolNameToVariable(${TOOL_BUILD_NAME} TOOL_BUILD_VARIABLE)
  set(${TOOL_BUILD_VARIABLE} "default" CACHE STRING "Enable build the ${TOOL_BUILD_NAME} tool.")
  set_property(CACHE ${TOOL_BUILD_VARIABLE} PROPERTY STRINGS default enabled disabled)
endforeach()

option(BUILD_TESTING       "Build unit tests"                                            0)
option(WITH_TEST_COVERAGE  "Build unit tests with code coverage instrumentation"         0)
option(USE_SCRIPTPCH       "Use precompiled headers when compiling scripts"              1)
option(USE_COREPCH         "Use precompiled headers when compiling servers"              1)
option(WITH_GAME_UNITY_BUILD "Compile the game library as a unity build"                0)
option(WITH_WARNINGS       "Show all warnings during compile"                            0)
option(WITH_COREDEBUG      "Include additional debug-code in core"                       0)
option(WITH_PERFTOOLS      "Enable compilation with gperftools libraries included"       0)
option(WITHOUT_GIT         "Disable the GIT testing routines"                            0)
option(ENABLE_VMAP_CHECKS  "Enable Checks relative to DisableMgr system on vmap"         1)
option(WITH_DYNAMIC_LINKING "Enable dynamic library linking."                            0)
option(WITH_STRICT_DATABASE_TYPE_CHECKS "Enable strict checking of database field value accessors" 0)
option(WITHOUT_METRICS     "Disable metrics reporting (i.e. InfluxDB and Grafana)"       0)
option(WITH_DETAILED_METRICS  "Enable detailed metrics reporting (i.e. time each session takes to update)" 0)
option(TOOL_CONFIG_MERGER     "Install the Python config merger tool alongside config files" 0)
option(USE_REAL_LIBSIDECAR "Use real libsidecar and expect that compiled shared lib is in deps/libsidecar folder." 0)

CheckApplicationsBuildList()
CheckToolsBuildList()
IsDynamicLinkingRequired(WITH_DYNAMIC_LINKING_FORCED)
IsDynamicLinkingModulesRequired(WITH_DYNAMIC_LINKING_FORCED)

if(WITH_DYNAMIC_LINKING AND WITH_DYNAMIC_LINKING_FORCED)
  set(WITH_DYNAMIC_LINKING_FORCED OFF)
endif()

if(WITH_DYNAMIC_LINKING OR WITH_DYNAMIC_LINKING_FORCED)
  set(BUILD_SHARED_LIBS ON)
else()
  set(BUILD_SHARED_LIBS OFF)
endif()

# Experimental: keep one statically linked core, but export the annotated
# AC_*_API surface from worldserver so plugins built against the plugin SDK
# import it instead of carrying their own copy of game.
option(COA_PLUGIN_HOST "Export the plugin API from worldserver and load plugins listed in plugins/plugins.lock.json" 0)
if(COA_PLUGIN_HOST)
  if(BUILD_SHARED_LIBS)
    message(FATAL_ERROR "COA_PLUGIN_HOST requires a static core (WITH_DYNAMIC_LINKING OFF, no dynamic modules/scripts).")
  endif()
  add_compile_definitions(COA_PLUGIN_HOST ACORE_API_USE_DYNAMIC_LINKING
    ACORE_API_EXPORT_COMMON ACORE_API_EXPORT_DATABASE ACORE_API_EXPORT_SHARED ACORE_API_EXPORT_GAME)
  if(MSVC)
    # dll-interface warnings are expected: the host is one image, plugins use the same CRT/STL.
    add_compile_options(/wd4251 /wd4275)
  endif()

  # Exact-build ABI fingerprint: plugins built against a different host are refused before
  # they are loaded. Inputs are written next to the header for diagnostics.
  file(GLOB_RECURSE COA_PLUGIN_ABI_HEADERS LIST_DIRECTORIES false
    "${CMAKE_SOURCE_DIR}/src/common/*.h" "${CMAKE_SOURCE_DIR}/src/server/shared/*.h"
    "${CMAKE_SOURCE_DIR}/src/server/database/*.h" "${CMAKE_SOURCE_DIR}/src/server/game/*.h"
    "${CMAKE_SOURCE_DIR}/src/server/coa/*.h")
  list(SORT COA_PLUGIN_ABI_HEADERS)
  set(COA_PLUGIN_ABI_HEADER_DIGESTS "")
  foreach(header ${COA_PLUGIN_ABI_HEADERS})
    # Hash with LF line endings: the same commit must give the same fingerprint whatever the
    # checkout's core.autocrlf (Windows runners convert to CRLF, Linux and most local trees do not).
    file(READ "${header}" header_text)
    string(REPLACE "\r\n" "\n" header_text "${header_text}")
    string(SHA256 header_digest "${header_text}")
    file(RELATIVE_PATH header_rel "${CMAKE_SOURCE_DIR}" "${header}")
    string(APPEND COA_PLUGIN_ABI_HEADER_DIGESTS "${header_rel}=${header_digest}\n")
  endforeach()
  string(SHA256 COA_PLUGIN_ABI_HEADERS_HASH "${COA_PLUGIN_ABI_HEADER_DIGESTS}")
  # The exported API is part of the contract too: a plugin built against an SDK whose import library
  # has a symbol this host does not export would pass the check and fail inside LoadLibrary.
  set(COA_PLUGIN_ABI_EXPORTS_FILE "${CMAKE_SOURCE_DIR}/src/server/apps/worldserver/Plugins/coa_plugin_exports.def")
  set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${COA_PLUGIN_ABI_EXPORTS_FILE}")
  file(READ "${COA_PLUGIN_ABI_EXPORTS_FILE}" exports_text)
  string(REPLACE "\r\n" "\n" exports_text "${exports_text}")
  string(SHA256 COA_PLUGIN_ABI_EXPORTS_HASH "${exports_text}")
  get_directory_property(COA_PLUGIN_ABI_DEFINES COMPILE_DEFINITIONS)
  string(TOUPPER "${CMAKE_BUILD_TYPE}" COA_PLUGIN_ABI_CONFIG)
  set(COA_PLUGIN_ABI_INPUTS
    "pluginApi=1\nplatform=${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}\ncompiler=${CMAKE_CXX_COMPILER_ID}-${CMAKE_CXX_COMPILER_VERSION}\nflags=${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${COA_PLUGIN_ABI_CONFIG}}\ndefines=${COA_PLUGIN_ABI_DEFINES}\nfeatures=MOD_PLAYERBOTS\nheaders=${COA_PLUGIN_ABI_HEADERS_HASH}\nexports=${COA_PLUGIN_ABI_EXPORTS_HASH}\n")
  string(SHA256 COA_PLUGIN_ABI_FINGERPRINT "${COA_PLUGIN_ABI_INPUTS}")
  set(COA_PLUGIN_ABI_DIR "${CMAKE_BINARY_DIR}/coa_plugin")
  file(WRITE "${COA_PLUGIN_ABI_DIR}/coa-plugin-abi-inputs.txt" "${COA_PLUGIN_ABI_INPUTS}fingerprint=${COA_PLUGIN_ABI_FINGERPRINT}\n")
  file(WRITE "${COA_PLUGIN_ABI_DIR}/CoaPluginAbi.h.tmp"
    "#pragma once\n#define COA_PLUGIN_ABI_FINGERPRINT \"${COA_PLUGIN_ABI_FINGERPRINT}\"\n")
  configure_file("${COA_PLUGIN_ABI_DIR}/CoaPluginAbi.h.tmp" "${COA_PLUGIN_ABI_DIR}/CoaPluginAbi.h" COPYONLY)
  include_directories("${COA_PLUGIN_ABI_DIR}")
  message(STATUS "CoA plugin host ABI fingerprint: ${COA_PLUGIN_ABI_FINGERPRINT}")
endif()

# Source tree in IDE
set(WITH_SOURCE_TREE       "hierarchical" CACHE STRING "Build the source tree for IDE's.")
set_property(CACHE WITH_SOURCE_TREE PROPERTY STRINGS no flat hierarchical)

# Config abort
option(CONFIG_ABORT_INCORRECT_OPTIONS "Enable abort if core found incorrect option in config files" 0)
