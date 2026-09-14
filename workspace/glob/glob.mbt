///|
fn component(pattern : String, name : String) -> Bool {
  let p = pattern.iter().to_array()
  let n = name.iter().to_array()
  let mut row = Array::make(n.length() + 1, false)
  row[0] = true
  for c in p {
    let next = Array::make(n.length() + 1, false)
    if c == '*' {
      next[0] = row[0]
    }
    for j in 0..<n.length() {
      next[j + 1] = if c == '*' {
        row[j + 1] || next[j]
      } else {
        row[j] && (c == '?' || c == n[j])
      }
    }
    row = next
  }
  row[n.length()]
}

///|
/// Root-anchored, case-sensitive portable glob. * and ? match within one
/// component; ? consumes one Unicode scalar. ** is a whole component matching
/// zero or more directories. No negation, braces, character classes or escapes.
/// Both slash forms are separators. Reject unsafe paths and oversized inputs.
pub fn matches(pattern : String, path : String) -> Result[Bool, String] {
  if pattern.length() > 1024 || path.length() > 4096 {
    return Err("MR_GLOB_LIMIT: pattern or path too long")
  }
  for c in ['[', ']', '{', '}', '!'] {
    if pattern.contains(c.to_string()) {
      return Err("MR_GLOB_SYNTAX: unsupported pattern syntax")
    }
  }
  let portable = pattern.replace_all(old="\\", new="/")
  let probe = portable
    .replace_all(old="*", new="x")
    .replace_all(old="?", new="x")
  match @source.validate_path(probe) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let parts = portable
    .split("/")
    .map(x => x.to_owned())
    .filter(x => x != ".")
    .to_array()
  for part in parts {
    if part.contains("**") && part != "**" {
      return Err("MR_GLOB_SYNTAX: double star must occupy a whole component")
    }
  }
  let path = match @source.validate_path(path) {
    Err(e) => return Err(e)
    Ok(p) => p
  }
  let names = path.split("/").map(x => x.to_owned()).to_array()
  let mut row = Array::make(names.length() + 1, false)
  row[0] = true
  for part in parts {
    let next = Array::make(names.length() + 1, false)
    if part == "**" {
      next[0] = row[0]
    }
    for j in 0..<names.length() {
      next[j + 1] = if part == "**" {
        row[j + 1] || next[j]
      } else {
        row[j] && component(part, names[j])
      }
    }
    row = next
  }
  Ok(row[names.length()])
}
