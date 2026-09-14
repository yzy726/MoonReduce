///|
fn executable_group(
  tree : @moon_syntax.ReductionTree,
  group : @moon_syntax.Group,
) -> Bool {
  for d in @moon_syntax.declarations(tree) {
    if !["fn", "test"].contains(d.kind) {
      continue
    }
    for body in tree.groups {
      if body.depth == 0 &&
        body.kind == "{" &&
        body.start >= d.start &&
        body.end <= d.end {
        if group.start >= body.start && group.end <= body.end {
          return true
        }
        break
      }
    }
  }
  false
}

///|
fn byte_text(bytes : Bytes, start : Int, end : Int) -> String {
  let slice = Bytes::from_array(
    FixedArray::makei(end - start, i => bytes[start + i]),
  )
  match @source.decode(slice) {
    Ok(s) => s
    Err(_) => ""
  }
}

///|
fn body_edits(
  name : String,
  tree : @moon_syntax.ReductionTree,
  bytes : Bytes,
) -> Array[(Int, Int, String)] {
  let edits : Array[(Int, Int, String)] = []
  for group in tree.groups {
    if group.kind != "{" || !executable_group(tree, group) {
      continue
    }
    if name == "statement" || name == "binding" {
      for node in @moon_syntax.segments(tree, group, "statements") {
        if name == "statement" {
          edits.push((node.start, node.end, ""))
        } else if node.kind == "let" {
          for token in tree.tokens {
            if token.start >= node.start &&
              token.end <= node.end &&
              token.text == "=" {
              let end = if bytes[node.end - 1] == b';' {
                node.end - 1
              } else {
                node.end
              }
              edits.push((token.end, end, " 0"))
              edits.push((token.end, end, " ()"))
              break
            }
          }
        }
      }
    }
  }
  if ["if-branch", "match-arm", "loop-body"].contains(name) {
    for token in tree.tokens {
      if token.kind != "word" {
        continue
      }
      let wanted = match name {
        "if-branch" => token.text == "if"
        "match-arm" => token.text == "match"
        _ => ["for", "while", "loop"].contains(token.text)
      }
      if !wanted {
        continue
      }
      for group in tree.groups {
        if group.kind != "{" ||
          group.start < token.end ||
          !executable_group(tree, group) {
          continue
        }
        // A following sibling/body group must still belong to the same statement.
        if name == "match-arm" || name == "loop-body" {
          let mode = if name == "match-arm" { "comma" } else { "statements" }
          for node in @moon_syntax.segments(tree, group, mode) {
            edits.push((node.start, node.end, ""))
          }
        } else {
          let mut end = group.end
          let mut alternative : @moon_syntax.Group? = None
          let following = tree.tokens.filter(t => {
            t.start >= group.end &&
            !["space", "doc", "line-comment", "block-comment"].contains(t.kind)
          })
          if !following.is_empty() && following[0].text == "else" {
            for other in tree.groups {
              if other.kind == "{" &&
                other.depth == group.depth &&
                other.start > group.end {
                alternative = Some(other)
                end = other.end
                break
              }
            }
          }
          edits.push(
            (
              token.start,
              end,
              byte_text(bytes, group.inner_start, group.inner_end),
            ),
          )
          if alternative is Some(other) {
            edits.push(
              (
                token.start,
                end,
                byte_text(bytes, other.inner_start, other.inner_end),
              ),
            )
          }
        }
        break
      }
    }
  }
  if name == "expression" {
    for token in tree.tokens {
      if ["number", "string", "char"].contains(token.kind) {
        for replacement in ["()", "true", "false", "0", "\"\""] {
          edits.push((token.start, token.end, replacement))
        }
      }
    }
    for group in tree.groups {
      if group.kind == "(" && executable_group(tree, group) {
        for replacement in ["()", "0", "true", "false", "\"\""] {
          edits.push((group.start, group.end, replacement))
        }
      }
    }
  }
  edits
}
