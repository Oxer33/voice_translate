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
if(EXISTS ${WHISPER_DIR}/whisper.cpp)
    message(STATUS "VoiceTranslate: Trovato whisper.cpp in ${WHISPER_DIR}")

    # Sorgenti ggml (backend di whisper.cpp)
    set(WHISPER_GGML_SOURCES
        ${WHISPER_DIR}/ggml/src/ggml.c
        ${WHISPER_DIR}/ggml/src/ggml-alloc.c
        ${WHISPER_DIR}/ggml/src/ggml-backend.c
        ${WHISPER_DIR}/ggml/src/ggml-quants.c
        ${WHISPER_DIR}/ggml/src/ggml-aarch64.c
    )

    # Sorgenti whisper
    set(WHISPER_SOURCES
        ${WHISPER_DIR}/src/whisper.cpp
    )

    # Crea la libreria condivisa libwhisper.so
    add_library(whisper SHARED
        ${WHISPER_GGML_SOURCES}
        ${WHISPER_SOURCES}
    )

    target_include_directories(whisper PUBLIC
        ${WHISPER_DIR}/include
        ${WHISPER_DIR}/ggml/include
        ${WHISPER_DIR}/ggml/src
        ${WHISPER_DIR}/src
    )

    target_compile_definitions(whisper PRIVATE
        GGML_USE_NEON
        WHISPER_SHARED
        WHISPER_BUILD
    )

    target_link_libraries(whisper
        android
        log
        m
    )

    # Esporta i simboli necessari per FFI
    set_target_properties(whisper PROPERTIES
        LINK_FLAGS "-Wl,--no-undefined"
    )
else()
    message(WARNING "VoiceTranslate: whisper.cpp NON trovato in ${WHISPER_DIR}")
    message(WARNING "Esegui: git clone https://github.com/ggerganov/whisper.cpp ${WHISPER_DIR}")
endif()

# ============================================================
# NOTE: llama.cpp rimosso nella v2.0 (correzione Phi-3 eliminata)
# Stack ottimizzato: solo Whisper Medium + NLLB-200 ONNX
# ============================================================
