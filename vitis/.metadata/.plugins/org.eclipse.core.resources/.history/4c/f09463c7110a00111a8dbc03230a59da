#include "xil_io.h"
#include "xil_printf.h"
#include "sleep.h"

#define BASE 0x44A00000
#define REG0 (BASE + 0x00)
#define REG3 (BASE + 0x0C)

int main()
{
    xil_printf("\r\n=== MULTI MEM LOAD TEST ===\r\n");

    // make sure start is low initially
    Xil_Out32(REG0, 0);
    usleep(1000);

    for (int i = 0; i < 4; i++)
    {
        // pulse start
        Xil_Out32(REG0, 1);
        usleep(1);
        Xil_Out32(REG0, 0);

        // wait for done (bit 0 of REG3)
        u32 r;
        do {
            r = Xil_In32(REG3);
        } while ((r & 0x1) == 0);

        u32 pred = (r >> 4) & 0xF;

        xil_printf("Test %d -> REG3=0x%08x pred=%u\r\n",
                   i,
                   (unsigned int)r,
                   (unsigned int)pred);

        usleep(1000);
    }

    xil_printf("Done.\r\n");

    while(1) {}
}
