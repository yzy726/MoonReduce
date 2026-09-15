///|
/// Conservative opt-in manifest edits. moon.pkg import entries may be removed;
/// moon.mod only permits description, keywords and repository assignments.
/// Names, versions, licenses, build settings and module dependencies are never
/// changed. Malformed or unsupported syntax produces no proposals.
pub fn propose(file : String, text : String) -> Array[String] {
  if file != "moon.pkg" && file != "moon.mod" {
    return []
  }
  let tree = @moon_syntax.scan(text)
  if !tree.diagnostics.is_empty() {
    return []
  }
  let tokens = tree.tokens.filter(t => {
    t.kind != "space" && !t.kind.contains("comment")
  })
  let edits : Array[(Int, Int)] = []
  for i in 0..<tokens.length() {
    let t = tokens[i]
    if tree.groups.iter().any(g => t.start >= g.start && t.end <= g.end) {
      continue
    }
    if file == "moon.pkg" &&
      t.text == "import" &&
      tokens.get(i + 1) is Some(next) &&
      next.text == "{" {
      for g in tree.groups {
        if g.start == next.start && g.depth == 0 {
          for part in @moon_syntax.segments(tree, g, "comma") {
            edits.push((part.start, part.end))
          }
          edits.push((g.inner_start, g.inner_end))
        }
      }
    }
    if file == "moon.mod" &&
      ["description", "keywords", "repository"].contains(t.text) &&
      i + 2 < tokens.length() &&
      tokens[i + 1].text == "=" {
      let value = tokens[i + 2]
      if value.kind == "string" {
        edits.push((t.start, value.end))
      } else if value.text == "[" {
        for g in tree.groups {
          if g.start == value.start && g.depth == 0 {
            edits.push((t.start, g.end))
          }
        }
      }
    }
  }
  let bytes = @source.encode(text)
  let result : Array[String] = []
  for edit in edits {
    match @source.apply_edit(bytes, edit.0, edit.1, b"") {
      Ok(bytes) =>
        match @source.decode(bytes) {
          Ok(candidate) =>
            if candidate != text && !result.contains(candidate) {
              result.push(candidate)
            }
          Err(_) => ()
        }
      Err(_) => ()
    }
  }
  result
}
