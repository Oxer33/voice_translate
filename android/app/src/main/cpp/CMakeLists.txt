# CMakeLists.txt per VoiceTranslate
# Compila whisper.cpp e llama.cpp come librerie condivise .so per ARM64
# Richiede NDK 25+ e CMake 3.22+

cmake_minimum_required(VERSION 3.22)
project(voice_translate_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# ============================================================
# Ottimizzazioni ARM NEON (abilitato per ARM64)
# ============================================================
if(ANDROID_ABI STREQUAL "arm64-v8a")
    message(STATUS "VoiceTranslate: Abilitazione ottimizzazioni ARM NEON per arm64-v8a")
    add_compile_options(-march=armv8-a+simd -O3 -DNDEBUG)
    add_definitions(-DGGML_USE_NEON)
endif()

# Flag comuni di ottimizzazione
add_compile_options(-fPIC -pthread)

# ============================================================
# whisper.cpp - Libreria per trascrizione STT
# ============================================================
# I sorgenti di whisper.cpp devono essere clonati in questa cartella
# git clone https://github.com/ggerganov/whisper.cpp whisper_cpp

set(WHISPER_DIR ${CMAKE_CURRENT_SOURCE_DIR}/whisper_cpp)

# Verifica che la cartella esista
if(EXISTS ${WHISPER_DIR}/CMakeLists.txt)
    message(STATUS "VoiceTranslate: Trovato whisper.cpp in ${WHISPER_DIR}")

    set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(WHISPER_USE_SYSTEM_GGML OFF CACHE BOOL "" FORCE)

    add_subdirectory(${WHISPER_DIR} ${CMAKE_CURRENT_BINARY_DIR}/whisper_cpp)

    if(NOT TARGET whisper)
        message(FATAL_ERROR "VoiceTranslate: target whisper non generato dal progetto whisper.cpp")
    endif()

    target_link_libraries(whisper PRIVATE
        android
        log
        m
    )

    add_library(voice_translate_whisper SHARED
        ${CMAKE_CURRENT_SOURCE_DIR}/voice_translate_whisper_wrapper.cpp
    )

    target_include_directories(voice_translate_whisper PRIVATE
        ${WHISPER_DIR}/include
    )

    target_link_libraries(voice_translate_whisper PRIVATE
        whisper
        android
        log
        m
    )

    set_target_properties(whisper PROPERTIES
        LINK_FLAGS "-Wl,--no-undefined"
    )

    set_target_properties(voice_translate_whisper PROPERTIES
        LINK_FLAGS "-Wl,--no-undefined"
    )
else()
    message(FATAL_ERROR "VoiceTranslate: whisper.cpp NON trovato in ${WHISPER_DIR}")
endif()

# ============================================================
# NOTE: llama.cpp rimosso nella v2.0 (correzione Phi-3 eliminata)
# Stack ottimizzato: solo Whisper Medium + NLLB-200 ONNX
# ============================================================
