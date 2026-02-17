#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xuartlite_l.h"
#include "xparameters.h"
#include "xil_types.h"

#define BASE 0x44A00000

#define REG0 (BASE + 0x00)
#define REG1 (BASE + 0x04)
#define REG2 (BASE + 0x08)
#define REG3 (BASE + 0x0C)

#ifndef UART_BASE
#define UART_BASE XPAR_UARTLITE_0_BASEADDR
#endif

static inline u8 uart_getc_blocking(void)
{
    while (XUartLite_IsReceiveEmpty(UART_BASE)) {}
    return Xil_In8(UART_BASE + XUL_RX_FIFO_OFFSET);
}

static inline void nn_write_pixel(u32 idx, u8 px)
{
    Xil_Out32(REG2, idx);
    Xil_Out32(REG1, (u32)px);
}

static inline void nn_start_pulse(void)
{
    Xil_Out32(REG0, 1u);
    usleep(1);
    Xil_Out32(REG0, 0u);
}

static inline u32 nn_wait_done(void)
{
    // wait for previous done to clear (if still set)
    while (Xil_In32(REG3) & 0x1u) {}

    // now wait for the next done
    while ((Xil_In32(REG3) & 0x1u) == 0u) {}

    return Xil_In32(REG3);
}


int main(void)
{
    xil_printf("\r\n=== NN CORE PREDICTION TEST ===\r\n");

    Xil_Out32(REG0, 0u);
    usleep(1000);

    while (1)
    {
        xil_printf("\r\nCMD? (1=send image, 4=menu)\r\n");

        u8 cmd = uart_getc_blocking();

        if (cmd == '4') {
            xil_printf("Menu:\r\n");
            xil_printf("  1: Send image\r\n");
            xil_printf("  4: Show menu\r\n");
            continue;
        }

        if (cmd != '1') {
            xil_printf("Unknown cmd '%c'\r\n", cmd);
            continue;
        }

        // now do your existing READY + 784 bytes + infer
        while (!XUartLite_IsReceiveEmpty(UART_BASE)) {
            (void)Xil_In8(UART_BASE + XUL_RX_FIFO_OFFSET);
        }

        xil_printf("READY\r\n");

        for (u32 idx = 0; idx < 784u; idx++) {
            u8 px = uart_getc_blocking();
            nn_write_pixel(idx, px);
        }

        nn_start_pulse();


        u32 status = nn_wait_done();
        u32 pred   = (status >> 4) & 0xFu;

        xil_printf("PRED:%u\r\n", (unsigned int)pred);
    }

}
