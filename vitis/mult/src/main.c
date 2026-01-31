#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"

#define BASE XPAR_SIMPLESUM_0_S00_AXI_BASEADDR

int main() {
    u32 b = 6;
    u32 c = 7;

    xil_printf("Start\r\n");
    for (u32 i = 0; i < 10; i++) {
        u32 bb = i + 3;
        u32 cc = i + 5;
        Xil_Out32(BASE + 0x08, bb);
        Xil_Out32(BASE + 0x0C, cc);
        Xil_Out32(BASE + 0x00, 1);
        while ((Xil_In32(BASE + 0x04) & 1) == 0) {}
        u32 oo = Xil_In32(BASE + 0x10);
        xil_printf("%d*%d=%d\r\n", bb, cc, oo);
    }
    // Write operands
    Xil_Out32(BASE + 0x08, b);
    Xil_Out32(BASE + 0x0C, c);

    // Start
    Xil_Out32(BASE + 0x00, 1);

    // Wait DONE
    while ((Xil_In32(BASE + 0x04) & 1) == 0) {}

    // Read result
    u32 out = Xil_In32(BASE + 0x10);

    xil_printf("B=%d C=%d OUT=%d\r\n", b, c, out);

    while (1) {}
}
