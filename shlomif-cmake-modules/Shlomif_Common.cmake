# Copyright (c) 2012 Shlomi Fish
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
#
# (This copyright notice applies only to this file)

include(CheckIncludeFile)
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckCCompilerFlag)
include(FindPerl)
IF (NOT PERL_FOUND)
    MESSAGE ( FATAL_ERROR "perl must be installed")
ENDIF()

# Taken from http://www.cmake.org/pipermail/cmake/2007-March/013060.html
MACRO(REPLACE_FUNCTIONS sources)
  FOREACH(name ${ARGN})
    STRING(TOUPPER have_${name} SYMBOL_NAME)
    CHECK_FUNCTION_EXISTS(${name} ${SYMBOL_NAME})
    IF(NOT ${SYMBOL_NAME})
      SET(${sources} ${${sources}} ${name}.c)
    ENDIF()
  ENDFOREACH()
ENDMACRO()

MACRO(CHECK_MULTI_INCLUDE_FILES)
  FOREACH(name ${ARGN})
    STRING(TOUPPER have_${name} SYMBOL_NAME)
    STRING(REGEX REPLACE "\\." "_" SYMBOL_NAME ${SYMBOL_NAME})
    STRING(REGEX REPLACE "/" "_" SYMBOL_NAME ${SYMBOL_NAME})
    CHECK_INCLUDE_FILE(${name} ${SYMBOL_NAME})
  ENDFOREACH()
ENDMACRO()

MACRO(CHECK_MULTI_FUNCTIONS_EXISTS)
  FOREACH(name ${ARGN})
    STRING(TOUPPER have_${name} SYMBOL_NAME)
    CHECK_FUNCTION_EXISTS(${name} ${SYMBOL_NAME})
  ENDFOREACH()
ENDMACRO()

MACRO(PREPROCESS_PATH_PERL_WITH_FULL_NAMES TARGET_NAME SOURCE DEST)
    ADD_CUSTOM_COMMAND(
        OUTPUT "${DEST}"
        COMMAND "${PERL_EXECUTABLE}"
        ARGS "${CMAKE_SOURCE_DIR}/cmake/preprocess-path-perl.pl"
            "--input" "${SOURCE}"
            "--output" "${DEST}"
            "--subst" "WML_VERSION=${VERSION}"
            "--subst" "WML_CONFIG_ARGS="
            "--subst" "perlprog=${PERL_EXECUTABLE}"
            "--subst" "perlvers=${PERL_EXECUTABLE}"
            "--subst" "built_system=${CMAKE_SYSTEM_NAME}"
            "--subst" "built_user=${username}"
            "--subst" "built_date=${date}"
            "--subst" "prefix=${CMAKE_INSTALL_PREFIX}"
            "--subst" "bindir=${CMAKE_INSTALL_PREFIX}/bin"
            "--subst" "libdir=${CMAKE_INSTALL_PREFIX}/${WML_LIB_DIR}"
            "--subst" "mandir=${CMAKE_INSTALL_PREFIX}/share/man"
            "--subst" "PATH_PERL=${PERL_EXECUTABLE}"
            "--subst" "INSTALLPRIVLIB=${CMAKE_INSTALL_PREFIX}/${WML_LIB_DIR}"
            "--subst" "INSTALLARCHLIB=${CMAKE_INSTALL_PREFIX}/${WML_LIB_DIR}"
        COMMAND chmod ARGS "a+x" "${DEST}"
        DEPENDS "${SOURCE}"
    )
    # The custom command needs to be assigned to a target.
    ADD_CUSTOM_TARGET(
        ${TARGET_NAME} ALL
        DEPENDS ${DEST}
    )
ENDMACRO()

MACRO(PREPROCESS_PATH_PERL TGT BASE_SOURCE BASE_DEST)
    PREPROCESS_PATH_PERL_WITH_FULL_NAMES ("${TGT}" "${CMAKE_CURRENT_SOURCE_DIR}/${BASE_SOURCE}" "${CMAKE_CURRENT_BINARY_DIR}/${BASE_DEST}")
ENDMACRO()

# Copies the file from one place to the other.
# TGT is the name of the makefile target to add.
# SOURCE is the source path.
# DEST is the destination path.
MACRO(ADD_COPY_TARGET TGT SOURCE DEST)
    ADD_CUSTOM_COMMAND(
        OUTPUT "${DEST}"
        DEPENDS "${SOURCE}"
        COMMAND "${CMAKE_COMMAND}" "-E" "copy" "${SOURCE}" "${DEST}"
    )
    # The custom command needs to be assigned to a target.
    ADD_CUSTOM_TARGET("${TGT}" ALL DEPENDS "${DEST}")
ENDMACRO()

MACRO(RUN_POD2MAN TARGET_DESTS_VARNAME BASE_SOURCE BASE_DEST SECTION CENTER RELEASE)
    SET (DEST "${CMAKE_CURRENT_BINARY_DIR}/${BASE_DEST}")
    IF (POD2MAN_SOURCE_IS_IN_BINARY)
        SET (SOURCE "${CMAKE_CURRENT_BINARY_DIR}/${BASE_SOURCE}")
    ELSE ()
        SET (SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/${BASE_SOURCE}")
    ENDIF ()
    # It is null by default.
    SET (POD2MAN_SOURCE_IS_IN_BINARY )
    ADD_CUSTOM_COMMAND(
        OUTPUT "${DEST}"
        COMMAND "${PERL_EXECUTABLE}"
        ARGS "${CMAKE_SOURCE_DIR}/cmake/pod2man-wrapper.pl"
            "--src" "${SOURCE}"
            "--dest" "${DEST}"
            "--section" "${SECTION}"
            "--center" "${CENTER}"
            "--release" "${RELEASE}"
        DEPENDS "${SOURCE}"
        VERBATIM
    )
    # The custom command needs to be assigned to a target.
    LIST(APPEND "${TARGET_DESTS_VARNAME}" "${DEST}")
ENDMACRO()

MACRO(SIMPLE_POD2MAN TARGET_NAME SOURCE DEST SECTION)
   RUN_POD2MAN("${TARGET_NAME}" "${SOURCE}" "${DEST}.${SECTION}"
       "${SECTION}"
       "EN Tools" "EN Tools"
   )
ENDMACRO()

MACRO(INST_POD2MAN TARGET_NAME SOURCE DEST SECTION)
   SIMPLE_POD2MAN ("${TARGET_NAME}" "${SOURCE}" "${DEST}" "${SECTION}")
   INSTALL_MAN ("${CMAKE_CURRENT_BINARY_DIR}/${DEST}.${SECTION}" "${SECTION}")
ENDMACRO()

MACRO(INST_RENAME_POD2MAN TARGET_NAME SOURCE DEST SECTION INSTNAME)
   SIMPLE_POD2MAN ("${TARGET_NAME}" "${SOURCE}" "${DEST}" "${SECTION}")
   INSTALL_RENAME_MAN ("${DEST}.${SECTION}" "${SECTION}" "${INSTNAME}" "${CMAKE_CURRENT_BINARY_DIR}")
ENDMACRO()

# Finds libm and puts the result in the MATH_LIB_LIST variable.
# If it cannot find it, it fails with an error.
MACRO(FIND_LIBM)
    IF (UNIX)
        FIND_LIBRARY(LIBM_LIB m)
        IF(LIBM_LIB STREQUAL "LIBM_LIB-NOTFOUND")
            MESSAGE(FATAL_ERROR "Cannot find libm")
        ELSE()
            SET(MATH_LIB_LIST ${LIBM_LIB})
        ENDIF()
    ELSE()
        SET(MATH_LIB_LIST)
    ENDIF()
ENDMACRO(FIND_LIBM)

MACRO(INSTALL_MAN SOURCE SECTION)
    INSTALL(
        FILES
            ${SOURCE}
        DESTINATION
            "share/man/man${SECTION}"
    )
ENDMACRO()

MACRO(INSTALL_DATA SOURCE)
    INSTALL(
        FILES
            "${SOURCE}"
        DESTINATION
            "${WML_DATA_DIR}"
    )
ENDMACRO()

MACRO(INSTALL_RENAME_MAN SOURCE SECTION INSTNAME MAN_SOURCE_DIR)
    INSTALL(
        FILES
            "${MAN_SOURCE_DIR}/${SOURCE}"
        DESTINATION
            "share/man/man${SECTION}"
        RENAME
            "${INSTNAME}.${SECTION}"
    )
ENDMACRO()

MACRO(INSTALL_CAT_MAN SOURCE SECTION)
    INSTALL(
        FILES
            "${CMAKE_CURRENT_BINARY_DIR}/${SOURCE}"
        DESTINATION
            "share/man/cat${SECTION}"
    )
ENDMACRO()

MACRO(DEFINE_WML_AUX_PERL_PROG_WITHOUT_MAN BASENAME)
    PREPROCESS_PATH_PERL("preproc_${BASENAME}" "${BASENAME}.src" "${BASENAME}.pl")
    INSTALL(
        PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/${BASENAME}.pl"
        DESTINATION "${WML_LIBEXE_DIR}"
        RENAME "wml_aux_${BASENAME}"
    )
ENDMACRO()

MACRO(DEFINE_WML_AUX_PERL_PROG BASENAME)
    DEFINE_WML_AUX_PERL_PROG_WITHOUT_MAN("${BASENAME}")
    SET (aux_pod_dests )
    RUN_POD2MAN("aux_pod_dests" "${BASENAME}.src" "${BASENAME}.1" "1" "EN  Tools" "En Tools")
    INSTALL_RENAME_MAN ("${BASENAME}.1" 1 "wml_aux_${BASENAME}" "${CMAKE_CURRENT_BINARY_DIR}")
    ADD_CUSTOM_TARGET(
        "pod_${BASENAME}" ALL
        DEPENDS ${aux_pod_dests}
    )
ENDMACRO()

MACRO(DEFINE_WML_AUX_C_PROG_WITHOUT_MAN BASENAME)
    ADD_EXECUTABLE(${BASENAME} ${ARGN})
    SET_TARGET_PROPERTIES("${BASENAME}"
        PROPERTIES OUTPUT_NAME "wml_aux_${BASENAME}"
    )
    INSTALL(
        TARGETS "${BASENAME}"
        DESTINATION "${WML_LIBEXE_DIR}"
    )
ENDMACRO()

MACRO(DEFINE_WML_AUX_C_PROG BASENAME MAN_SOURCE_DIR)
    DEFINE_WML_AUX_C_PROG_WITHOUT_MAN (${BASENAME} ${ARGN})
    INSTALL_RENAME_MAN ("${BASENAME}.1" 1 "wml_aux_${BASENAME}" "${MAN_SOURCE_DIR}")
ENDMACRO()

MACRO(DEFINE_WML_PERL_BACKEND BASENAME DEST_BASENAME)
    PREPROCESS_PATH_PERL(
        "${BASENAME}_preproc" "${BASENAME}.src" "${BASENAME}.pl"
    )
    SET (perl_backend_pod_tests )
    INST_RENAME_POD2MAN(
        "perl_backend_pod_tests" "${BASENAME}.src" "${BASENAME}" "1"
        "${DEST_BASENAME}"
    )
    ADD_CUSTOM_TARGET(
        "${BASENAME}_pod" ALL
        DEPENDS ${perl_backend_pod_tests}
    )
    INSTALL(
        PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/${BASENAME}.pl"
        DESTINATION "${WML_LIBEXE_DIR}"
        RENAME "${DEST_BASENAME}"
    )
ENDMACRO()

MACRO(CHOMP VAR)
    STRING(REGEX REPLACE "[\r\n]+$" "" ${VAR} "${${VAR}}")
ENDMACRO()

MACRO(READ_VERSION_FROM_VER_TXT)

    # Process and extract the version number.
    FILE( READ "${CMAKE_SOURCE_DIR}/ver.txt" VERSION)

    CHOMP (VERSION)

    STRING (REGEX MATCHALL "([0-9]+)" VERSION_DIGITS "${VERSION}")

    LIST(GET VERSION_DIGITS 0 CPACK_PACKAGE_VERSION_MAJOR)
    LIST(GET VERSION_DIGITS 1 CPACK_PACKAGE_VERSION_MINOR)
    LIST(GET VERSION_DIGITS 2 CPACK_PACKAGE_VERSION_PATCH)

ENDMACRO()

MACRO(INSTALL_MAN SOURCE SECTION)
    INSTALL(
        FILES
            ${SOURCE}
        DESTINATION
            "share/man/man${SECTION}"
   )
ENDMACRO()

MACRO(ADD_GCC_DEBUG_WARNING_FLAGS)
    ADD_DEFINITIONS(
        "-Wall"
        "-Werror=implicit-function-declaration"
        "-Wold-style-declaration"
        "-Wmissing-prototypes"
        "-Wformat-nonliteral"
        "-Wcast-align"
        "-Wpointer-arith"
        "-Wbad-function-cast"
        "-Wstrict-prototypes"
        "-Wmissing-declarations"
        "-Wundef"
        "-Wnested-externs"
        "-Wcast-qual"
        "-Wshadow"
        "-Wwrite-strings"
        "-Wunused"
        "-Wold-style-definition"
        )
ENDMACRO()

MACRO(SHLOMIF_PHYS_COPY_FILE FROM TO)
    FILE (READ "${FROM}" contents)
    FILE (WRITE "${TO}" "${contents}")
ENDMACRO()

MACRO(SHLOMIF_COMMON_SETUP private_mod_path)
    SET (private_mod "Shlomif_Common.cmake")
    SET (_dest "${private_mod_path}/${private_mod}")
    IF (NOT EXISTS "${_dest}")
        SHLOMIF_PHYS_COPY_FILE( "/usr/share/cmake/Modules/${private_mod}" "${_dest}")
    ENDIF ()
ENDMACRO()

# Configure paths.
SET (RELATIVE_DATADIR "share")
SET (DATADIR "${CMAKE_INSTALL_PREFIX}/${RELATIVE_DATADIR}")

SET (PKGDATADIR_SUBDIR "freecell-solver")
SET (RELATIVE_PKGDATADIR "${RELATIVE_DATADIR}/${PKGDATADIR_SUBDIR}")
SET (PKGDATADIR "${DATADIR}/${PKGDATADIR_SUBDIR}")

SET (COMPILER_FLAGS_TO_CHECK "-fvisibility=hidden")
MACRO(add_flags)
    LIST(APPEND COMPILER_FLAGS_TO_CHECK ${ARGV})
ENDMACRO ()
MACRO(SHLOMIF_ADD_COMMON_C_FLAGS)
    IF (MSVC)
        MESSAGE(FATAL_ERROR "Error! You are using Microsoft Visual C++ and Freecell Solver Requires a compiler that supports C99 and some GCC extensions. Possible alternatives are GCC, clang and Intel C++ Compiler")
    ENDIF ()

    IF (CPU_ARCH)
        add_flags("-march=${CPU_ARCH}")
    ENDIF ()

    IF (OPTIMIZATION_OMIT_FRAME_POINTER)
        add_flags("-fomit-frame-pointer")
    ENDIF ()

    SET (IS_DEBUG)
    IF ((CMAKE_BUILD_TYPE STREQUAL debug) OR (CMAKE_BUILD_TYPE STREQUAL RelWithDebInfo))
        SET (IS_DEBUG 1)
        # This slows down the program considerably.
        IF (CMAKE_BUILD_TYPE STREQUAL debug)
            add_flags("-DDEBUG=1")
        ENDIF ()

        # Removed these flags because they emitted spurious warnings, which were of
        # no use to us:
        # "-Winline"
        # "-Wfloat-equal"

        IF (${CMAKE_COMPILER_IS_GNUCC})
            ADD_GCC_DEBUG_WARNING_FLAGS()
        ENDIF ()
    ENDIF ()

    IF (${CMAKE_COMPILER_IS_GNUCC})
        SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu11")
        SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++11")
    ENDIF ()

    IF (CMAKE_BUILD_TYPE STREQUAL release)
        add_flags("-flto" "-ffat-lto-objects")
    ENDIF ()

ENDMACRO()

MACRO(SHLOMIF_FINALIZE_FLAGS)
    SET (IDX 1)
    FOREACH (CFLAG_TO_CHECK ${COMPILER_FLAGS_TO_CHECK})
        SET (FLAG_EXISTS_VAR "FLAG_EXISTS_${IDX}")
        MATH (EXPR IDX "${IDX} + 1")
        CHECK_C_COMPILER_FLAG("${CFLAG_TO_CHECK}" ${FLAG_EXISTS_VAR})
        IF (${FLAG_EXISTS_VAR})
            ADD_DEFINITIONS(${CFLAG_TO_CHECK})
            LIST(APPEND MY_LINK_FLAGS "${CFLAG_TO_CHECK}")
        ENDIF ()
    ENDFOREACH()

    SET (MY_EXE_FLAGS)
    FOREACH (CFLAG_TO_CHECK "-fwhole-program")
        SET (FLAG_EXISTS_VAR "FLAG_EXISTS_${IDX}")
        MATH (EXPR IDX "${IDX} + 1")
        CHECK_C_COMPILER_FLAG("${CFLAG_TO_CHECK}" ${FLAG_EXISTS_VAR})
        IF (${FLAG_EXISTS_VAR})
            LIST(APPEND MY_EXE_FLAGS "${CFLAG_TO_CHECK}")
        ENDIF ()
    ENDFOREACH ()
ENDMACRO ()

MACRO(CHECK_FOR_PERL_MODULE MODULE)
    EXECUTE_PROCESS (
        COMMAND "${PERL_EXECUTABLE}" "-M${MODULE}=" "-e" "exit(0)"
        RESULT_VARIABLE "RESULT"
    )
    IF (NOT RESULT EQUAL 0)
        MESSAGE(FATAL_ERROR "Your Perl doesn't have the module ${MODULE}. Please install it.")
    ENDIF ()
ENDMACRO ()

MACRO(CHECK_FOR_MULTIPLE_PERL_MODULES)
    FOREACH (MODULE ${ARGV})
        CHECK_FOR_PERL_MODULE ("${MODULE}")
    ENDFOREACH ()
ENDMACRO ()
