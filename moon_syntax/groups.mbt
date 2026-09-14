///|
/// Half-open UTF8 byte range of a balanced delimiter group.
pub(all) struct Group {
  kind : String
  start : Int
  end : Int
  inner_start : Int
  inner_end : Int
  depth : Int
} derive(Debug, Eq, ToJson)

///|
/// Lossless lexical token with UTF8 byte offsets, independent of String indices.
pub(all) struct Token {
  kind : String
  text : String
  start : Int
  end : Int
} derive(Debug, Eq, ToJson)

///|
/// Partial reduction structure. Diagnostics require conservative token fallback;
/// this is not a complete compiler syntax tree.
pub(all) struct ReductionTree {
  tokens : Array[Token]
  groups : Array[Group]
  diagnostics : Array[String]
} derive(Debug, Eq, ToJson)

///|
fn terminated(t : @token.Token) -> Bool {
  if t.kind == "string" || t.kind == "char" {
    if t.text.length() < 2 || t.text[0] != t.text[t.text.length() - 1] {
      return false
    }
    let mut slash = 0
    let mut i = t.text.length() - 2
    while i >= 0 && t.text[i] == 92 {
      slash += 1
      i -= 1
    }
    return slash % 2 == 0
  }
  if t.kind == "block-comment" {
    let mut depth = 0
    let mut i = 0
    while i + 1 < t.text.length() {
      if t.text[i] == 47 && t.text[i + 1] == 42 {
        depth += 1
        i += 2
      } else if t.text[i] == 42 && t.text[i + 1] == 47 {
        depth -= 1
        i += 2
      } else {
        i += 1
      }
    }
    return depth == 0
  }
  true
}

///|
/// Scan a bounded source, keeping strings/comments opaque to bracket matching.
/// Completed groups survive an incomplete suffix; malformed groups are omitted.
/// Offsets count UTF8 bytes, including BOM and CRLF, rather than UTF16 units.
pub fn scan(source : String) -> ReductionTree {
  let tokens : Array[Token] = []
  let groups : Array[Group] = []
  let diagnostics : Array[String] = []
  if source.length() > 65536 || @source.encode(source).length() > 65536 {
    return {
      tokens,
      groups,
      diagnostics: ["MR_SYNTAX_LIMIT: source exceeds 64 KiB"],
    }
  }
  let offsets = Array::make(source.length() + 1, 0)
  let mut units = 0
  let mut bytes = 0
  for c in source.iter() {
    let s = c.to_string()
    offsets[units] = bytes
    units += s.length()
    bytes += @source.encode(s).length()
    offsets[units] = bytes
  }
  let stack : Array[(Token, Int)] = []
  for t in @token.scan(source) {
    let token = Token::{
      kind: t.kind,
      text: t.text,
      start: offsets[t.start],
      end: offsets[t.end],
    }
    tokens.push(token)
    if !terminated(t) {
      diagnostics.push("MR_SYNTAX_INCOMPLETE: unterminated " + t.kind)
    }
    if t.kind != "punct" {
      continue
    }
    if ["(", "[", "{"].contains(t.text) {
      stack.push((token, stack.length()))
    } else if [")", "]", "}"].contains(t.text) {
      match stack.pop() {
        None => diagnostics.push("MR_SYNTAX_UNBALANCED: unexpected closer")
        Some((open, depth)) => {
          let expected = match open.text {
            "(" => ")"
            "[" => "]"
            _ => "}"
          }
          if token.text != expected {
            diagnostics.push("MR_SYNTAX_UNBALANCED: mismatched closer")
            stack.clear()
          } else {
            groups.push({
              kind: open.text,
              start: open.start,
              end: token.end,
              inner_start: open.end,
              inner_end: token.start,
              depth,
            })
          }
        }
      }
    }
  }
  if !stack.is_empty() {
    diagnostics.push("MR_SYNTAX_UNBALANCED: missing closer")
  }
  groups.sort_by((a, b) => a.start - b.start)
  { tokens, groups, diagnostics }
}
