#include <cassert>
#include <cstdio>
#include "ring_buffer.h"

static int tests_run = 0, tests_passed = 0;
#define CHECK(cond) do { tests_run++; if (cond) { tests_passed++; } \
    else { fprintf(stderr, "FAIL: %s\n", #cond); } } while(0)

void test_write_read() {
    RingBuffer rb(1024);
    float src[100], dst[100];
    for (int i = 0; i < 100; i++) src[i] = (float)i;

    bool ok = rb.write(src, 100);
    CHECK(ok);
    size_t got = rb.read(dst, 100);
    CHECK(got == 100);
    for (int i = 0; i < 100; i++)
        CHECK(dst[i] == (float)i);
}

void test_overflow_returns_false() {
    RingBuffer rb(100);
    float src[200];
    bool ok = rb.write(src, 200);
    CHECK(!ok);
}

void test_empty_read_returns_zero() {
    RingBuffer rb(1024);
    float dst[10];
    size_t got = rb.read(dst, 10);
    CHECK(got == 0);
}

void test_wrap_around() {
    RingBuffer rb(900);
    float src[500], dst[500];
    for (int i = 0; i < 500; i++) src[i] = (float)(i + 1);

    rb.write(src, 500);
    rb.read(dst, 300);   // read 300, leaving 200
    rb.write(src, 500);  // write 500 more, will wrap

    float buf[700];
    size_t got = rb.read(buf, 700);
    CHECK(got == 700);
    // First 200: original tail, then 500 new
    for (int i = 0; i < 200; i++)
        CHECK(buf[i] == (float)(i + 301));
    for (int i = 0; i < 500; i++)
        CHECK(buf[200 + i] == (float)(i + 1));
}

void test_available() {
    RingBuffer rb(1024);
    CHECK(rb.available() == 0);
    float src[50];
    rb.write(src, 50);
    CHECK(rb.available() == 50);
    float dst[30];
    rb.read(dst, 30);
    CHECK(rb.available() == 20);
}

int main() {
    test_write_read();
    test_overflow_returns_false();
    test_empty_read_returns_zero();
    test_wrap_around();
    test_available();
    printf("%d/%d passed\n", tests_passed, tests_run);
    return tests_run == tests_passed ? 0 : 1;
}
