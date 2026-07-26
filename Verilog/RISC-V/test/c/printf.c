#include "printf.h"

int main() {
    printf("Hello, RISC-V!\n");
    printf("%d + %d = %d\n", 40, 2, 42);
    printf("hex: %x\n", 0xDEAD);
    printf("negative: %d\n", -123);
    printf("char: %c\n", 'Z');
    printf("string: %s\n", "world");
    printf("long: %ld\n", 1000000000000L);
    printf("percent: 100%%\n");
    return 0;
}
