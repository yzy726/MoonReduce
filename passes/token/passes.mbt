///|
/// Token pass order, used unchanged on all supported algorithm backends.
pub fn names() -> Array[String] {
  ["balanced", "token-range", "token", "string", "number"]
}

///|
/// Content tokens exclude whitespace and comments.
pub fn significant(s : String) -> Array[Token] {
  scan(s).filter(t => {
    t.kind != "space" &&
    t.kind != "line-comment" &&
    t.kind != "block-comment" &&
    t.kind != "doc"
  })
}

///|
/// Conservative deterministic proposals; every candidate still needs the predicate.
pub fn propose_iter(name : String, s : String) -> Iter[String] {
  let ts = significant(s)
  let edits : Array[(Int, Int, String)] = []
  match name {
    "token" =>
      for t in ts {
        edits.push((t.start, t.end, ""))
      }
    "token-range" => {
      let mut width = ts.length() / 2
      while width >= 2 {
        let mut i = 0
        while i < ts.length() {
          edits.push(
            (ts[i].start, ts[(i + width).min(ts.length()) - 1].end, ""),
          )
          i += width
        }
        width /= 2
      }
    }
    "string" =>
      for t in ts {
        if t.kind == "string" && t.text.length() > 2 && t.text.has_suffix("\"") {
          edits.push((t.start, t.end, "\"\""))
        }
      }
    "number" =>
      for t in ts {
        if t.kind == "number" && t.text.length() > 1 {
          edits.push((t.start, t.end, "0"))
          edits.push((t.start, t.end, "1"))
        }
      }
    "balanced" => {
      let stack : Array[Token] = []
      let mut malformed = false
      for t in ts {
        if t.kind != "punct" {
          continue
        }
        if ["(", "[", "{"].contains(t.text) {
          stack.push(t)
        } else if [")", "]", "}"].contains(t.text) {
          match stack.pop() {
            None => {
              malformed = true
              break
            }
            Some(open) => {
              let expected = match open.text {
                "(" => ")"
                "[" => "]"
                _ => "}"
              }
              if t.text != expected {
                malformed = true
                break
              }
              if open.end < t.start {
                edits.push((open.end, t.start, ""))
              }
            }
          }
        }
      }
      if malformed || !stack.is_empty() {
        return [].iter()
      }
    }
    _ => ()
  }
  edits.iter().map(e => s[:e.0].to_owned() + e.2 + s[e.1:].to_owned())
}

///|
/// Collect proposals for small inputs; the engine consumes propose_iter lazily.
pub fn propose(name : String, s : String) -> Array[String] {
  propose_iter(name, s).to_array()
}
