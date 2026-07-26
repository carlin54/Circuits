int main() {
    int a = 0, b = 1;
    for (int i = 0; i < 10; i++) {
        int t = a + b;
        a = b;
        b = t;
    }
    if (a == 55) return 0;
    return 1;
}
