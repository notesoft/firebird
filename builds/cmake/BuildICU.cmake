####

function(replace_in_file SOURCE TARGET FILE_PATH)
    file(READ "${FILE_PATH}" FILE_CONTENT)
    string(REPLACE "${SOURCE}" "${TARGET}" FILE_CONTENT "${FILE_CONTENT}" )
    file(WRITE "${FILE_PATH}" "${FILE_CONTENT}")
endfunction()


function(fix_win_crlf FILE_PATH)
    if (NOT WIN32)
        replace_in_file("\\r\\n" "\\n" "${FILE_PATH}")
    endif()        
endfunction()

function(download_and_unzip SOURCE_URL TARGET_PATH)

    file(DOWNLOAD ${SOURCE_URL} ${TARGET_PATH} SHOW_PROGRESS STATUS ICU_DL_STATUS ${ICU_CHECK_HASH})

    # check download result
    list(GET ICU_DL_STATUS 0 ICU_DL_STATUS_CODE)
    if (NOT ICU_DL_STATUS_CODE EQUAL 0)
        message(FATAL_ERROR "download from ${SOURCE_URL} failed with code: ${ICU_DL_STATUS_CODE}")
    endif()

    execute_process(COMMAND unzip "${TARGET_PATH}" -d "${ICU_DIR}")

    file(REMOVE "${TARGET_PATH}")
    
endfunction()

function(build_icu4c ICU_VER)

    string(REGEX MATCH "^([0-9]*)" icu_MAJOR "${ICU_VER}")
    string(REGEX MATCH "[^.]*$"    icu_MINOR "${ICU_VER}")

    set(ICU_DIR       "${CMAKE_CURRENT_BINARY_DIR}/ICU")
    set(ICU_DIR_build "${ICU_DIR}/build")
    set(ICU_DIR_distr "${ICU_DIR}/distr")
    set(ICU_DIR_distr "${ICU_DIR_distr}" PARENT_SCOPE)
    set(ISU_VER_MAJOR "${icu_MAJOR}"     PARENT_SCOPE)
    set(ISU_VER_MINOR "${icu_MINOR}"     PARENT_SCOPE)

    string(REPLACE "." "-" ICU_URL_TAG_VER ${ICU_VER})
    string(REPLACE "." "_" ICU_URL_ARH_VER ${ICU_VER})
    message ("== ICU build ver: ${icu_MAJOR}.${icu_MINOR} dir: ${ICU_DIR} ==")

    # file(REMOVE_RECURSE ${ICU_DIR})

    set(HOST_CC       ${CMAKE_C_COMPILER}) 
    set(HOST_CXX      ${CMAKE_CXX_COMPILER}) 
    set(HOST_CXXFLAGS "") 
    set(HOST_CXXFLAGS "-std=c++20") 
    set(HOST_LDFLAGS  "-static-libstdc++")

    if (APPLE)
        set(ICU_PROC aarch64)
        set(ICU_PROV apple)
        set(ICU_OS   darwin)
        set(icu4c_lib_name "libicuuc.${icu_MAJOR}.${icu_MINOR}.dylib")
    endif()
    if (WIN32)

        # set(HOST_CC       "clang") 
        # set(HOST_CXX      "clang++") 

        set(ICU_PROC x86_64)
        set(ICU_PROV msys)
        set(ICU_OS   windows)
        set(icu4c_lib_name "icuuc${icu_MAJOR}.dll")

        # set(HOST_LDFLAGS  " -lkernel32 -lAdvapi32 -l${clang_rt_lib_dir_win}/clang_rt.builtins-x86_64.lib")
        set(HOST_LDFLAGS  "  -lAdvapi32")
    endif()
    if (LINUX)
        set(ICU_PROC x86_64)
        set(ICU_PROV unknow)
        set(ICU_OS   linux)
        set(icu4c_lib_name "libicuuc.so.${icu_MAJOR}.${icu_MINOR}")
    endif()

    set(ICU_BUILD ${ICU_PROC}-${ICU_PROV}-${ICU_OS})

    if (NOT EXISTS ${ICU_DIR})
        set(icu_URL "https://github.com/unicode-org/icu/releases/download/release-${ICU_URL_TAG_VER}/icu4c-${ICU_URL_ARH_VER}")
        message ("== ICU download from ${icu_URL}")

        make_directory(${ICU_DIR})
        make_directory(${ICU_DIR}/build)

        download_and_unzip("${icu_URL}-src.zip"  "${ICU_DIR}/icu4c-${ICU_BUILD_VER}-src.zip")
        download_and_unzip("${icu_URL}-data.zip" "${ICU_DIR}/icu4c-${ICU_BUILD_VER}-data.zip")

        fix_win_crlf("${ICU_DIR}/icu/source/runConfigureICU")
        fix_win_crlf("${ICU_DIR}/icu/source/configure")
        fix_win_crlf("${ICU_DIR}/icu/source/config.sub")
        fix_win_crlf("${ICU_DIR}/icu/source/mkinstalldirs")

        if (NOT WIN32)
            execute_process(COMMAND cd ${ICU_DIR}/icu/source && chmod +x runConfigureICU configure install-sh config.sub )
        endif()

        
    endif()

        # file(REMOVE_RECURSE ${ICU_DIR_build})
        # file(REMOVE_RECURSE ${ICU_DIR_distr})


    if (NOT EXISTS ${ICU_DIR_distr}/lib/${icu4c_lib_name})

        file(REMOVE_RECURSE ${ICU_DIR_build})
        file(REMOVE_RECURSE ${ICU_DIR_distr})

        make_directory(${ICU_DIR_build})
        make_directory(${ICU_DIR_distr})

        set(HOST_ENV env CFLAGS=${HOST_CFLAGS} CXXFLAGS=${HOST_CXXFLAGS} LDFLAGS=${HOST_LDFLAGS}  CC=${HOST_CC} CXX=${HOST_CXX} )
        
        if (WIN32)

            # file(COPY  mh-unknown "${ICU_DIR}/ICU/icu/source/config/mh-unknown")
            
            execute_process(COMMAND 
                ${CMAKE_VS_MSBUILD_COMMAND} icu/source/allinone/allinone.sln 
                /p:Configuration=Release /t:Rebuild
                /p:Platform=x64            
                WORKING_DIRECTORY ${ICU_DIR}
            )

            file(COPY "${ICU_DIR}/icu/bin64/"      DESTINATION "${ICU_DIR_distr}/lib")

            # file(COPY "${ICU_DIR}/icu/bin64/"      DESTINATION "${ICU_DIR_distr}/lib"  FILES_MATCHING PATTERN "icuin*.dll")
            # file(COPY "${ICU_DIR}/icu/bin64/"      DESTINATION "${ICU_DIR_distr}/lib"  FILES_MATCHING PATTERN "icuuc*")
            # file(COPY "${ICU_DIR}/icu/bin64/"      DESTINATION "${ICU_DIR_distr}/lib"  FILES_MATCHING PATTERN "icudt*")
            # file(COPY "${ICU_DIR}/icu/include/"    DESTINATION "${ICU_DIR_distr}/include")

        else()
            execute_process(COMMAND ${HOST_ENV} ${ICU_DIR}/icu/source/configure 
            --srcdir=../icu/source 
            --host=${ICU_BUILD} 
            --build=${ICU_BUILD} 
            --prefix=${ICU_DIR_distr} 
            --disable-tests 
            --disable-samples 
            WORKING_DIRECTORY ${ICU_DIR_build}) # --with-data-packaging=archive
            execute_process(COMMAND ${HOST_ENV} ${CMAKE_MAKE_PROGRAM} WORKING_DIRECTORY ${ICU_DIR_build})
            execute_process(COMMAND ${HOST_ENV} ${CMAKE_MAKE_PROGRAM} install  WORKING_DIRECTORY ${ICU_DIR_build})
            if (APPLE)
                execute_process(COMMAND install_name_tool -change libicudata.${icu_MAJOR}.dylib @loader_path/libicudata.${icu_MAJOR}.dylib ${ICU_DIR_distr}/lib/${icu4c_lib_name})
            endif()
        endif()

        message("== library icu4c rebuld now ${ICU_DIR_distr}/lib/${icu4c_lib_name} ")
    else()
        message("== library icu4c built earlier  ${ICU_DIR_distr}/lib/${icu4c_lib_name} ")
    endif()
       
endfunction()
