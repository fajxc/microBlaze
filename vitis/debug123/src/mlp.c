#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xuartlite_l.h"
#include "xparameters.h"
#include "xil_types.h"
#include <stdint.h>

#include "weights_w1.h"
#include "weights_b1.h"
#include "weights_w2.h"
#include "weights_b2.h"

// ============================================================
// AXI Register Map
// ============================================================
#define BASE  0x44A00000
#define REG0  (BASE + 0x00)  // start pulse
#define REG1  (BASE + 0x04)  // pixel data
#define REG2  (BASE + 0x08)  // pixel address
#define REG3  (BASE + 0x0C)  // status / done / predicted
#define REG4  (BASE + 0x10)  // dbg_score0      (reserved)
#define REG5  (BASE + 0x14)  // dbg_acc0        (reserved)
#define REG6  (BASE + 0x18)  // dbg_partial4_o0 (reserved)
#define REG7  (BASE + 0x1C)  // dbg_w2_00       (reserved)

#ifndef UART_BASE
#define UART_BASE XPAR_UARTLITE_0_BASEADDR
#endif

#define INPUT_SIZE  784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

// ============================================================
// Buffers
// ============================================================
static uint8_t  input_image[INPUT_SIZE];
static int32_t  hidden_layer[HIDDEN_SIZE];
static int32_t  output_layer[OUTPUT_SIZE];

// ============================================================
// UART / Hardware Helpers
// ============================================================
static inline u8 uart_getc_blocking(void) {
    while (XUartLite_IsReceiveEmpty(UART_BASE)) {}
    return Xil_In8(UART_BASE + XUL_RX_FIFO_OFFSET);
}

static inline void nn_write_pixel(u32 idx, u8 px) {
    Xil_Out32(REG2, idx);
    Xil_Out32(REG1, (u32)px);
}

static inline void nn_start_pulse(void) {
    Xil_Out32(REG0, 1u);
    usleep(10);
    Xil_Out32(REG0, 0u);
}

static inline u32 nn_wait_done(void) {
    while ( Xil_In32(REG3) & 0x1u)        {}  // wait for done to deassert
    while ((Xil_In32(REG3) & 0x1u) == 0u) {}  // wait for done to assert
    return Xil_In32(REG3);
}

// ============================================================
// Software MLP (reference)
// ============================================================
static inline int32_t relu(int32_t x) { return (x > 0) ? x : 0; }

static void layer1_forward(const uint8_t* input, int32_t* output) {
    for (int h = 0; h < HIDDEN_SIZE; h++) {
        int32_t accum = 0;
        for (int i = 0; i < INPUT_SIZE; i++)
            accum += (int32_t)w1[h][i] * (int32_t)input[i];
        output[h] = relu(accum + b1[h]);
    }
}

static void layer2_forward(const int32_t* hidden, int32_t* output) {
    for (int o = 0; o < OUTPUT_SIZE; o++) {
        int32_t accum = 0;
        for (int h = 0; h < HIDDEN_SIZE; h++)
            accum += (int32_t)w2[o][h] * (hidden[h] / 256);
        output[o] = accum + b2[o];
    }
}

static int argmax(const int32_t* array, int length) {
    int max_idx = 0;
    int32_t max_val = array[0];
    for (int i = 1; i < length; i++)
        if (array[i] > max_val) { max_val = array[i]; max_idx = i; }
    return max_idx;
}

static int mlp_inference(const uint8_t* img) {
    layer1_forward(img, hidden_layer);
    layer2_forward(hidden_layer, output_layer);
    return argmax(output_layer, OUTPUT_SIZE);
}

// ============================================================
// Main
// ============================================================
int main(void) {
    xil_printf("\r\n=== NN Core: HW vs SW Inference ===\r\n");
    Xil_Out32(REG0, 0u);
    usleep(1000);

    while (1) {
        xil_printf("\r\nCMD? (1=run inference, 4=menu)\r\n");
        u8 cmd = uart_getc_blocking();

        if (cmd == '4') {
            xil_printf("1: Run inference\r\n4: Menu\r\n");
            continue;
        }
        if (cmd != '1') {
            xil_printf("Unknown cmd '%c'\r\n", cmd);
            continue;
        }

        // Flush UART buffer before receiving image
        while (!XUartLite_IsReceiveEmpty(UART_BASE))
            (void)Xil_In8(UART_BASE + XUL_RX_FIFO_OFFSET);

        xil_printf("READY\r\n");

        // Receive 784 pixels and write to HW pixel buffer
        for (u32 idx = 0; idx < INPUT_SIZE; idx++) {
            u8 px = uart_getc_blocking();
            input_image[idx] = px;
            nn_write_pixel(idx, px);
        }

        // Run HW inference
        nn_start_pulse();
        u32 status  = nn_wait_done();
        u32 hw_pred = (status >> 4) & 0xFu;

        // Run SW inference
        int sw_pred = mlp_inference(input_image);

        xil_printf("HW PRED:%u SW PRED:%u\r\n", (unsigned)hw_pred, (unsigned)sw_pred);
        xil_printf("PRED:%u\r\n", (unsigned)sw_pred);
    }
}
