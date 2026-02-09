#include "xil_printf.h"
#include "xparameters.h"
#include "xuartlite_l.h"
#include <stdint.h>
#include <string.h>

// ------------------------------------------------------------
// Shared constants
// ------------------------------------------------------------
#define IMG_BYTES 784

// ------------------------------------------------------------
// Forward decl from mlp.c
// ------------------------------------------------------------
int mlp_predict_u8(const uint8_t img[IMG_BYTES]);

// ------------------------------------------------------------
// UART chunk protocol (must match your Python sender)
// Packet: [START][TYPE][off_lo][off_hi][len][payload...][xor_chk]
// chk is XOR over TYPE, off_lo, off_hi, len, payload bytes
// ------------------------------------------------------------
#define START     0xAA
#define TYPE_DATA 0x01
#define ACK_OK    0x55
#define ACK_BAD   0xEE

// Base address selection
// If STDOUT_BASEADDRESS is not defined in your BSP, fall back to the default UARTLite instance.
#ifndef STDOUT_BASEADDRESS
#define STDOUT_BASEADDRESS XPAR_UARTLITE_0_BASEADDR
#endif

static inline uint8_t uart_recv_byte_blocking(void) {
    while (XUartLite_IsReceiveEmpty(STDOUT_BASEADDRESS)) { }
    return (uint8_t)XUartLite_RecvByte(STDOUT_BASEADDRESS);
}

static inline void uart_send_byte(uint8_t b) {
    while (XUartLite_IsTransmitFull(STDOUT_BASEADDRESS)) { }
    XUartLite_SendByte(STDOUT_BASEADDRESS, b);
}

// Receives one valid chunk and applies it to img[].
// Maintains got_map and got_count for reassembly.
// Returns 1 if chunk accepted (ACK_OK sent), 0 if rejected (ACK_BAD sent).
static int recv_and_apply_chunk(uint8_t img[IMG_BYTES], uint8_t got_map[IMG_BYTES], int *got_count) {
    // Find START byte (resync)
    uint8_t b;
    do {
        b = uart_recv_byte_blocking();
    } while (b != START);

    uint8_t type   = uart_recv_byte_blocking();
    uint8_t off_lo = uart_recv_byte_blocking();
    uint8_t off_hi = uart_recv_byte_blocking();
    uint8_t len    = uart_recv_byte_blocking();

    uint16_t offset = (uint16_t)off_lo | ((uint16_t)off_hi << 8);

    // Validate header
    if (type != TYPE_DATA) {
        uart_send_byte(ACK_BAD);
        return 0;
    }

    if (len == 0 || (offset + (uint16_t)len) > IMG_BYTES) {
        // Consume payload and checksum to keep stream aligned
        for (int i = 0; i < (int)len; i++) (void)uart_recv_byte_blocking();
        (void)uart_recv_byte_blocking(); // chk
        uart_send_byte(ACK_BAD);
        return 0;
    }

    // XOR checksum: XOR over [TYPE, off_lo, off_hi, len] + payload
    uint8_t chk_calc = 0;
    chk_calc ^= type;
    chk_calc ^= off_lo;
    chk_calc ^= off_hi;
    chk_calc ^= len;

    for (int i = 0; i < (int)len; i++) {
        uint8_t v = uart_recv_byte_blocking();
        chk_calc ^= v;

        uint16_t idx = offset + (uint16_t)i;

        if (got_map[idx] == 0) {
            got_map[idx] = 1;
            (*got_count)++;
        }
        img[idx] = v;
    }

    uint8_t chk_rx = uart_recv_byte_blocking();

    if (chk_rx != chk_calc) {
        uart_send_byte(ACK_BAD);
        return 0;
    }

    uart_send_byte(ACK_OK);
    return 1;
}

// Blocks until a full 784-byte image has been received via the chunk protocol.
static void recv_image_784(uint8_t img[IMG_BYTES]) {
    static uint8_t got_map[IMG_BYTES];

    memset(img, 0, IMG_BYTES);
    memset(got_map, 0, IMG_BYTES);
    int got_count = 0;

    while (got_count < IMG_BYTES) {
        (void)recv_and_apply_chunk(img, got_map, &got_count);
        // Sender retries on ACK_BAD, so we keep listening until complete.
    }
}

int main(void) {
    uint8_t img[IMG_BYTES];

    xil_printf("Ready. Send 784 bytes using chunk protocol. Use --gray.\r\n");

    while (1) {
        recv_image_784(img);

        int digit = mlp_predict_u8(img);

        xil_printf("Pred: %d\r\n", digit);

        // Send predicted digit back as one raw byte 0..9
        uart_send_byte((uint8_t)digit);
    }
}
