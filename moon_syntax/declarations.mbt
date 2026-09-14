///|
/// Conservative syntax range usable as an independently predicate-tested edit.
pub(all) struct Node {
  kind : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson)

///|
fn significant(token : Token) -> Bool {
  !["space", "doc", "line-comment", "block-comment"].contains(token.kind)
}

///|
/// Recognize top-level declaration starts outside all balanced groups.
/// Includes visibility/async/extern modifiers, retains trailing derive clauses.
/// Unknown syntax is not invented as a declaration; malformed scans yield none.
pub fn declarations(tree : ReductionTree) -> Array[Node] {
  if !tree.diagnostics.is_empty() {
    return []
  }
  let starts : Array[(String, Int)] = []
  let mut prefix : Int? = None
  for token in tree.tokens {
    if !significant(token) {
      continue
    }
    let mut nested = false
    for g in tree.groups {
      if token.start >= g.start && token.end <= g.end {
        nested = true
        break
      }
    }
    if nested {
      continue
    }
    if ["pub", "priv", "async", "extern"].contains(token.text) &&
      token.kind == "word" {
      if prefix is None {
        prefix = Some(token.start)
      }
    } else if token.kind == "word" &&
      [
        "fn", "struct", "enum", "trait", "impl", "type", "typealias", "const", "let",
        "test",
      ].contains(token.text) {
      starts.push((token.text, prefix.unwrap_or(token.start)))
      prefix = None
    } else if token.kind != "string" {
      prefix = None
    }
  }
  let nodes : Array[Node] = []
  let end = if tree.tokens.is_empty() {
    0
  } else {
    tree.tokens[tree.tokens.length() - 1].end
  }
  for i in 0..<starts.length() {
    nodes.push({
      kind: starts[i].0,
      start: starts[i].1,
      end: if i + 1 < starts.length() {
        starts[i + 1].1
      } else {
        end
      },
    })
  }
  nodes
}
