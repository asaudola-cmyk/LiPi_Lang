// ==============================================================================
// 👑 LIPI UNIVERSE MEDIA: SOVEREIGN RIFF/WAVE PCM AUDIO ENGINE
// File: universe/media/audio_wav.lp
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% FFmpeg | 0% Libsndfile
// ==============================================================================
//
// WHY THIS EXISTS:
// In mainstream software, generating or playing audio requires linking heavy C
// libraries (FFmpeg, libsndfile, ALSA, PortAudio).
//
// LIPI'S SOVEREIGN ANSWER:
// Pure direct-to-silicon RIFF/WAVE PCM 16-bit audio synthesis and serialization.
// Generates standard uncompressed audio bitstreams playable across any operating
// system, hardware DAC, web browser, or phone without foreign dependencies.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"

// ── ১. অডিও স্ট্রাকচার ও মডেল (Audio Buffer Model) ──────────────────────────
struct WavAudioBuffer
    wb_sample_rate
    wb_channels
    wb_bits_per_sample
    wb_samples_count
    wb_samples_ptr

fn wav_buffer_new sample_rate channels max_samples
    wb = WavAudioBuffer()
    wb.wb_sample_rate = sample_rate
    wb.wb_channels = channels
    wb.wb_bits_per_sample = 16
    wb.wb_samples_count = 0
    // 2 bytes per 16-bit sample * channels
    byte_capacity = max_samples * channels * 2
    wb.wb_samples_ptr = malloc(byte_capacity + 64)
    return wb

fn wav_buffer_free wb
    if wb.wb_samples_ptr != 0
        total_bytes = wb.wb_samples_count * wb.wb_channels * 2
        free(wb.wb_samples_ptr, total_bytes + 64)
        wb.wb_samples_ptr = 0
    return 0

// ── ২. পিওর ইনটিজার সাইন ওয়েভ ফর্ম জেনারেটর (Fixed-Point Sine Synthesizer) ────
// WHY: Generates smooth sinusoidal 16-bit PCM waves using a fast 12-point quadrant
// approximation without floating-point FPU traps or external math libraries.
fn math_sin_approx_16bit phase_deg
    // Normalise phase to 0..359 degrees
    deg = phase_deg % 360
    if deg < 0 deg = deg + 360

    sign = 1
    if deg >= 180
        sign = -1
        deg = deg - 180

    // Quadrant symmetry: 0..90
    if deg > 90
        deg = 180 - deg

    // Parabolic Sine Approximation: y = 4*x*(180 - x) / (40500 - x*(180 - x))
    // Scaled for 16-bit signed PCM amplitude (-32767 to 32767)
    // Fast integer approximation: sin(deg) ~= deg * (180 - deg) * 4 / 180
    // For deg in 0..90:
    val = (deg * (180 - deg) * 32767) / 8100
    if val > 32767 val = 32767
    return val * sign

// ── ৩. পিওর টোন জেনারেট ও বাফারে পুশ (Generate Pure Frequency Tone) ───────────
// WHY: Synthesizes a clean acoustic frequency (e.g. 440 Hz concert pitch A)
fn wav_add_tone wb freq_hz duration_ms amplitude
    sr = wb.wb_sample_rate
    total_samples = (sr * duration_ms) / 1000
    ptr = wb.wb_samples_ptr
    base_idx = wb.wb_samples_count

    i = 0
    while i < total_samples
        // Phase in degrees: (i * freq_hz * 360) / sr
        phase = (i * freq_hz * 360) / sr
        raw_sin = math_sin_approx_16bit(phase)
        sample_16 = (raw_sin * amplitude) / 100

        // Clamp to 16-bit signed integer limits (-32768 to 32767)
        if sample_16 > 32767 sample_16 = 32767
        if sample_16 < -32768 sample_16 = -32768

        // Convert signed 16-bit to little-endian unsigned word
        u_sample = sample_16
        if u_sample < 0 u_sample = u_sample + 65536

        byte_offset = (base_idx + i) * 2
        mem_byte_write(ptr, byte_offset, u_sample & 255)
        mem_byte_write(ptr, byte_offset + 1, (u_sample >> 8) & 255)
        i = i + 1

    wb.wb_samples_count = base_idx + total_samples
    return total_samples

// ── ৪. RIFF/WAV ফাইল সিরিয়ালাইজেশন (Direct Disk Audio File Serialization) ──────
// WHY: Directly writes the 44-byte canonical WAV header followed by PCM payload
// via direct Linux kernel system calls (SYS_open, SYS_write, SYS_fsync, SYS_close).
fn wav_write_file wb file_path
    data_size = wb.wb_samples_count * wb.wb_channels * 2
    riff_size = data_size + 36

    // Open file for write: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, mode 0644 = 420
    fd = syscall(2, file_path, 577, 420, 0, 0, 0)
    if fd < 0
        return -1

    hdr = malloc(48)

    // 1. 'RIFF' Chunk Descriptor
    mem_byte_write(hdr, 0, 82)  // 'R'
    mem_byte_write(hdr, 1, 73)  // 'I'
    mem_byte_write(hdr, 2, 70)  // 'F'
    mem_byte_write(hdr, 3, 70)  // 'F'
    // ChunkSize = 36 + data_size (32-bit LE)
    mem_byte_write(hdr, 4, riff_size & 255)
    mem_byte_write(hdr, 5, (riff_size >> 8) & 255)
    mem_byte_write(hdr, 6, (riff_size >> 16) & 255)
    mem_byte_write(hdr, 7, (riff_size >> 24) & 255)

    // 2. 'WAVE' Format
    mem_byte_write(hdr, 8, 87)   // 'W'
    mem_byte_write(hdr, 9, 65)   // 'A'
    mem_byte_write(hdr, 10, 86)  // 'V'
    mem_byte_write(hdr, 11, 69)  // 'E'

    // 3. 'fmt ' Subchunk
    mem_byte_write(hdr, 12, 102) // 'f'
    mem_byte_write(hdr, 13, 109) // 'm'
    mem_byte_write(hdr, 14, 116) // 't'
    mem_byte_write(hdr, 15, 32)  // ' '
    // Subchunk1Size = 16 (for PCM)
    mem_byte_write(hdr, 16, 16)
    mem_byte_write(hdr, 17, 0)
    mem_byte_write(hdr, 18, 0)
    mem_byte_write(hdr, 19, 0)
    // AudioFormat = 1 (Linear PCM)
    mem_byte_write(hdr, 20, 1)
    mem_byte_write(hdr, 21, 0)
    // NumChannels
    mem_byte_write(hdr, 22, wb.wb_channels & 255)
    mem_byte_write(hdr, 23, 0)
    // SampleRate (32-bit LE)
    sr = wb.wb_sample_rate
    mem_byte_write(hdr, 24, sr & 255)
    mem_byte_write(hdr, 25, (sr >> 8) & 255)
    mem_byte_write(hdr, 26, (sr >> 16) & 255)
    mem_byte_write(hdr, 27, (sr >> 24) & 255)
    // ByteRate = SampleRate * NumChannels * BitsPerSample/8
    byte_rate = sr * wb.wb_channels * 2
    mem_byte_write(hdr, 28, byte_rate & 255)
    mem_byte_write(hdr, 29, (byte_rate >> 8) & 255)
    mem_byte_write(hdr, 30, (byte_rate >> 16) & 255)
    mem_byte_write(hdr, 31, (byte_rate >> 24) & 255)
    // BlockAlign = NumChannels * BitsPerSample/8
    block_align = wb.wb_channels * 2
    mem_byte_write(hdr, 32, block_align & 255)
    mem_byte_write(hdr, 33, 0)
    // BitsPerSample = 16
    mem_byte_write(hdr, 34, 16)
    mem_byte_write(hdr, 35, 0)

    // 4. 'data' Subchunk
    mem_byte_write(hdr, 36, 100) // 'd'
    mem_byte_write(hdr, 37, 97)  // 'a'
    mem_byte_write(hdr, 38, 116) // 't'
    mem_byte_write(hdr, 39, 97)  // 'a'
    // Subchunk2Size = data_size
    mem_byte_write(hdr, 40, data_size & 255)
    mem_byte_write(hdr, 41, (data_size >> 8) & 255)
    mem_byte_write(hdr, 42, (data_size >> 16) & 255)
    mem_byte_write(hdr, 43, (data_size >> 24) & 255)

    // Write 44 bytes header to disk
    syscall(1, fd, hdr, 44, 0, 0, 0)

    // Write PCM raw samples
    if data_size > 0
        syscall(1, fd, wb.wb_samples_ptr, data_size, 0, 0, 0)

    syscall(74, fd, 0, 0, 0, 0, 0) // SYS_fsync
    syscall(3, fd, 0, 0, 0, 0, 0)  // SYS_close
    free(hdr, 48)

    return 44 + data_size

// ── ৫. দ্বিভাষিক বাংলা ফাংশনসমূহ (Bilingual Bengali API) ──────────────────────
fn অডিও_বাফার_তৈরি নমুনা_রেট চ্যানেল সর্বোচ্চ_নমুনা
    return wav_buffer_new(নমুনা_রেট, চ্যানেল, সর্বোচ্চ_নমুনা)

fn অডিও_টোন_যুক্ত_করো বাফার ফ্রিকোয়েন্সি স্থায়িত্ব_মিলি অ্যাম্প্লিটিউড
    return wav_add_tone(বাফার, ফ্রিকোয়েন্সি, স্থায়িত্ব_মিলি, অ্যাম্প্লিটিউড)

fn অডিও_ওয়েভ_সংরক্ষণ বাফার ফাইল_পাথ
    return wav_write_file(বাফার, ফাইল_পাথ)
