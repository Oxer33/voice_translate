#include "whisper.h"

#include <algorithm>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>

namespace {

std::mutex g_whisper_mutex;
whisper_context * g_cached_ctx = nullptr;
std::string g_cached_model_path;

void copy_to_buffer(const std::string & value, char * buffer, int capacity) {
    if (buffer == nullptr || capacity <= 0) {
        return;
    }

    const size_t writable = std::min(value.size(), static_cast<size_t>(capacity - 1));
    if (writable > 0) {
        std::memcpy(buffer, value.c_str(), writable);
    }
    buffer[writable] = '\0';
}

int default_thread_count() {
    const unsigned int hw = std::thread::hardware_concurrency();
    if (hw == 0) {
        return 2;
    }
    return std::max(1, std::min(4, static_cast<int>(hw)));
}

whisper_context * get_or_create_context(const char * model_path) {
    if (model_path == nullptr || model_path[0] == '\0') {
        return nullptr;
    }

    const std::string requested_model_path(model_path);
    if (g_cached_ctx != nullptr && g_cached_model_path == requested_model_path) {
        return g_cached_ctx;
    }

    if (g_cached_ctx != nullptr) {
        whisper_free(g_cached_ctx);
        g_cached_ctx = nullptr;
        g_cached_model_path.clear();
    }

    whisper_context_params context_params = whisper_context_default_params();
    g_cached_ctx = whisper_init_from_file_with_params(model_path, context_params);
    if (g_cached_ctx != nullptr) {
        g_cached_model_path = requested_model_path;
    }

    return g_cached_ctx;
}

}  // namespace

extern "C" int voice_translate_whisper_transcribe(
    const char * model_path,
    const float * samples,
    int n_samples,
    const char * language,
    char * output_text,
    int output_text_capacity,
    char * detected_language,
    int detected_language_capacity
) {
    if (model_path == nullptr || samples == nullptr || n_samples <= 0) {
        return -1;
    }

    std::lock_guard<std::mutex> lock(g_whisper_mutex);
    whisper_context * ctx = get_or_create_context(model_path);
    if (ctx == nullptr) {
        return -2;
    }

    int status = 0;

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = default_thread_count();
    params.translate = false;
    params.no_context = true;
    params.no_timestamps = true;
    params.single_segment = true;
    params.print_special = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.token_timestamps = false;

    const bool has_language = language != nullptr && language[0] != '\0' && std::strcmp(language, "auto") != 0;
    params.language = has_language ? language : nullptr;
    params.detect_language = !has_language;

    const int result = whisper_full(ctx, params, samples, n_samples);
    if (result != 0) {
        return -3;
    }

    std::string combined_text;
    const int n_segments = whisper_full_n_segments(ctx);
    for (int i = 0; i < n_segments; ++i) {
        const char * segment = whisper_full_get_segment_text(ctx, i);
        if (segment != nullptr) {
            combined_text += segment;
        }
    }

    const int lang_id = whisper_full_lang_id(ctx);
    const char * lang = lang_id >= 0 ? whisper_lang_str(lang_id) : nullptr;

    copy_to_buffer(combined_text, output_text, output_text_capacity);
    copy_to_buffer(lang != nullptr ? std::string(lang) : std::string(), detected_language, detected_language_capacity);

    return status;
}

extern "C" int voice_translate_whisper_validate_model(const char * model_path) {
    if (model_path == nullptr || model_path[0] == '\0') {
        return -1;
    }

    std::lock_guard<std::mutex> lock(g_whisper_mutex);
    whisper_context * ctx = get_or_create_context(model_path);
    if (ctx == nullptr) {
        return -2;
    }

    return 0;
}
