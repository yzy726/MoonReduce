///|
/// Stable registry order. Formatting remains opt-in at the proposal boundary.
pub fn names() -> Array[String] {
  [
    "import", "function", "type-declaration", "test", "parameter", "field", "statement",
    "if-branch", "match-arm", "loop-body", "binding", "expression", "type-annotation",
    "metadata", "identifier-literal", "format",
  ]
}

///|
fn cleanup_edits(
  name : String,
  tree : @moon_syntax.ReductionTree,
  bytes : Bytes,
  allow_format : Bool,
) -> Array[(Int, Int, String)] {
  let edits : Array[(Int, Int, String)] = []
  let sig = tree.tokens.filter(t => {
    !["space", "doc", "line-comment", "block-comment"].contains(t.kind)
  })
  if name == "type-annotation" {
    for i in 0..<sig.length() {
      let t = sig[i]
      if t.text != ":" ||
        (i > 0 && sig[i - 1].text == ":") ||
        (i + 1 < sig.length() && sig[i + 1].text == ":") {
        continue
      }
      let mut end = t.end
      for j in (i + 1)..<sig.length() {
        if ["=", ";", ",", ")", "}", "{"].contains(sig[j].text) {
          break
        }
        end = sig[j].end
      }
      if end > t.end {
        edits.push((t.start, end, ""))
      }
    }
    for g in tree.groups {
      if g.kind != "[" {
        continue
      }
      for t in sig {
        if t.end == g.start && t.kind == "word" {
          edits.push((g.start, g.end, ""))
          break
        }
      }
    }
  }
  if name == "metadata" {
    for t in tree.tokens {
      if t.kind == "doc" {
        edits.push((t.start, t.end, ""))
      }
      if t.kind == "punct" && t.text == "#" {
        let mut end = t.end
        while end < bytes.length() && bytes[end] != b'\n' && bytes[end] != b'\r' {
          end += 1
        }
        edits.push((t.start, end, ""))
      }
    }
    for i in 1..<sig.length() {
      if sig[i].kind == "string" && sig[i - 1].text == "test" {
        edits.push((sig[i].start, sig[i].end, ""))
      }
    }
  }
  if name == "identifier-literal" {
    let keywords = [
      "fn", "pub", "priv", "all", "async", "extern", "struct", "enum", "trait", "impl",
      "type", "typealias", "const", "let", "mut", "test", "if", "else", "match",
      "for", "while", "loop", "break", "continue", "return", "raise", "try", "catch",
      "finally", "nobreak", "guard", "is", "as", "in", "with", "derive", "true",
      "false", "import", "defer", "suberror", "typeerror",
    ]
    for t in sig {
      if t.kind == "word" && !keywords.contains(t.text) && t.text != "x" {
        edits.push((t.start, t.end, "x"))
      }
      if t.kind == "number" {
        edits.push((t.start, t.end, "0"))
      }
      if t.kind == "string" {
        edits.push((t.start, t.end, "\"\""))
      }
    }
  }
  if name == "format" && allow_format {
    for t in tree.tokens {
      if t.kind == "space" && t.text.length() > 1 {
        edits.push(
          (t.start, t.end, if t.text.contains("\n") { "\n" } else { " " }),
        )
      }
    }
  }
  edits
}
