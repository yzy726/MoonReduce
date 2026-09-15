///|
/// Deterministic project metrics. Tokens, nonblank lines and lightweight nodes
/// count MoonBit sources; bytes/files include all copied support content.
pub(all) struct Score {
  bytes : Int
  tokens : Int
  lines : Int
  files : Int
  nodes : Int
  paths : String
} derive(Debug, Eq, ToJson)

///|
pub fn measure(snapshot : @manifest.Snapshot) -> Score {
  let files = snapshot.files()
  let mut bytes = 0
  let mut tokens = 0
  let mut lines = 0
  let mut nodes = 0
  for file in files {
    bytes += file.1.length()
    if file.0.has_suffix(".mbt") {
      let text = match @source.decode(file.1) {
        Ok(s) => s
        Err(_) => ""
      }
      tokens += @token.significant(text).length()
      lines += text.split("\n").filter(line => !line.trim().is_empty()).count()
      let tree = @moon_syntax.scan(text)
      nodes += tree.groups.length() + @moon_syntax.declarations(tree).length()
    }
  }
  {
    bytes,
    tokens,
    lines,
    files: files.length(),
    nodes,
    paths: files.map(f => f.0).join("\u0000"),
  }
}

///|
/// Compare lexicographically, returning -1/0/1. The selected primary metric is
/// followed by the remaining default metrics and stable lexical path order.
pub fn compare(strategy : String, a : Score, b : Score) -> Result[Int, String] {
  let keys = match strategy {
    "bytes" => [(a.bytes, b.bytes), (a.tokens, b.tokens), (a.lines, b.lines)]
    "tokens" => [(a.tokens, b.tokens), (a.bytes, b.bytes), (a.lines, b.lines)]
    "lines" => [(a.lines, b.lines), (a.bytes, b.bytes), (a.tokens, b.tokens)]
    _ => return Err("MR_CFG_SCORE: expected bytes, tokens or lines")
  }
  keys.append([(a.files, b.files), (a.nodes, b.nodes)])
  for key in keys {
    if key.0 < key.1 {
      return Ok(-1)
    }
    if key.0 > key.1 {
      return Ok(1)
    }
  }
  for i in 0..<a.paths.length().min(b.paths.length()) {
    if a.paths[i] < b.paths[i] {
      return Ok(-1)
    }
    if a.paths[i] > b.paths[i] {
      return Ok(1)
    }
  }
  Ok(
    if a.paths.length() < b.paths.length() {
      -1
    } else if a.paths.length() > b.paths.length() {
      1
    } else {
      0
    },
  )
}
