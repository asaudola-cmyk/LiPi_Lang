// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Sovereign RIFF/WAV Audio Synthesizer
// File: tests/test_audio_wav.lp
// Milestone: First 1.0.0 (প্রথম ১.০.০) | Zero Libc | Zero External Codecs
// ==============================================================================

include "universe/media/audio_wav.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ FAILED: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🎵 LIPI SOVEREIGN AUDIO SYNTHESIS & RIFF/WAV CODEC TEST"
    say "════════════════════════════════════════════════════════════════════════"

    test_wav = "/tmp/test_acoustic_tone.wav"
    syscall(87, test_wav, 0, 0, 0, 0, 0) // Clean prior

    say "\n[Phase 1]: Initializing 44.1 kHz Mono Audio Buffer..."
    // 44100 Hz, 1 channel (mono), capacity for 44100 samples (1 second)
    wb = wav_buffer_new(44100, 1, 44100)
    assert_true(wb.wb_sample_rate == 44100, "Sample rate is 44100 Hz")
    assert_true(wb.wb_channels == 1, "Channel count is 1 (Mono)")
    assert_true(wb.wb_bits_per_sample == 16, "Resolution is 16-bit PCM")

    say "\n[Phase 2]: Synthesizing 440 Hz Concert Pitch A (500 ms)..."
    samples_added = wav_add_tone(wb, 440, 500, 80) // 440 Hz, 500ms, 80% volume
    assert_true(samples_added == 22050, "Synthesized exactly 22050 PCM audio samples")
    assert_true(wb.wb_samples_count == 22050, "Buffer contains 22050 samples")

    say "\n[Phase 3]: Serializing to Canonical RIFF/WAVE File on Disk..."
    bytes_written = wav_write_file(wb, test_wav)
    expected_size = 44 + (22050 * 2) // 44144 bytes
    assert_true(bytes_written == expected_size, "Output file size matches calculation (" + str(expected_size) + " bytes)")

    say "\n[Phase 4]: Validating RIFF Header Silicon Bytes from Disk..."
    fd = syscall(2, test_wav, 0, 0, 0, 0, 0) // O_RDONLY = 0
    assert_true(fd >= 0, "Test WAV file opened successfully")

    hdr_buf = malloc(48)
    n = syscall(0, fd, hdr_buf, 44, 0, 0, 0)
    assert_true(n == 44, "Read 44 header bytes from disk")

    // 'R' 'I' 'F' 'F' = 82, 73, 70, 70
    assert_true(mem_byte_read(hdr_buf, 0) == 82, "Magic byte 0 is 'R'")
    assert_true(mem_byte_read(hdr_buf, 1) == 73, "Magic byte 1 is 'I'")
    assert_true(mem_byte_read(hdr_buf, 2) == 70, "Magic byte 2 is 'F'")
    assert_true(mem_byte_read(hdr_buf, 3) == 70, "Magic byte 3 is 'F'")

    // 'W' 'A' 'V' 'E' = 87, 65, 86, 69
    assert_true(mem_byte_read(hdr_buf, 8) == 87, "Format byte 8 is 'W'")
    assert_true(mem_byte_read(hdr_buf, 9) == 65, "Format byte 9 is 'A'")
    assert_true(mem_byte_read(hdr_buf, 10) == 86, "Format byte 10 is 'V'")
    assert_true(mem_byte_read(hdr_buf, 11) == 69, "Format byte 11 is 'E'")

    // Free resources
    free(hdr_buf, 48)
    syscall(3, fd, 0, 0, 0, 0, 0)
    wav_buffer_free(wb)
    syscall(87, test_wav, 0, 0, 0, 0, 0)

    say "\n════════════════════════════════════════════════════════════════════════"
    say "🎉 SOVEREIGN AUDIO SYNTHESIZER & WAV CODEC TEST PASSED (100% PURE)"
    say "════════════════════════════════════════════════════════════════════════\n"
    return 0

main()
