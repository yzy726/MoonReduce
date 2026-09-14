///|
fn declaration_edits(
  name : String,
  tree : @moon_syntax.ReductionTree,
) -> Array[(Int, Int, String)] {
  let edits : Array[(Int, Int, String)] = []
  let declarations = @moon_syntax.declarations(tree)
  for d in declarations {
    if (name == "function" && d.kind == "fn") ||
      (name == "test" && d.kind == "test") ||
      (
        name == "type-declaration" &&
        ["struct", "enum", "trait", "impl", "type", "typealias"].contains(
          d.kind,
        )
      ) {
      edits.push((d.start, d.end, ""))
    }
    if (name == "parameter" && d.kind == "fn") ||
      (name == "field" && ["struct", "enum"].contains(d.kind)) {
      let mut keyword_end = d.start
      for t in tree.tokens {
        if t.start >= d.start && t.end <= d.end && t.text == d.kind {
          keyword_end = t.end
          break
        }
      }
      for g in tree.groups {
        if g.depth != 0 || g.start < keyword_end || g.end > d.end {
          continue
        }
        if name == "parameter" && g.kind == "{" {
          break
        }
        if (name == "parameter" && ["(", "["].contains(g.kind)) ||
          (name == "field" && g.kind == "{") {
          for part in @moon_syntax.segments(tree, g, "comma") {
            edits.push((part.start, part.end, ""))
          }
          if name == "field" || g.kind == "(" {
            break
          }
        }
      }
    }
  }
  if name == "import" {
    for t in tree.tokens {
      if t.kind != "word" || t.text != "import" {
        continue
      }
      let mut nested = false
      for container in tree.groups {
        if t.start >= container.start && t.end <= container.end {
          nested = true
          break
        }
      }
      if nested {
        continue
      }
      for g in tree.groups {
        if g.depth == 0 && g.kind == "{" && g.start >= t.end {
          edits.push((t.start, g.end, ""))
          break
        }
      }
    }
  }
  edits
}

///|
/// Generate byte-range edits lazily. Every result is strictly smaller and still
/// requires external predicate validation. Incomplete syntax returns no edits.
pub fn propose_iter(name : String, source : String) -> Iter[String] {
  let tree = @moon_syntax.scan(source)
  if !tree.diagnostics.is_empty() {
    return [].iter()
  }
  let bytes = @source.encode(source)
  let edits = declaration_edits(name, tree)
  edits.append(body_edits(name, tree, bytes))
  let seen : Map[String, Bool] = Map([])
  edits
  .iter()
  .filter_map(edit => {
    match @source.apply_edit(bytes, edit.0, edit.1, @source.encode(edit.2)) {
      Ok(output) if output.length() < bytes.length() =>
        match @source.decode(output) {
          Ok(candidate) if !seen.contains(candidate) => {
            seen[candidate] = true
            Some(candidate)
          }
          _ => None
        }
      _ => None
    }
  })
}

///|
/// Collect proposals for inspection and small tests. Prefer the lazy interface
/// when driving a reducer so a successful candidate can stop the current pass.
pub fn propose(name : String, source : String) -> Array[String] {
  propose_iter(name, source).to_array()
}
