///|
/// Stable text pass order from coarse deletion to comment cleanup.
pub fn names() -> Array[String] {
  [
    "line-block", "line", "blank-line", "line-comment", "block-comment", "doc-comment",
    "trim-edge",
  ]
}

///|
/// Exact line spans, including the newline; no synthetic trailing empty line.
pub fn lines(s : String) -> Array[(Int, Int)] {
  let result = []
  let mut start = 0
  for i in 0..<s.length() {
    if s[i] == 10 {
      result.push((start, i + 1))
      start = i + 1
    }
  }
  if start < s.length() {
    result.push((start, s.length()))
  }
  result
}

///|
/// Deterministic deletion proposals. Strings/comments use the tolerant lexer.
pub fn propose(name : String, s : String) -> Array[String] {
  let spans : Array[(Int, Int)] = []
  let ls = lines(s)
  match name {
    "line" => spans.append(ls)
    "blank-line" =>
      for span in ls {
        if s[span.0:span.1].trim().is_empty() {
          spans.push(span)
        }
      }
    "line-block" => {
      let mut width = ls.length() / 2
      while width >= 2 {
        let mut i = 0
        while i < ls.length() {
          spans.push((ls[i].0, ls[(i + width).min(ls.length()) - 1].1))
          i += width
        }
        width /= 2
      }
    }
    "trim-edge" =>
      if ls.length() > 1 {
        let middle = ls.length() / 2
        spans.push((0, ls[middle].0))
        spans.push((ls[middle].0, s.length()))
      }
    "line-comment" | "block-comment" | "doc-comment" => {
      let kind = if name == "doc-comment" { "doc" } else { name }
      for t in @token.scan(s) {
        if t.kind == kind {
          spans.push((t.start, t.end))
        }
      }
    }
    _ => ()
  }
  spans.filter(p => p.1 > p.0).map(p => s[:p.0].to_owned() + s[p.1:].to_owned())
}
