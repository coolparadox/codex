#include <cstdio>

int main() {
    FILE* out;
    out = fdopen(3, "w");
    if (!out) return 1;
    fprintf(out, "yo!\n");
    return 0;
}
