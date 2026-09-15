///|
fn rotate(value : UInt, count : Int) -> UInt {
  (value >> count) | (value << (32 - count))
}

///|
/// SHA-256 of arbitrary bytes, encoded as 64 lowercase hexadecimal digits.
/// Pure implementation with fixed-size schedule; no platform cryptography or I/O.
pub fn digest(input : Bytes) -> String {
  let constants : Array[UInt] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
    0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
    0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
    0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
    0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
    0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
    0xc67178f2,
  ]
  let state : Array[UInt] = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ]
  let schedule : Array[UInt] = Array::make(64, 0)
  let length = input.length()
  let blocks = length / 64 + (if length % 64 < 56 { 1 } else { 2 })
  let bits = length.to_uint64() * 8UL
  for block = 0; block < blocks; block = block + 1 {
    for word = 0; word < 16; word = word + 1 {
      let mut value : UInt = 0
      for byte = 0; byte < 4; byte = byte + 1 {
        let position = block * 64 + word * 4 + byte
        let part : UInt = if position < length {
          input[position].to_int().reinterpret_as_uint()
        } else if position == length {
          128U
        } else if block == blocks - 1 && word >= 14 {
          ((bits >> ((blocks * 64 - 1 - position) * 8)) & 255UL).to_uint()
        } else {
          0U
        }
        value = (value << 8) | part
      }
      schedule[word] = value
    }
    for i = 16; i < 64; i = i + 1 {
      let x = schedule[i - 15]
      let y = schedule[i - 2]
      let s0 = rotate(x, 7) ^ rotate(x, 18) ^ (x >> 3)
      let s1 = rotate(y, 17) ^ rotate(y, 19) ^ (y >> 10)
      schedule[i] = schedule[i - 16] + s0 + schedule[i - 7] + s1
    }
    let mut a = state[0]
    let mut b = state[1]
    let mut c = state[2]
    let mut d = state[3]
    let mut e = state[4]
    let mut f = state[5]
    let mut g = state[6]
    let mut h = state[7]
    for i = 0; i < 64; i = i + 1 {
      let s1 = rotate(e, 6) ^ rotate(e, 11) ^ rotate(e, 25)
      let choice = (e & f) ^ ((e ^ 0xffffffffU) & g)
      let t1 = h + s1 + choice + constants[i] + schedule[i]
      let s0 = rotate(a, 2) ^ rotate(a, 13) ^ rotate(a, 22)
      let majority = (a & b) ^ (a & c) ^ (b & c)
      let t2 = s0 + majority
      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    }
    state[0] += a
    state[1] += b
    state[2] += c
    state[3] += d
    state[4] += e
    state[5] += f
    state[6] += g
    state[7] += h
  }
  let out = StringBuilder()
  let hex = "0123456789abcdef"
  for word in state {
    for shift = 28; shift >= 0; shift = shift - 4 {
      out.write_char(
        hex[((word >> shift) & 15U).reinterpret_as_int()].to_char().unwrap(),
      )
    }
  }
  out.to_string()
}
