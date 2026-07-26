#include <stdarg.h>
#include "printf.h"

#define UART_TX (*(volatile char *)0x10000000)

void putchar(char c) {
    UART_TX = c;
}

void puts(const char *s) {
    while (*s)
        putchar(*s++);
    putchar('\n');
}

static void print_uint(unsigned long val, int base) {
    char buf[20];
    int i = 0;
    if (val == 0) {
        putchar('0');
        return;
    }
    while (val) {
        int d = val % base;
        buf[i++] = d < 10 ? '0' + d : 'a' + d - 10;
        val /= base;
    }
    while (i > 0)
        putchar(buf[--i]);
}

static void print_int(long val) {
    if (val < 0) {
        putchar('-');
        print_uint(-val, 10);
    } else {
        print_uint(val, 10);
    }
}

int printf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int count = 0;

    while (*fmt) {
        if (*fmt != '%') {
            putchar(*fmt++);
            count++;
            continue;
        }
        fmt++;

        int is_long = 0;
        if (*fmt == 'l') {
            is_long = 1;
            fmt++;
        }

        switch (*fmt) {
        case 'd':
        case 'i':
            if (is_long)
                print_int(va_arg(ap, long));
            else
                print_int(va_arg(ap, int));
            break;
        case 'u':
            if (is_long)
                print_uint(va_arg(ap, unsigned long), 10);
            else
                print_uint(va_arg(ap, unsigned int), 10);
            break;
        case 'x':
            if (is_long)
                print_uint(va_arg(ap, unsigned long), 16);
            else
                print_uint(va_arg(ap, unsigned int), 16);
            break;
        case 's': {
            const char *s = va_arg(ap, const char *);
            while (*s) {
                putchar(*s++);
                count++;
            }
            break;
        }
        case 'c':
            putchar((char)va_arg(ap, int));
            count++;
            break;
        case '%':
            putchar('%');
            count++;
            break;
        default:
            putchar('%');
            putchar(*fmt);
            count += 2;
            break;
        }
        fmt++;
    }

    va_end(ap);
    return count;
}
