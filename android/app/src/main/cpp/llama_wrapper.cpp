/**
 * llama_wrapper.cpp
 * Wrapper C semplificato per llama.cpp, espone una funzione di chat per FFI.
 * Gestisce tokenizzazione, inferenza e detokenizzazione in un'unica chiamata.
 */

#include "llama.h"
#include <cstring>
#include <string>
#include <vector>
#include <android/log.h>

#define LOG_TAG "LlamaWrapper"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

extern "C" {

/**
 * Funzione wrapper semplificata per generazione testo con llama.cpp.
 * Carica il modello, tokenizza il prompt, esegue l'inferenza e restituisce
 * il testo generato come stringa C.
 *
 * @param model     Puntatore al modello llama gia' caricato
 * @param prompt    Prompt di input come stringa C (UTF-8)
 * @param output    Buffer di output per il testo generato
 * @param max_len   Dimensione massima del buffer di output
 * @return          0 in caso di successo, codice errore altrimenti
 */
int llama_simple_chat(
    llama_model * model,
    const char * prompt,
    char * output,
    int max_len
) {
    if (!model || !prompt || !output || max_len <= 0) {
        LOGE("Parametri invalidi passati a llama_simple_chat");
        return -1;
    }

    LOGI("llama_simple_chat: inizio generazione, prompt len=%zu", strlen(prompt));

    // Crea il contesto di inferenza
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 4096;      // Context window Phi-3 4k
    ctx_params.n_batch = 512;      // Batch size
    ctx_params.n_threads = 4;      // Thread per inferenza CPU

    llama_context * ctx = llama_new_context_with_model(model, ctx_params);
    if (!ctx) {
        LOGE("Impossibile creare contesto llama");
        return -2;
    }

    // Tokenizza il prompt
    const int n_prompt_tokens_max = strlen(prompt) + 256;
    std::vector<llama_token> tokens(n_prompt_tokens_max);
    int n_tokens = llama_tokenize(
        model,
        prompt,
        strlen(prompt),
        tokens.data(),
        n_prompt_tokens_max,
        true,   // add_special (BOS)
        false   // parse_special
    );

    if (n_tokens < 0) {
        LOGE("Errore tokenizzazione: %d", n_tokens);
        llama_free(ctx);
        return -3;
    }

    tokens.resize(n_tokens);
    LOGI("Tokenizzazione completata: %d token", n_tokens);

    // Prepara il batch per l'inferenza
    llama_batch batch = llama_batch_init(n_tokens, 0, 1);

    for (int i = 0; i < n_tokens; i++) {
        llama_batch_add(batch, tokens[i], i, {0}, false);
    }
    batch.logits[batch.n_tokens - 1] = true;

    // Valuta il prompt
    if (llama_decode(ctx, batch) != 0) {
        LOGE("Errore decode prompt");
        llama_batch_free(batch);
        llama_free(ctx);
        return -4;
    }

    // Generazione token per token
    std::string result;
    const int max_gen_tokens = 512;
    int n_cur = batch.n_tokens;

    // Sampler per la generazione
    llama_sampler * sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.1f));
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(0.95f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(42));

    for (int i = 0; i < max_gen_tokens; i++) {
        // Campiona il prossimo token
        llama_token new_token = llama_sampler_sample(sampler, ctx, -1);

        // Controlla fine generazione (EOS)
        if (llama_token_is_eog(model, new_token)) {
            LOGI("EOS raggiunto dopo %d token generati", i);
            break;
        }

        // Converti token in testo
        char buf[256];
        int n = llama_token_to_piece(model, new_token, buf, sizeof(buf), 0, true);
        if (n > 0) {
            result.append(buf, n);
        }

        // Prepara il batch per il prossimo token
        llama_batch_clear(batch);
        llama_batch_add(batch, new_token, n_cur, {0}, true);
        n_cur++;

        // Decodifica
        if (llama_decode(ctx, batch) != 0) {
            LOGE("Errore decode token %d", i);
            break;
        }
    }

    LOGI("Generazione completata: %zu caratteri", result.size());

    // Copia il risultato nel buffer di output
    int copy_len = std::min((int)result.size(), max_len - 1);
    std::memcpy(output, result.c_str(), copy_len);
    output[copy_len] = '\0';

    // Cleanup
    llama_sampler_free(sampler);
    llama_batch_free(batch);
    llama_free(ctx);

    return 0;
}

} // extern "C"
