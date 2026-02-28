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
# llama.cpp - Libreria per correzione testo (Phi-3)
# ============================================================
# I sorgenti di llama.cpp devono essere clonati in questa cartella
# git clone https://github.com/ggerganov/llama.cpp llama_cpp

set(LLAMA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/llama_cpp)

if(EXISTS ${LLAMA_DIR}/src/llama.cpp)
    message(STATUS "VoiceTranslate: Trovato llama.cpp in ${LLAMA_DIR}")

    # Sorgenti ggml per llama.cpp (usa la propria copia)
    file(GLOB LLAMA_GGML_SOURCES
        ${LLAMA_DIR}/ggml/src/ggml*.c
        ${LLAMA_DIR}/ggml/src/ggml*.cpp
    )

    # Sorgenti llama
    set(LLAMA_SOURCES
        ${LLAMA_DIR}/src/llama.cpp
        ${LLAMA_DIR}/src/llama-vocab.cpp
        ${LLAMA_DIR}/src/llama-grammar.cpp
        ${LLAMA_DIR}/src/llama-sampling.cpp
        ${LLAMA_DIR}/src/unicode.cpp
        ${LLAMA_DIR}/src/unicode-data.cpp
    )

    # Wrapper semplificato per FFI
    set(LLAMA_WRAPPER_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/llama_wrapper.cpp
    )

    # Crea la libreria condivisa libllama.so
    add_library(llama SHARED
        ${LLAMA_GGML_SOURCES}
        ${LLAMA_SOURCES}
        ${LLAMA_WRAPPER_SOURCES}
    )

    target_include_directories(llama PUBLIC
        ${LLAMA_DIR}/include
        ${LLAMA_DIR}/ggml/include
        ${LLAMA_DIR}/ggml/src
        ${LLAMA_DIR}/src
        ${LLAMA_DIR}/common
    )

    target_compile_definitions(llama PRIVATE
        GGML_USE_NEON
        LLAMA_SHARED
        LLAMA_BUILD
    )

    target_link_libraries(llama
        android
        log
        m
    )

    set_target_properties(llama PROPERTIES
        LINK_FLAGS "-Wl,--no-undefined"
    )
else()
    message(WARNING "VoiceTranslate: llama.cpp NON trovato in ${LLAMA_DIR}")
    message(WARNING "Esegui: git clone https://github.com/ggerganov/llama.cpp ${LLAMA_DIR}")
endif()
