///|
/// An original regular file, kept in memory so every evaluation starts pristine.
priv struct Entry {
  path : String
  bytes : Bytes
  executable : Bool
} derive(Eq)

///|
/// Isolated immutable input manifest and explicit output root.
pub struct Workspace {
  root : String
  output : String
  target : String
  original : String
  priv entries : Array[Entry]
  ignored : Array[String]
  mut sequence : Int
}

///|
/// Stable native workspace failures, surfaced by the CLI as MR_INPUT/MR_OUTPUT.
pub suberror WorkspaceError {
  WorkspaceError(String)
} derive(Debug)

///|
fn portable(s : String) -> String {
  s.replace_all(old="\\", new="/")
}

///|
fn inside(path : String, root : String) -> Bool {
  let p = portable(path).to_lower()
  let r = portable(root).to_lower()
  p == r || p.has_prefix(r + "/")
}

///|
async fn collect(
  root : String,
  relative : String,
  ignored : Array[String],
  entries : Array[Entry],
  total : Ref[Int],
) -> Unit {
  let dir = if relative == "" { root } else { root + "/" + relative }
  for name in @fs.readdir(dir, include_hidden=true, sort=true) {
    if [".git", "_build", ".mooncakes", ".moonreduce"].contains(name) {
      continue
    }
    let rel = if relative == "" { name } else { relative + "/" + name }
    if ignored.contains(rel) {
      continue
    }
    match @source.validate_path(rel) {
      Err(e) => raise WorkspaceError(e)
      _ => ()
    }
    let path = root + "/" + rel
    match @fs.kind(path, follow_symlink=false) {
      Directory => collect(root, rel, ignored, entries, total)
      Regular => {
        if entries.length() >= 1000 {
          raise WorkspaceError("MR_INPUT_LIMIT: more than 1000 files")
        }
        let file = @fs.open(path, mode=@fs.ReadOnly)
        defer file.close()
        let size = file.size()
        if size > 1048576L || size < 0L {
          raise WorkspaceError("MR_INPUT_LIMIT: file exceeds 1 MiB")
        }
        let bytes = file.read_exactly(size.to_int())
        total.val += bytes.length()
        if total.val > 16777216 {
          raise WorkspaceError("MR_INPUT_LIMIT: project exceeds 16 MiB")
        }
        entries.push({ path: rel, bytes, executable: @fs.can_execute(path) })
      }
      SymLink => ()
      _ =>
        raise WorkspaceError(
          "MR_INPUT_KIND: only regular files and directories are supported",
        )
    }
  }
}

///|
async fn write_entry(root : String, entry : Entry, bytes : Bytes) -> Unit {
  let path = root + "/" + entry.path
  if entry.path.rev_split_once("/") is Some((parent, _)) {
    @fs.mkdir(root + "/" + parent.to_owned(), recursive=true)
  }
  @fs.write_file(
    path,
    bytes,
    create_mode=@fs.CreateNew,
    permission=if entry.executable { 0o755 } else { 0o644 },
  )
}

///|
/// Snapshot a trusted project and reserve a new output directory. Output must be
/// outside the source tree, making unchanged-input verification unambiguous.
pub async fn prepare(
  input : String,
  target : String,
  output : String,
  ignored : Array[String],
) -> Workspace {
  let target = match @source.validate_path(target) {
    Ok(p) => p
    Err(e) => raise WorkspaceError(e)
  }
  let root = portable(@fs.realpath(input))
  let out = portable(output)
  let (parent, leaf) = match out.rev_split_once("/") {
    Some((p, f)) =>
      (if p.is_empty() { "/" } else { p.to_owned() }, f.to_owned())
    None => (".", out)
  }
  match @source.validate_path(leaf) {
    Err(e) => raise WorkspaceError(e)
    _ => ()
  }
  let output = portable(@fs.realpath(parent)) + "/" + leaf
  if inside(output, root) || @fs.exists(output) {
    raise WorkspaceError(
      "MR_OUTPUT_PATH: choose a new directory outside the workspace",
    )
  }
  let entries = []
  collect(root, "", ignored, entries, Ref(0))
  let bytes = match entries.iter().find_first(e => e.path == target) {
    Some(e) => e.bytes
    None =>
      raise WorkspaceError(
        "MR_INPUT_TARGET: missing, ignored or symlink target",
      )
  }
  if bytes.length() > 65536 {
    raise WorkspaceError("MR_INPUT_LIMIT: target exceeds 64 KiB")
  }
  let original = match @source.decode(bytes) {
    Ok(s) => s
    Err(e) => raise WorkspaceError(e)
  }
  @fs.mkdir(output)
  @fs.mkdir(output + "/.moonreduce/work", recursive=true)
  {
    root,
    output,
    target,
    original,
    entries,
    ignored: ignored.copy(),
    sequence: 0,
  }
}

///|
/// Materialize a fresh project for each attempt, isolating compiler build artifacts.
pub async fn Workspace::materialize(
  self : Workspace,
  candidate : String,
) -> String {
  self.sequence += 1
  let dir = self.output + "/.moonreduce/work/run-" + self.sequence.to_string()
  @fs.mkdir(dir)
  @fs.write_file(
    dir + "/.moonreduce-owner",
    "MoonReduce-v1",
    create_mode=@fs.CreateNew,
  )
  for entry in self.entries {
    let bytes = if entry.path == self.target {
      @source.encode(candidate)
    } else {
      entry.bytes
    }
    write_entry(dir, entry, bytes)
  }
  dir
}

///|
/// Export pristine support files and the selected target, never compiler side effects.
pub async fn Workspace::export_best(self : Workspace, best : String) -> Unit {
  let dir = self.output + "/reduced"
  @fs.mkdir(dir)
  for entry in self.entries {
    write_entry(
      dir,
      entry,
      if entry.path == self.target {
        @source.encode(best)
      } else {
        entry.bytes
      },
    )
  }
}

///|
/// Re-read the included original manifest to detect edits, additions or removals.
pub async fn Workspace::original_unchanged(self : Workspace) -> Bool {
  let current = []
  collect(self.root, "", self.ignored, current, Ref(0))
  current == self.entries
}

///|
/// Validate cwd against the freshly materialized copy, including realpath confinement.
pub async fn Workspace::working_directory(
  self : Workspace,
  dir : String,
  cwd : String,
) -> String {
  if !inside(dir, self.output + "/.moonreduce/work") {
    raise WorkspaceError("MR_INPUT_CWD: unknown evaluation directory")
  }
  if cwd != "." {
    match @source.validate_path(cwd) {
      Err(e) => raise WorkspaceError(e)
      _ => ()
    }
  }
  let path = portable(@fs.realpath(dir + "/" + cwd))
  if !inside(path, dir) {
    raise WorkspaceError("MR_INPUT_CWD: directory escapes evaluation copy")
  }
  path
}
