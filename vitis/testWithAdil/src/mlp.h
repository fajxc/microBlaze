/**
 * @file mlp.h
 * @brief Header file for MLP Neural Network Inference
 *
 * MicroBlaze RISC-V implementation with 9600 baud UART
 */

#ifndef MLP_H
#define MLP_H

#include <stdint.h>

// Network configuration
#define INPUT_SIZE 784
#define HIDDEN_SIZE 32
#define OUTPUT_SIZE 10

// Quantization parameters
#define SHIFT_BITS 8

// UART configuration
#define UART_BAUDRATE 9600

// Function prototypes

/**
 * @brief Initialize UART peripheral
 * @return XST_SUCCESS if successful, XST_FAILURE otherwise
 */
int uart_init(void);

/**
 * @brief Send string via UART
 * @param str Null-terminated string to send
 */
void uart_send_string(const char* str);

/**
 * @brief Send a single character via UART
 * @param c Character to send
 */
void uart_send_char(char c);

/**
 * @brief Receive bytes via UART with timeout
 * @param buffer Buffer to store received bytes
 * @param num_bytes Number of bytes to receive
 * @param timeout_ms Timeout in milliseconds
 * @return Number of bytes received
 */
int uart_receive_bytes(uint8_t* buffer, unsigned int num_bytes, unsigned int timeout_ms);

/**
 * @brief Apply ReLU activation function
 * @param x Input value
 * @return max(0, x)
 */
static inline int32_t relu(int32_t x);

/**
 * @brief Forward pass through layer 1
 * @param input Input image (784 uint8 values)
 * @param output Hidden layer activations (32 int32 values)
 */
void layer1_forward(const uint8_t* input, int32_t* output);

/**
 * @brief Forward pass through layer 2
 * @param hidden Hidden layer activations
 * @param output Output logits (10 int32 values)
 */
void layer2_forward(const int32_t* hidden, int32_t* output);

/**
 * @brief Find index of maximum value in array
 * @param array Input array
 * @param length Length of array
 * @return Index of maximum value
 */
int argmax(const int32_t* array, int length);

/**
 * @brief Perform complete MLP inference
 * @param input_image Input image (784 bytes)
 * @return Predicted digit (0-9)
 */
int mlp_inference(const uint8_t* input_image);

/**
 * @brief Print output logits for debugging
 */
void print_logits(void);

/**
 * @brief Process received image and perform inference
 */
void process_inference(void);

/**
 * @brief Wait for and receive MNIST image via UART
 * @return XST_SUCCESS if successful, XST_FAILURE otherwise
 */
int receive_image(void);

/**
 * @brief Run self-test with test pattern
 */
void run_self_test(void);

/**
 * @brief Display menu to user
 */
void display_menu(void);

/**
 * @brief Display network information
 */
void display_network_info(void);

#endif // MLP_H
