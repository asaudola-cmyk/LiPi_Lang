import "universe/b_core/io"
import "universe/b_core/string"
import "universe/b_core/fs"
import "universe/b_core/math_audio"

@fn write_u32_le(fd, val)
  buf = sys_mmap(0, 4, 3, 34, 0 - 1, 0)
  sys_poke8(buf + 0, val & 255)
  sys_poke8(buf + 1, (val >> 8) & 255)
  sys_poke8(buf + 2, (val >> 16) & 255)
  sys_poke8(buf + 3, (val >> 24) & 255)
  fs_write(fd, buf, 4)
  return 0
@end

@fn write_u16_le(fd, val)
  buf = sys_mmap(0, 2, 3, 34, 0 - 1, 0)
  sys_poke8(buf + 0, val & 255)
  sys_poke8(buf + 1, (val >> 8) & 255)
  fs_write(fd, buf, 2)
  return 0
@end

@fn main()
  string_println("=== Native Maya Audio Synthesizer ===")
  
  sample_rate = 44100
  duration = 3 @! 3 seconds
  num_samples = sample_rate * duration
  
  fd = fs_open_write("chord.wav")
  
  @! RIFF Header
  fs_write(fd, "RIFF", 4)
  chunk_size = 36 + (num_samples * 2)
  write_u32_le(fd, chunk_size)
  fs_write(fd, "WAVE", 4)
  
  @! fmt chunk
  fs_write(fd, "fmt ", 4)
  write_u32_le(fd, 16)       @! Subchunk1Size
  write_u16_le(fd, 1)        @! AudioFormat (PCM)
  write_u16_le(fd, 1)        @! NumChannels (Mono)
  write_u32_le(fd, 44100)    @! SampleRate
  write_u32_le(fd, 88200)    @! ByteRate (44100 * 2)
  write_u16_le(fd, 2)        @! BlockAlign
  write_u16_le(fd, 16)       @! BitsPerSample
  
  @! data chunk
  fs_write(fd, "data", 4)
  data_size = num_samples * 2
  write_u32_le(fd, data_size)
  
  @! Frequencies for C Major Chord (C4, E4, G4)
  @! C4 = 261.63, E4 = 329.63, G4 = 392.00
  freq1 = float(261, 63, 100)
  freq2 = float(329, 63, 100)
  freq3 = float(392, 0, 1)
  
  pi2 = float(6, 28318, 100000)
  f_sr = int_to_float(sample_rate)
  
  buf = sys_mmap(0, 2, 3, 34, 0 - 1, 0)
  
  i = 0
  @while i < num_samples
    t = fdiv(int_to_float(i), f_sr) @! t = i / sample_rate
    
    @! phase = t * freq * 2PI
    p1 = fmul(fmul(t, freq1), pi2)
    p2 = fmul(fmul(t, freq2), pi2)
    p3 = fmul(fmul(t, freq3), pi2)
    
    s1 = fsin(p1)
    s2 = fsin(p2)
    s3 = fsin(p3)
    
    @! Mix them: (s1 + s2 + s3) / 3
    mixed = fdiv(fadd(fadd(s1, s2), s3), float(3, 0, 1))
    
    @! Volume envelope: simple fade out
    @! vol = 1.0 - (t / duration)
    vol = fsub(float(1, 0, 1), fdiv(t, int_to_float(duration)))
    mixed = fmul(mixed, vol)
    
    @! Scale to 16-bit integer (-32767 to 32767)
    sample_val = float_to_int(fmul(mixed, int_to_float(32767)))
    
    @! Write 16-bit little endian
    sys_poke8(buf + 0, sample_val & 255)
    sys_poke8(buf + 1, (sample_val >> 8) & 255)
    fs_write(fd, buf, 2)
    
    i = i + 1
  @end
  
  fs_close(fd)
  string_println("Synthesized chord.wav!")
  sys_exit(0)
@end

@fn sys_exit(code)
  sys_syscall(60, code, 0, 0, 0, 0, 0)
@end
