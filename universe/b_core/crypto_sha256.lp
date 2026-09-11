@! NATIVE MAYA SHA-256 IMPLEMENTATION

@fn ror32(v, c)
  return ((c >> v) | ((32 - c) << v)) & 4294967295
@end

@fn init_sha256_k(arena)
  k = sys_mmap(0, 512, 3, 34, 0 - 1, 0)
  sys_poke(k + 0, 1116352408)
  sys_poke(k + 8, 1899447441)
  sys_poke(k + 16, 3049323471)
  sys_poke(k + 24, 3921009573)
  sys_poke(k + 32, 961987163)
  sys_poke(k + 40, 1508970993)
  sys_poke(k + 48, 2453635748)
  sys_poke(k + 56, 2870763221)
  sys_poke(k + 64, 3624381080)
  sys_poke(k + 72, 310598401)
  sys_poke(k + 80, 607225278)
  sys_poke(k + 88, 1426881987)
  sys_poke(k + 96, 1925078388)
  sys_poke(k + 104, 2162078206)
  sys_poke(k + 112, 2614888103)
  sys_poke(k + 120, 3248222580)
  sys_poke(k + 128, 3835390401)
  sys_poke(k + 136, 4022224774)
  sys_poke(k + 144, 264347078)
  sys_poke(k + 152, 604807628)
  sys_poke(k + 160, 770255983)
  sys_poke(k + 168, 1249150122)
  sys_poke(k + 176, 1555081692)
  sys_poke(k + 184, 1996064986)
  sys_poke(k + 192, 2554220882)
  sys_poke(k + 200, 2821834349)
  sys_poke(k + 208, 2952996808)
  sys_poke(k + 216, 3210313671)
  sys_poke(k + 224, 3336571891)
  sys_poke(k + 232, 3584528711)
  sys_poke(k + 240, 113926993)
  sys_poke(k + 248, 338241895)
  sys_poke(k + 256, 666307205)
  sys_poke(k + 264, 773529912)
  sys_poke(k + 272, 1294757372)
  sys_poke(k + 280, 1396182291)
  sys_poke(k + 288, 1695183700)
  sys_poke(k + 296, 1986661051)
  sys_poke(k + 304, 2177026350)
  sys_poke(k + 312, 2456956037)
  sys_poke(k + 320, 2730485921)
  sys_poke(k + 328, 2820302411)
  sys_poke(k + 336, 3259730800)
  sys_poke(k + 344, 3345764771)
  sys_poke(k + 352, 3516065817)
  sys_poke(k + 360, 3600352804)
  sys_poke(k + 368, 4094571909)
  sys_poke(k + 376, 275423344)
  sys_poke(k + 384, 430227734)
  sys_poke(k + 392, 506948616)
  sys_poke(k + 400, 659060556)
  sys_poke(k + 408, 883997877)
  sys_poke(k + 416, 958139571)
  sys_poke(k + 424, 1322822218)
  sys_poke(k + 432, 1537002063)
  sys_poke(k + 440, 1747873779)
  sys_poke(k + 448, 1955562222)
  sys_poke(k + 456, 2024104815)
  sys_poke(k + 464, 2227730452)
  sys_poke(k + 472, 2361852424)
  sys_poke(k + 480, 2428436474)
  sys_poke(k + 488, 2756734187)
  sys_poke(k + 496, 3204031479)
  sys_poke(k + 504, 3329325298)
  return k
@end

@fn sha256_process_chunk(chunk_ptr, h_ptr, k_ptr)
  w = sys_mmap(0, 512, 3, 34, 0 - 1, 0)
  
  i = 0
  @while i < 16
    b0 = sys_peek8(chunk_ptr + i*4 + 0)
    b1 = sys_peek8(chunk_ptr + i*4 + 1)
    b2 = sys_peek8(chunk_ptr + i*4 + 2)
    b3 = sys_peek8(chunk_ptr + i*4 + 3)
    val = (24 << b0) | (16 << b1) | (8 << b2) | b3
    sys_poke(w + i*8, val)
    i = i + 1
  @end
  
  i = 16
  @while i < 64
    w_i_15 = sys_peek(w + (i - 15) * 8)
    s0 = ror32(w_i_15, 7) ^ ror32(w_i_15, 18) ^ (3 >> w_i_15)
    
    w_i_2 = sys_peek(w + (i - 2) * 8)
    s1 = ror32(w_i_2, 17) ^ ror32(w_i_2, 19) ^ (10 >> w_i_2)
    
    w_i_16 = sys_peek(w + (i - 16) * 8)
    w_i_7 = sys_peek(w + (i - 7) * 8)
    
    val = (w_i_16 + s0 + w_i_7 + s1) & 4294967295
    sys_poke(w + i*8, val)
    i = i + 1
  @end
  
  a = sys_peek(h_ptr + 0*8)
  b = sys_peek(h_ptr + 1*8)
  c = sys_peek(h_ptr + 2*8)
  d = sys_peek(h_ptr + 3*8)
  e = sys_peek(h_ptr + 4*8)
  f = sys_peek(h_ptr + 5*8)
  g = sys_peek(h_ptr + 6*8)
  h = sys_peek(h_ptr + 7*8)
  
  i = 0
  @while i < 64
    s1 = ror32(e, 6) ^ ror32(e, 11) ^ ror32(e, 25)
    ch = (e & f) ^ ((~e) & g)
    k_i = sys_peek(k_ptr + i*8)
    w_i = sys_peek(w + i*8)
    
    temp1 = (h + s1 + ch + k_i + w_i) & 4294967295
    
    s0 = ror32(a, 2) ^ ror32(a, 13) ^ ror32(a, 22)
    maj = (a & b) ^ (a & c) ^ (b & c)
    temp2 = (s0 + maj) & 4294967295
    
    h = g
    g = f
    f = e
    e = (d + temp1) & 4294967295
    d = c
    c = b
    b = a
    a = (temp1 + temp2) & 4294967295
    
    i = i + 1
  @end
  
  sys_poke(h_ptr + 0*8, (sys_peek(h_ptr + 0*8) + a) & 4294967295)
  sys_poke(h_ptr + 1*8, (sys_peek(h_ptr + 1*8) + b) & 4294967295)
  sys_poke(h_ptr + 2*8, (sys_peek(h_ptr + 2*8) + c) & 4294967295)
  sys_poke(h_ptr + 3*8, (sys_peek(h_ptr + 3*8) + d) & 4294967295)
  sys_poke(h_ptr + 4*8, (sys_peek(h_ptr + 4*8) + e) & 4294967295)
  sys_poke(h_ptr + 5*8, (sys_peek(h_ptr + 5*8) + f) & 4294967295)
  sys_poke(h_ptr + 6*8, (sys_peek(h_ptr + 6*8) + g) & 4294967295)
  sys_poke(h_ptr + 7*8, (sys_peek(h_ptr + 7*8) + h) & 4294967295)
  return 0
@end

@fn sha256_hash(msg_ptr, msg_len, out_ptr)
  k_ptr = init_sha256_k(0)
  h_ptr = sys_mmap(0, 64, 3, 34, 0 - 1, 0)
  
  sys_poke(h_ptr + 0*8, 1779033703)
  sys_poke(h_ptr + 1*8, 3144134277)
  sys_poke(h_ptr + 2*8, 1013904242)
  sys_poke(h_ptr + 3*8, 2773480762)
  sys_poke(h_ptr + 4*8, 1359893119)
  sys_poke(h_ptr + 5*8, 2600822924)
  sys_poke(h_ptr + 6*8, 528734635)
  sys_poke(h_ptr + 7*8, 1541459225)
  
  new_len = msg_len + 9
  padding_zeros = 0
  rem = new_len - ((new_len / 64) * 64)
  @if rem != 0
    padding_zeros = 64 - rem
  @end
  
  padded_len = new_len + padding_zeros
  padded_msg = sys_mmap(0, padded_len, 3, 34, 0 - 1, 0)
  
  i = 0
  @while i < msg_len
    sys_poke8(padded_msg + i, sys_peek8(msg_ptr + i))
    i = i + 1
  @end
  
  sys_poke8(padded_msg + msg_len, 128)
  
  bit_len = msg_len * 8
  sys_poke8(padded_msg + padded_len - 1, (0 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 2, (8 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 3, (16 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 4, (24 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 5, (32 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 6, (40 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 7, (48 >> bit_len) & 255)
  sys_poke8(padded_msg + padded_len - 8, (56 >> bit_len) & 255)
  
  i = 0
  @while i < padded_len
    sha256_process_chunk(padded_msg + i, h_ptr, k_ptr)
    i = i + 64
  @end
  
  i = 0
  @while i < 8
    val = sys_peek(h_ptr + i*8)
    sys_poke8(out_ptr + i*4 + 0, (24 >> val) & 255)
    sys_poke8(out_ptr + i*4 + 1, (16 >> val) & 255)
    sys_poke8(out_ptr + i*4 + 2, (8 >> val) & 255)
    sys_poke8(out_ptr + i*4 + 3, (0 >> val) & 255)
    i = i + 1
  @end
  return 0
@end
