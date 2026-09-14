///|
/// Validated immutable portable project contents. No filesystem operations.
/// Entries and bytes are copied at the public boundary.
pub struct Snapshot {
  entries : Array[(String, Bytes)]
}

///|
fn copy_bytes(b : Bytes) -> Bytes {
  Bytes::from_array(FixedArray::makei(b.length(), i => b[i]))
}

///|
/// Canonicalize and sort paths, reject case collisions and file/directory
/// conflicts. Limits: 1000 entries, 1 MiB/file, 64 KiB/mbt and 16 MiB total.
/// Source files must contain strict UTF8; support files may be binary.
pub fn Snapshot::new(
  files : Array[(String, Bytes)],
) -> Result[Snapshot, String] {
  if files.length() > 1000 {
    return Err("MR_INPUT_LIMIT: too many project entries")
  }
  let entries : Array[(String, Bytes)] = []
  let seen : Map[String, Bool] = Map([])
  let mut total = 0
  for entry in files {
    let (path, bytes) = entry
    let path = match @source.validate_path(path) {
      Err(e) => return Err(e)
      Ok(p) => p
    }
    let lower = path.to_lower()
    if seen.contains(lower) {
      return Err("MR_INPUT_PATH: duplicate or case-colliding path")
    }
    seen[lower] = true
    if bytes.length() > 1048576 ||
      (lower.has_suffix(".mbt") && bytes.length() > 65536) {
      return Err("MR_INPUT_LIMIT: file too large")
    }
    total += bytes.length()
    if total > 16777216 {
      return Err("MR_INPUT_LIMIT: project exceeds 16 MiB")
    }
    if lower.has_suffix(".mbt") {
      match @source.decode(bytes) {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
    entries.push((path, bytes))
  }
  let directories : Map[String, String] = Map([])
  for entry in entries {
    let path = entry.0
    let parts = path.split("/").map(x => x.to_owned()).to_array()
    let mut parent = ""
    for i in 0..<(parts.length() - 1) {
      parent = if i == 0 { parts[i] } else { parent + "/" + parts[i] }
      let lower = parent.to_lower()
      match directories.get(lower) {
        Some(spelling) if spelling != parent =>
          return Err("MR_INPUT_PATH: directory case collision")
        _ => directories[lower] = parent
      }
      if seen.contains(parent.to_lower()) {
        return Err("MR_INPUT_PATH: file conflicts with directory")
      }
    }
  }
  entries.sort_by((a, b) => a.0.compare(b.0))
  Ok({ entries: entries.map(x => (x.0, copy_bytes(x.1))) })
}

///|
/// Defensive copy in stable path order.
pub fn Snapshot::files(self : Snapshot) -> Array[(String, Bytes)] {
  self.entries.map(x => (x.0, copy_bytes(x.1)))
}

///|
/// Replace an existing entry, returning a newly validated snapshot.
pub fn Snapshot::replace(
  self : Snapshot,
  path : String,
  bytes : Bytes,
) -> Result[Snapshot, String] {
  let path = match @source.validate_path(path) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let mut found = false
  let files = self.entries.map(x => {
    if x.0 == path {
      found = true
      (path, bytes)
    } else {
      x
    }
  })
  if !found {
    return Err("MR_INPUT_PATH: replacement target missing")
  }
  Snapshot::new(files)
}

///|
/// Remove exactly one existing entry without mutating this snapshot.
pub fn Snapshot::remove(
  self : Snapshot,
  path : String,
) -> Result[Snapshot, String] {
  let path = match @source.validate_path(path) {
    Ok(p) => p
    Err(e) => return Err(e)
  }
  let files = self.entries.filter(x => x.0 != path)
  if files.length() == self.entries.length() {
    return Err("MR_INPUT_PATH: removal target missing")
  }
  Snapshot::new(files)
}

///|
/// Exact versioned content key, not a digest. Includes every path and byte;
/// length framing prevents ambiguity. Evaluators must also key their config.
pub fn Snapshot::key(self : Snapshot) -> String {
  let out = StringBuilder()
  out.write_string("snapshot-v1;")
  for entry in self.entries {
    let (path, bytes) = entry
    out.write_string(
      path.length().to_string() +
      ":" +
      path +
      ":" +
      bytes.length().to_string() +
      ":",
    )
    for b in bytes {
      let h = b.to_int().to_string(radix=16)
      if h.length() == 1 {
        out.write_string("0")
      }
      out.write_string(h)
    }
    out.write_string(";")
  }
  out.to_string()
}
