#include "xil_printf.h"
#include "sleep.h"

int main()
{
    xil_printf("UART works. If you see this, you're alive.\r\n");

    int i = 0;
    while (1) {
        xil_printf("tick %d\r\n", i++);
        sleep(1);
    }

    return 0;
}
