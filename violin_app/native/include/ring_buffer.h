#pragma once
#include <atomic>
#include <vector>
#include <cstring>
#include <algorithm>

class RingBuffer {
public:
    explicit RingBuffer(size_t capacity)
        : buf_(capacity), capacity_(capacity),
          write_pos_(0), read_pos_(0) {}

    bool write(const float* src, size_t frames) noexcept {
        size_t w = write_pos_.load(std::memory_order_relaxed);
        size_t r = read_pos_.load(std::memory_order_acquire);
        size_t available = capacity_ - (w - r);
        if (available < frames) return false;

        size_t idx = w % capacity_;
        size_t first = std::min(frames, capacity_ - idx);
        std::memcpy(buf_.data() + idx, src, first * sizeof(float));
        if (frames > first)
            std::memcpy(buf_.data(), src + first,
                        (frames - first) * sizeof(float));

        write_pos_.fetch_add(frames, std::memory_order_release);
        return true;
    }

    size_t read(float* dst, size_t max_frames) noexcept {
        size_t r = read_pos_.load(std::memory_order_relaxed);
        size_t w = write_pos_.load(std::memory_order_acquire);
        size_t available = w - r;
        size_t to_read = std::min(available, max_frames);
        if (to_read == 0) return 0;

        size_t idx = r % capacity_;
        size_t first = std::min(to_read, capacity_ - idx);
        std::memcpy(dst, buf_.data() + idx, first * sizeof(float));
        if (to_read > first)
            std::memcpy(dst + first, buf_.data(),
                        (to_read - first) * sizeof(float));

        read_pos_.fetch_add(to_read, std::memory_order_release);
        return to_read;
    }

    size_t available() const noexcept {
        return write_pos_.load(std::memory_order_acquire)
             - read_pos_.load(std::memory_order_acquire);
    }

private:
    std::vector<float> buf_;
    const size_t capacity_;
    std::atomic<size_t> write_pos_;
    std::atomic<size_t> read_pos_;
};
