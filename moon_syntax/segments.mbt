///|
fn direct_tokens(tree : ReductionTree, group : Group) -> Array[Token] {
  let result : Array[Token] = []
  let mut skip = group.inner_start
  for token in tree.tokens {
    if token.start < skip || token.end > group.inner_end {
      continue
    }
    let mut child : Group? = None
    for g in tree.groups {
      if g.start == token.start && g.depth == group.depth + 1 {
        child = Some(g)
        break
      }
    }
    if child is Some(g) {
      result.push({ kind: "group", text: g.kind, start: g.start, end: g.end })
      skip = g.end
    } else {
      result.push(token)
    }
  }
  result
}

///|
fn line_ends(previous : Token, next : Token?) -> Bool {
  if [
      "=", "+", "-", "*", "/", ".", ",", ":", "|", "&", "<", ">", "!", "?", "\\",
    ].contains(previous.text) {
    return false
  }
  if previous.kind == "word" &&
    [
      "let", "mut", "return", "raise", "if", "else", "match", "for", "while", "try",
      "catch", "fn", "async",
    ].contains(previous.text) {
    return false
  }
  if next is Some(t) {
    if [
        ".", "+", "-", "*", "/", "|", "&", "=", "else", "catch", "finally", "nobreak",
      ].contains(t.text) {
      return false
    }
  }
  true
}

///|
/// Conservative direct-child ranges in a validated group. Mode comma splits
/// lists; statements splits semicolons and non-continuation newlines. Nested
/// groups are opaque. These are proposals, not guarantees of syntactic validity.
/// Invalid scans, foreign groups and unknown modes produce no edits.
pub fn segments(
  tree : ReductionTree,
  group : Group,
  mode : String,
) -> Array[Node] {
  if !tree.diagnostics.is_empty() ||
    !tree.groups.contains(group) ||
    !["comma", "statements"].contains(mode) {
    return []
  }
  let tokens = direct_tokens(tree, group)
  let result : Array[Node] = []
  let mut start : Int? = None
  let mut previous : Token? = None
  let mut kind = "expression"
  for i in 0..<tokens.length() {
    let token = tokens[i]
    let delimiter = token.kind == "punct" &&
      (
        (mode == "comma" && token.text == ",") ||
        (mode == "statements" && token.text == ";")
      )
    let mut newline = false
    if mode == "statements" &&
      token.kind == "space" &&
      token.text.contains("\n") {
      let mut next : Token? = None
      for j in (i + 1)..<tokens.length() {
        if significant(tokens[j]) {
          next = Some(tokens[j])
          break
        }
      }
      if previous is Some(p) {
        newline = line_ends(p, next)
      }
    }
    if delimiter || newline {
      if start is Some(s) && previous is Some(p) {
        result.push({
          kind,
          start: s,
          end: if delimiter {
            token.end
          } else {
            p.end
          },
        })
      }
      start = None
      previous = None
    } else if significant(token) {
      if start is None {
        start = Some(token.start)
        kind = if token.kind == "word" &&
          ["let", "if", "match", "for", "while", "return", "raise"].contains(
            token.text,
          ) {
          token.text
        } else {
          "expression"
        }
      }
      previous = Some(token)
    }
  }
  if start is Some(s) && previous is Some(p) {
    result.push({ kind, start: s, end: p.end })
  }
  result
}
