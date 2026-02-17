/**
 * @file mlp.c
 * @brief MLP Neural Network Inference on MicroBlaze RISC-V
 *
 * This program performs MNIST digit classification using a 2-layer MLP
 * with INT8 quantized weights on an FPGA with MicroBlaze RISC-V processor.
 * Communication via UART using AXI4-Lite interface.
 *
 * Network Architecture:
 * - Input: 784 (28x28 MNIST image)
 * - Hidden Layer: 32 neurons with ReLU
 * - Output: 10 classes (digits 0-9)
 *
 * UART: 9600 baud, 8N1
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartlite.h"
#include "xil_types.h"

// Include the quantized weight headers
#include "weights_w1.h"
#include "weights_b1.h"
#include "weights_w2.h"
#include "weights_b2.h"

// Network configuration
#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

// Quantization parameters (from export_weights_int8.py)
#define SHIFT_BITS 8  // Right shift after layer 1 for scaling

// UART configuration
#define UART_DEVICE_ID XPAR_UARTLITE_0_DEVICE_ID
#define UART_BAUDRATE 9600  // Changed to 9600 for better compatibility

// Global variables
XUartLite UartLite;
uint8_t input_image[INPUT_SIZE];
int32_t hidden_layer[HIDDEN_SIZE];
int32_t output_layer[OUTPUT_SIZE];

/**
 * @brief Initialize UART peripheral
 */
int uart_init(void) {
    int Status;

    Status = XUartLite_Initialize(&UartLite, UART_DEVICE_ID);
    if (Status != XST_SUCCESS) {
        xil_printf("ERROR: UART initialization failed!\r\n");
        return XST_FAILURE;
    }

    xil_printf("UART initialized successfully at 9600 baud\r\n");
    return XST_SUCCESS;
}

/**
 * @brief Send string via UART
 */
void uart_send_string(const char* str) {
    unsigned int len = strlen(str);
    unsigned int sent = 0;

    while (sent < len) {
        unsigned int count = XUartLite_Send(&UartLite, (u8*)(str + sent), len - sent);
        sent += count;
    }
}

/**
 * @brief Send a single character via UART
 */
void uart_send_char(char c) {
    XUartLite_Send(&UartLite, (u8*)&c, 1);
}

/**
 * @brief Receive bytes via UART with timeout
 * @return Number of bytes received
 */
int uart_receive_bytes(uint8_t* buffer, unsigned int num_bytes, unsigned int timeout_ms) {
    unsigned int received = 0;
    unsigned int timeout_counter = 0;
    const unsigned int delay_loops = 1000;

    while (received < num_bytes && timeout_counter < (timeout_ms * 10)) {
        unsigned int count = XUartLite_Recv(&UartLite, buffer + received, num_bytes - received);
        if (count > 0) {
            received += count;
            timeout_counter = 0;  // Reset timeout on successful receive
        } else {
            timeout_counter++;
            // Small delay (busy wait)
            for (volatile int i = 0; i < delay_loops; i++);
        }
    }

    return received;
}

/**
 * @brief Apply ReLU activation: max(0, x)
 */
static inline int32_t relu(int32_t x) {
    return (x > 0) ? x : 0;
}

/**
 * @brief Perform matrix-vector multiplication for layer 1
 *
 * Computes: hidden = ReLU(W1 * input + b1)
 * Input is uint8 (0-255), converted to centered int8 range
 */
void layer1_forward(const uint8_t* input, int32_t* output) {
    // Process each hidden neuron
    for (int h = 0; h < HIDDEN_SIZE; h++) {
        int32_t accum = 0;

        // Matrix multiply: sum over all input features
        for (int i = 0; i < INPUT_SIZE; i++) {
            // Direct multiplication - scaling happens in layer 2
            accum += (int32_t)w1[h][i] * (int32_t)input[i];
        }

        // Add bias (already scaled during quantization)
        accum += b1[h];

        // Apply ReLU activation
        output[h] = relu(accum);
    }
}
/**
 * @brief Perform matrix-vector multiplication for layer 2
 *
 * Computes: output = W2 * hidden + b2
 * Hidden layer values are downshifted before multiplication
 */
void layer2_forward(const int32_t* hidden, int32_t* output) {
    // Process each output neuron
    for (int o = 0; o < OUTPUT_SIZE; o++) {
        int32_t accum = 0;

        // Matrix multiply with downshifted hidden values
        for (int h = 0; h < HIDDEN_SIZE; h++) {
            // Downshift hidden layer to prevent overflow
            // Divide by 256 (SHIFT_BITS = 8 means divide by 2^8 = 256)
            int32_t hidden_scaled = hidden[h] / 256;
            accum += (int32_t)w2[o][h] * hidden_scaled;
        }

        // Add bias (already scaled during quantization)
        accum += b2[o];

        output[o] = accum;
    }
}

/**
 * @brief Find the index of maximum value (argmax)
 */
int argmax(const int32_t* array, int length) {
    int max_idx = 0;
    int32_t max_val = array[0];

    for (int i = 1; i < length; i++) {
        if (array[i] > max_val) {
            max_val = array[i];
            max_idx = i;
        }
    }

    return max_idx;
}

/**
 * @brief Perform complete MLP inference
 * @return Predicted digit (0-9)
 */
int mlp_inference(const uint8_t* input_image) {
    // Forward pass through layer 1
    layer1_forward(input_image, hidden_layer);

    // Forward pass through layer 2
    layer2_forward(hidden_layer, output_layer);

    // Get prediction
    int prediction = argmax(output_layer, OUTPUT_SIZE);

    return prediction;
}

/**
 * @brief Print the output logits for debugging
 */
void print_logits(void) {
    xil_printf("Logits: ");
    for (int i = 0; i < OUTPUT_SIZE; i++) {
        xil_printf("%d", output_layer[i]);
        if (i < OUTPUT_SIZE - 1) {
            xil_printf(",");
        }
    }
    xil_printf("\r\n");
}

/**
 * @brief Process received MNIST image and perform inference
 */
void process_inference(void) {
    char result_buffer[64];

    xil_printf("\r\n=== Inference Start ===\r\n");

    // Run inference
    int prediction = mlp_inference(input_image);

    // Print results locally
    xil_printf("Prediction: %d\r\n", prediction);
    print_logits();

    // Send result via UART in simple format
    sprintf(result_buffer, "PRED:%d\r\n", prediction);
    uart_send_string(result_buffer);

    xil_printf("=== Inference Complete ===\r\n");
}

/**
 * @brief Wait for and receive MNIST image via UART
 *
 * Protocol:
 * - Expects 784 bytes of grayscale pixel data (28x28 image)
 * - Values should be in range 0-255
 */
int receive_image(void) {
    char msg[128];

    xil_printf("Ready to receive image (784 bytes)...\r\n");

    // Send READY signal
    uart_send_string("READY\r\n");

    // Receive image data with 30 second timeout (slower at 9600 baud)
    int received = uart_receive_bytes(input_image, INPUT_SIZE, 30000);

    if (received == INPUT_SIZE) {
        xil_printf("Received complete image (%d bytes)\r\n", received);
        return XST_SUCCESS;
    } else {
        sprintf(msg, "ERROR: Received only %d of %d bytes\r\n", received, INPUT_SIZE);
        xil_printf("%s", msg);
        uart_send_string(msg);
        return XST_FAILURE;
    }
}

/**
 * @brief Run self-test with a simple test pattern
 */
void run_self_test(void) {
    xil_printf("\r\n=== Self-Test Start ===\r\n");

    // Create a simple test pattern (all zeros)
    memset(input_image, 0, INPUT_SIZE);

    // Add some non-zero values to test the network
    for (int i = 0; i < 100; i++) {
        input_image[i] = 128;  // Mid-range values
    }

    // Run inference
    int prediction = mlp_inference(input_image);

    xil_printf("Self-test prediction: %d\r\n", prediction);
    print_logits();

    // Send via UART
    char buffer[64];
    sprintf(buffer, "SELF-TEST:PRED=%d\r\n", prediction);
    uart_send_string(buffer);

    xil_printf("=== Self-Test Complete ===\r\n");
}

/**
 * @brief Display menu
 */
void display_menu(void) {
    xil_printf("\r\n");
    xil_printf("=========================================\r\n");
    xil_printf("  MNIST MLP Inference - MicroBlaze RISC-V\r\n");
    xil_printf("  INT8 Quantization | 9600 baud\r\n");
    xil_printf("=========================================\r\n");
    xil_printf("Commands:\r\n");
    xil_printf("  1 - Receive image and classify\r\n");
    xil_printf("  2 - Run self-test\r\n");
    xil_printf("  3 - Display network info\r\n");
    xil_printf("  4 - Display menu\r\n");
    xil_printf("=========================================\r\n");
    xil_printf("Command: ");

    // Also send via UART
    uart_send_string("\r\n=== MENU ===\r\n");
    uart_send_string("1: Classify image\r\n");
    uart_send_string("2: Self-test\r\n");
    uart_send_string("3: Network info\r\n");
    uart_send_string("4: Menu\r\n");
}

/**
 * @brief Display network information
 */
void display_network_info(void) {
    xil_printf("\r\n=== Network Info ===\r\n");
    xil_printf("Architecture: 784->32->10\r\n");
    xil_printf("Quantization: INT8\r\n");
    xil_printf("Shift bits: %d\r\n", SHIFT_BITS);
    xil_printf("Parameters: %d\r\n",
               (INPUT_SIZE * HIDDEN_SIZE + HIDDEN_SIZE +
                HIDDEN_SIZE * OUTPUT_SIZE + OUTPUT_SIZE));

    // Send via UART
    uart_send_string("INFO:784->32->10,INT8\r\n");
}

/**
 * @brief Main function
 */
int main(void) {
    int Status;
    uint8_t command;

    // Startup message
    xil_printf("\r\n\r\n");
    xil_printf("*********************************************\r\n");
    xil_printf("* MLP Inference System Starting...          *\r\n");
    xil_printf("*********************************************\r\n");

    // Initialize UART
    Status = uart_init();
    if (Status != XST_SUCCESS) {
        xil_printf("FATAL: UART init failed\r\n");
        return XST_FAILURE;
    }

    // Send startup message via UART
    uart_send_string("\r\n*** MLP System Ready ***\r\n");
    uart_send_string("Baud: 9600\r\n");

    // Display menu
    display_menu();

    // Main command loop
    while (1) {
        // Wait for command (single character)
        if (uart_receive_bytes(&command, 1, 60000) == 1) {

            // Echo command
            xil_printf("%c\r\n", command);

            switch (command) {
                case '1':
                    xil_printf("Command: Classify image\r\n");
                    Status = receive_image();
                    if (Status == XST_SUCCESS) {
                        process_inference();
                    }
                    break;

                case '2':
                    xil_printf("Command: Self-test\r\n");
                    run_self_test();
                    break;

                case '3':
                    xil_printf("Command: Network info\r\n");
                    display_network_info();
                    break;

                case '4':
                    xil_printf("Command: Show menu\r\n");
                    display_menu();
                    break;

                case '\r':
                case '\n':
                    // Ignore newlines
                    break;

                default:
                    xil_printf("Unknown: %c (0x%02X)\r\n", command, command);
                    uart_send_string("ERROR:Unknown command\r\n");
                    break;
            }

            xil_printf("\r\nCommand: ");
        }
    }

    return 0;
}
