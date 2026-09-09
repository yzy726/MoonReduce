///|
/// Portable, traversal-free relative path. Windows aliases are rejected everywhere.
pub fn validate_path(path : String) -> Result[String, String] {
  let p = path.replace_all(old="\\", new="/")
  if p == "" || p.has_prefix("/") || p.contains(":") || p.contains("\u0000") {
    return Err("MR_INPUT_PATH: expected a relative path")
  }
  let parts : Array[String] = []
  for part in p.split("/") {
    let s = part.to_owned()
    if s == "." {
      continue
    }
    if s == "" || s == ".." || s.has_suffix(".") || s.has_suffix(" ") {
      return Err("MR_INPUT_PATH: unsafe path component")
    }
    let stem = s.split(".").to_array()[0].to_owned().to_lower()
    if [
        "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6",
        "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7",
        "lpt8", "lpt9",
      ].contains(stem) {
      return Err("MR_INPUT_PATH: reserved filename")
    }
    parts.push(s)
  }
  if parts.is_empty() {
    Err("MR_INPUT_PATH: empty path")
  } else {
    Ok(parts.join("/"))
  }
}

///|
/// Decode strictly, retaining a UTF-8 BOM if present.
pub fn decode(bytes : Bytes) -> Result[String, String] {
  Ok(@utf8.decode(bytes, ignore_bom=false)) catch {
    _ => Err("MR_INPUT_ENCODING: invalid UTF-8")
  }
}

///|
/// Encode text without adding a BOM.
pub fn encode(text : String) -> Bytes {
  @utf8.encode(text)
}

///|
/// Apply a single half-open byte edit, rejecting invalid bounds and broken UTF-8.
pub fn apply_edit(
  bytes : Bytes,
  start : Int,
  end : Int,
  replacement : Bytes,
) -> Result[Bytes, String] {
  if start < 0 || end < start || end > bytes.length() {
    return Err("MR_INPUT_SPAN: out of bounds")
  }
  if (start < bytes.length() && (bytes[start].to_int() & 0xC0) == 0x80) ||
    (end < bytes.length() && (bytes[end].to_int() & 0xC0) == 0x80) {
    return Err("MR_INPUT_SPAN: split UTF-8 codepoint")
  }
  let output : FixedArray[Byte] = FixedArray::make(
    bytes.length() - (end - start) + replacement.length(),
    0,
  )
  for i in 0..<start {
    output[i] = bytes[i]
  }
  for i in 0..<replacement.length() {
    output[start + i] = replacement[i]
  }
  for i in end..<bytes.length() {
    output[start + replacement.length() + i - end] = bytes[i]
  }
  let output = Bytes::from_array(output)
  match decode(output) {
    Ok(_) => Ok(output)
    Err(e) => Err(e)
  }
}

///|
/// Stable FNV-1a 64-bit identifier, not a security checksum. Cache uses full content.
pub fn digest(bytes : Bytes) -> String {
  let mut hash = 14695981039346656037UL
  for b in bytes {
    hash = (hash ^ b.to_uint64()) * 1099511628211UL
  }
  hash.to_string(radix=16)
}
