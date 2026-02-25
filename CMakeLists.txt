#
# firebird (trunk)
#
#  This file has following organization:
#  1. cmake settings
#  2. project settings
#  3. packages
#  4. configure
#  5. compiler & linker settings
#  6. pre-build
#  7. build
#

################################################################################
#
# cmake settings
#
################################################################################

cmake_minimum_required(VERSION 3.10.0)

# In-source builds are not possible and so disabled.
if (${CMAKE_CURRENT_SOURCE_DIR} STREQUAL ${CMAKE_CURRENT_BINARY_DIR})
    message(FATAL_ERROR
        "CMake generation for Firebird is not possible within the source directory!"
        "\n Remove the CMakeCache.txt file and try again from another folder, e.g.:"
        "\n "
        "\n rm CMakeCache.txt"
        "\n mkdir build"
        "\n cd build"
        "\n cmake .."
    )
endif()

set(CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/builds/cmake)

if (NATIVE_BUILD_DIR)
    get_filename_component(NATIVE_BUILD_DIR ${NATIVE_BUILD_DIR} ABSOLUTE)
else()
    set(NATIVE_BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR})
endif()

# Use solution folders.
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMake Targets")

################################################################################
#
# project settings
#
################################################################################

project("firebird" C CXX)

########################################
# build type settings
########################################

# Define build mode
if (NOT DEFINED CMAKE_BUILD_TYPE OR "${CMAKE_BUILD_TYPE}" STREQUAL "")
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build.")
endif()

# Qt with MSVC does not have multiconfiguration option by default,
#  so we create it.
set(DEFAULT_CONFIGURATION)

# Set build types if none was specified
if (NOT DEFINED CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_CONFIGURATION_TYPES Debug Release MinSizeRel RelWithDebInfo)
    set(DEFAULT_CONFIGURATION ${CMAKE_BUILD_TYPE})
endif()

########################################
# Output directory settings
########################################

set(output_dir ${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME})
set(boot_dir ${CMAKE_CURRENT_BINARY_DIR}/src)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${output_dir})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${output_dir})

if (MSVC OR XCODE)
    set(output_dir ${output_dir}/$<CONFIG>)
    set(boot_dir ${boot_dir}/$<CONFIG>)
endif()

if (MSVC AND DEFAULT_CONFIGURATION)
    foreach(conf ${CMAKE_CONFIGURATION_TYPES})
        string(TOUPPER ${conf} conf2)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${conf2} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${DEFAULT_CONFIGURATION})
    endforeach()
endif()

if (XCODE)
    foreach(conf ${CMAKE_CONFIGURATION_TYPES})
        string(TOUPPER ${conf} conf2)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${conf2} ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${conf}/bin)
    endforeach()
elseif (UNIX)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${output_dir}/bin)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${output_dir}/bin)
endif()

################################################################################
#
# packages
#
################################################################################



########################################
# icu
########################################

include(builds/cmake/BuildICU.cmake)

    if (${BUILD_ICU_WITH_VER})

        build_icu4c(${BUILD_ICU_WITH_VER})

        set(ICU_INCLUDE_DIR "${ICU_DIR_distr}/include")
            link_directories(${ICU_DIR_distr})
         include_directories(${ICU_DIR_distr}/include)

        if (WIN32)
            set(ICU_VERSION ${ISU_VER_MAJOR})

            string(FIND "${CMAKE_EXE_LINKER_FLAGS}" "/machine:x64" arch)
            if (NOT ${arch} EQUAL -1)
                set(arch "x64")
            else()
                set(arch "Win32")
            endif()

            file(COPY "${ICU_DIR_distr}/lib/"  DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/extern/icu/${arch}/Release/bin FILES_MATCHING PATTERN "icuin*")
            file(COPY "${ICU_DIR_distr}/lib/"  DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/extern/icu/${arch}/Release/bin FILES_MATCHING PATTERN "icuuc*")
            file(COPY "${ICU_DIR_distr}/lib/"  DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/extern/icu/${arch}/Release/bin FILES_MATCHING PATTERN "icudt*")
        endif()

    endif()

if (UNIX)
    if (NOT ICU_INCLUDE_DIR)
        find_path(ICU_INCLUDE_DIR unicode/ucnv.h
            PATHS
                /usr/include
                /usr/include/x86_64-linux-gnu
                /usr/local/include
                /opt/local/include
                /usr/local/opt/icu4c/include
            CMAKE_FIND_ROOT_PATH_BOTH
        )
        if ("${ICU_INCLUDE_DIR}" STREQUAL "ICU_INCLUDE_DIR-NOTFOUND")
            message(FATAL_ERROR "ICU headers not found!")
        endif()
    endif()
    if (CMAKE_CROSSCOMPILING)
        execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${ICU_INCLUDE_DIR}/unicode
            ${CMAKE_CURRENT_BINARY_DIR}/unicode
        )
        set(ICU_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    set(ICU_INCLUDE_DIRS ${ICU_INCLUDE_DIR})
    include_directories(${ICU_INCLUDE_DIRS})
endif()

################################################################################
#
# configure
#
################################################################################

include(builds/cmake/Configure.cmake)

if (FREEBSD)
    # temporary
    set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_BINARY_DIR})
endif()

set(FB_PREFIX ${CMAKE_INSTALL_PREFIX}/${PROJECT_NAME})
set(FB_IPC_NAME "FirebirdIPI")
set(FB_LOGFILENAME "firebird.log")
set(FB_SERVICE_NAME "gds_db")
set(FB_SERVICE_PORT 3050)

if (WIN32)
    set(FB_PREFIX "c:\\\\Program Files\\\\Firebird\\\\")
    set(FB_IPC_NAME "FIREBIRD")
endif()

set(AUTOCONFIG_SRC ${CMAKE_CURRENT_SOURCE_DIR}/src/include/gen/autoconfig.h.in)
set(AUTOCONFIG ${CMAKE_CURRENT_BINARY_DIR}/src/include/gen/autoconfig.h)
configure_file(${AUTOCONFIG_SRC} ${AUTOCONFIG} @ONLY)

################################################################################
#
# compiler & linker settings
#
################################################################################

add_definitions(-DDEV_BUILD)

string(REPLACE "${CMAKE_SOURCE_DIR}" "" OWNER_RROJECTS_TREE "${CMAKE_CURRENT_SOURCE_DIR}" )

if (WIN32)
    set(OS_DIR win32)
    set(VERSION_RC ${CMAKE_CURRENT_SOURCE_DIR}/src/jrd/version.rc)

    if (MSVC)
        set(disable_msvc_warnings "/wd4996")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /MP ${disable_msvc_warnings}")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP ${disable_msvc_warnings}")

        if (MSVC_STATIC_RUNTIME)
            set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} /MTd")
            set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} /MT")
            set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")
            set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
        endif()
    endif(MSVC)

    set(LIB_Ws2_32 Ws2_32)
    set(LIB_comctl32 comctl32)
    set(LIB_mpr mpr)
    set(LIB_version version)
endif(WIN32)

if (MINGW)
    # clear unix-style prefixes
    set(CMAKE_SHARED_LIBRARY_PREFIX)
    set(CMAKE_SHARED_MODULE_PREFIX)
    set(CMAKE_STATIC_LIBRARY_PREFIX)

    # 0x0601 is Windows 7 - see also comments in autoconfig_msvc.h
    add_definitions(-D_WIN32_WINNT=0x0601)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -msse4 -std=c++20")
endif()

if (UNIX)
    set(OS_DIR posix)

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -msse4 -std=c++20")

    if (NOT CMAKE_CROSSCOMPILING)
        # set(LIB_readline readline)
    endif()
    if (NOT FREEBSD)
        set(LIB_dl dl)
    endif()
endif()

if (NOT LINUX AND (CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR IOS))
    if (NOT WIN32)
        set(LIB_iconv iconv)
    endif()
endif()




if (FREEBSD OR APPLE)
    include_directories(/usr/local/include)
    link_directories(/usr/local/lib)
endif()

if (APPLE)
    set(OS_DIR darwin)

    if (NOT CMAKE_CROSSCOMPILING)
        include_directories(/opt/local/include)
        link_directories(/opt/local/lib)
        link_directories(${ICU_DIR}/distr/lib)
        link_directories(/usr/local/opt/icu4c/lib)  
    endif()

    find_library(LIB_CoreFoundation CoreFoundation)
elseif (UNIX)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pthread")
endif()

################################################################################
#
# pre-build
#
################################################################################

if (WIN32)
    # icu
    if (NOT ICU_EXTRACT)
        message(STATUS "Extracting pre-built ICU")
        set(ICU_EXTRACT ${CMAKE_CURRENT_SOURCE_DIR}/extern/icu/icu.exe -y
            CACHE STRING "ICU extraction variable")
        execute_process(COMMAND ${ICU_EXTRACT})
    endif()

	# determine icu version
	foreach(v RANGE 63 83)
		if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/extern/icu/icudt${v}l.dat)
			set(ICU_VERSION ${v} CACHE STRING "ICU version")
		endif()
	endforeach()

    # zlib
    if (NOT ZLIB_EXTRACT)
        message(STATUS "Extracting pre-built zlib")
        set(ZLIB_EXTRACT ${CMAKE_CURRENT_SOURCE_DIR}/extern/zlib/zlib.exe -y
            CACHE STRING "zlib extraction variable")
        execute_process(COMMAND ${ZLIB_EXTRACT})
    endif()
endif()

if (UNIX)
    file(GLOB vers_src "${CMAKE_CURRENT_SOURCE_DIR}/builds/posix/*.vers")
    foreach(f ${vers_src})
        get_filename_component(name ${f} NAME)
        set(name "${CMAKE_CURRENT_BINARY_DIR}/builds/posix/${name}")

        if (AIX)
            file(WRITE ${name} "#!\n")
        elseif (LINUX)
            file(WRITE ${name} "{\nglobal:\n")
        endif()

        file(STRINGS ${f} strings)
        foreach(s ${strings})
            string(REGEX REPLACE "#.*$" "" s "${s}")
            string(STRIP "${s}" s)
            if (NOT "${s}" STREQUAL "")
                if (AIX)
                    file(APPEND ${name} "\t${s}\n")
                elseif (APPLE)
                    file(APPEND ${name} "\t_${s}\n")
                elseif (HPUX)
                    file(APPEND ${name} "+e ${s}\n")
                else()
                    file(APPEND ${name} "\t${s};\n")
                endif()
            endif()
        endforeach()

        if (LINUX)
            file(APPEND ${name} "local:\n\t*;\n};\n")
        endif()
    endforeach()
endif()

################################################################################
#
# build
#
################################################################################

include(builds/cmake/BuildFunctions.cmake)

if (NOT CMAKE_CROSSCOMPILING)

create_boot_commands()
create_master_commands()

endif() # if (NOT CMAKE_CROSSCOMPILING)

crosscompile_prebuild_steps()

# include_directories("/extern/editline/src/editline")

include_directories("extern/re2")
include_directories("extern/boost")


include_directories("extern/decNumber")
include_directories("extern/icu/include")
include_directories("extern/zlib")

include_directories("src/include")
include_directories("src/include/gen")
include_directories("${CMAKE_CURRENT_BINARY_DIR}/src/include")
include_directories("${CMAKE_CURRENT_BINARY_DIR}/src/include/gen")


########################################
# LIBRARY cds
########################################

if (USE_CDS)

    add_definitions(-DCDS_BUILD_STATIC_LIB) # nead global to include .h   
    set(LIB_cds_ID "fb-cds-static")
    file(GLOB cds_src 
        extern/libcds/src/*.cpp
    )  
    add_library                 (${LIB_cds_ID} STATIC ${cds_src})        
    project_group               (${LIB_cds_ID} Extern)
    # target_compile_definitions  (${LIB_cds_ID} PUBLIC CDS_BUILD_STATIC_LIB)

    # #
    # set(LIBCDS_CXX_STANDARD ${CMAKE_CXX_STANDARD})
    # add_definitions( -DCDS_BUILD_STATIC_LIB)   # target_compile_definitions  (cds PUBLIC CDS_BUILD_STATIC_LIB)
    # add_subdirectory(extern/libcds)
    # set(cds "cds-s")
    # if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    #     set(cds "${cds}_d")
    # endif()
    # set(LIB_cds_ID "${cds}")
    # #

    include_directories("${CMAKE_CURRENT_SOURCE_DIR}/extern/libcds")
       link_directories("${CMAKE_CURRENT_BINARY_DIR}/extern/libcds/bin")

    message("use cds library from ${CMAKE_CURRENT_BINARY_DIR}/extern/libcds/bin/")
else()
    add_definitions("-DCDS_UNAVAILABLE")
endif()

########################################
# LIBRARY re2
########################################

file( GLOB re2_src  
 "extern/re2/re2/*.cc" 
 "extern/re2/re2/*.h"
 "extern/re2/util/rune.cc"  
 "extern/re2/util/strutil.cc"
)
add_library                 (re2 ${re2_src})
target_compile_definitions  (re2 PRIVATE NOMINMAX)
project_group               (re2 Extern)

if(BUILD_LIBTOM)

########################################
# LIBRARY libtommath
########################################
    set(libtommath_ID   tommath)

if (LIBTOMMATH_VER)
    set(LIBTOMMATH_DIR "extern/libtommath-${LIBTOMMATH_VER}")
else()
    set(LIBTOMMATH_DIR "extern/libtommath")
endif()    
include_directories("${LIBTOMMATH_DIR}")

    # # test build vith MSVS
    # d: && cd d:/source/COMPONENTS/SQLfb/code/extern/libtommath-1.2
    # "c:/Program Files/Microsoft Visual Studio/18/Community/MSBuild/Current/Bin/MSBuild.exe" libtommath_MSVC15.sln /p:Configuration=Release /t:Rebuild /p:Platform=x64            
    # execute_process(COMMAND 
    # ${CMAKE_VS_MSBUILD_COMMAND} ${LIBTOMMATH_DIR}/libtommath_MSVC15.sln 
    # /p:Configuration=Release /t:Rebuild
    # /p:Platform=x64            
    # WORKING_DIRECTORY ${LIBTOMMATH_DIR})
    # file(COPY "${LIBTOMMATH_DIR}/lib/x64/Release/" DESTINATION "${CMAKE_CURRENT_BINARY_DIR}")
    # set(libtommath_ID   tommath)
    # #

    file(GLOB libtommath_src "${LIBTOMMATH_DIR}/*.c" "${LIBTOMMATH_DIR}/*.h")
    add_library               (${libtommath_ID} ${libtommath_src})
    project_group             (${libtommath_ID} Extern)


if (WIN32 AND USE_TTMATH_MASM)
    add_custom_command(TARGET ${libtommath_ID} PRE_BUILD  
    # COMMAND "${LLVM_win}/bin/llvm-ml.exe" -c --m64 -Fo  # --save-temp-labels 
      COMMAND "/c/Program Files/Microsoft Visual Studio/18/Community/VC/Tools/MSVC/14.50.35717/bin/Hostx64/x64/ml64.exe"  -c -Fo
              "${CMAKE_CURRENT_BINARY_DIR}/ttmathuint_x86_64_msvc.obj"
              "${CMAKE_CURRENT_SOURCE_DIR}/extern/ttmath/ttmathuint_x86_64_msvc.asm"
    )
    set(libtommath_x86_64_masm_obj  "${CMAKE_CURRENT_BINARY_DIR}/ttmathuint_x86_64_msvc.obj")
    target_link_libraries     (${libtommath_ID} ${LIB_builtins_Clang} ${libtommath_x86_64_masm_obj})
    message("use TTMATH MASM")
else()
    message("not use TTMATH MASM")
    add_definitions("-DTTMATH_NOASM")
endif()                             

########################################
# LIBRARY libtomcrypt
########################################

set(libtomcrypt_ID tomcrypt)

file(GLOB_RECURSE libtomcrypt_src "extern/libtomcrypt/src/*")
list(FILTER libtomcrypt_src EXCLUDE REGEX ".*aes_tab.c")
list(FILTER libtomcrypt_src EXCLUDE REGEX ".*whirltab.c")
list(FILTER libtomcrypt_src EXCLUDE REGEX ".*sober128tab.c")

add_library                 (${libtomcrypt_ID} ${libtomcrypt_src})
target_compile_definitions  (${libtomcrypt_ID} PRIVATE LTC_NO_ROLC LTC_SOURCE)
target_link_libraries       (${libtomcrypt_ID} ${libtommath_ID})
project_group               (${libtomcrypt_ID} Extern)
include_directories("extern/libtomcrypt/src/headers")

endif()

########################################
# LIBRARY decNumber
########################################

file(GLOB_RECURSE decNumber_src "extern/decNumber/*.c" "extern/decNumber/*.h")
list(FILTER decNumber_src EXCLUDE REGEX ".*decBasic.c")
list(FILTER decNumber_src EXCLUDE REGEX ".*decCommon.c")

add_library                 (decNumber ${decNumber_src})
project_group               (decNumber Extern)


########################################
# EXECUTABLE btyacc
########################################

file(GLOB btyacc_src "extern/btyacc/*.c" "extern/btyacc/*.h")

if (NOT CMAKE_CROSSCOMPILING)

add_executable          (btyacc ${btyacc_src})
project_group           (btyacc Extern)
set_output_directory    (btyacc . CURRENT_DIR)

endif() # if (NOT CMAKE_CROSSCOMPILING)

########################################
# EXECUTABLE cloop
########################################

file(GLOB cloop_src "extern/cloop/src/cloop/*.cpp" "extern/cloop/src/cloop/*.h")

add_executable          (cloop ${cloop_src})
project_group           (cloop Extern)

########################################
# subdirectories
########################################

add_subdirectory("examples")
add_subdirectory("src")


################################################################################
