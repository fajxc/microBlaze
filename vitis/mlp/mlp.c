#include <stdint.h>

// Keep weights as separate headers (unchanged)
#include "weights_w1.h"  // expects: int8_t  w1[32][784]
#include "weights_b1.h"  // expects: int32_t b1[32]
#include "weights_w2.h"  // expects: int8_t  w2[10][32]
#include "weights_b2.h"  // expects: int32_t b2[10]

#define IMG_BYTES 784
#define HIDDEN    32
#define OUT       10

// Must match SHIFT used in export_weights_int8.py
#define SHIFT 8

static inline int32_t relu_i32(int32_t x) { return (x > 0) ? x : 0; }

// Predict digit 0..9 from a 28x28 image flattened row-major (784 bytes, 0..255).
int mlp_predict_u8(const uint8_t img[IMG_BYTES]) {
    int32_t h[HIDDEN];

    // Layer 1: h = ReLU(W1*x + b1)
    for (int j = 0; j < HIDDEN; j++) {
        int32_t acc = b1[j];
        for (int i = 0; i < IMG_BYTES; i++) {
            // Center input roughly around 0. Works well with int8 weights.
            int32_t x = (int32_t)img[i] - 128;
            acc += (int32_t)w1[j][i] * x;
        }
        h[j] = relu_i32(acc);
    }

    // Layer 2: y = W2*(h >> SHIFT) + b2
    int32_t best_val = 0;
    int best_idx = 0;

    for (int k = 0; k < OUT; k++) {
        int32_t acc = b2[k];
        for (int j = 0; j < HIDDEN; j++) {
            int32_t hj = (h[j] >> SHIFT);
            acc += (int32_t)w2[k][j] * hj;
        }
        if (k == 0 || acc > best_val) {
            best_val = acc;
            best_idx = k;
        }
    }

    return best_idx;
}
