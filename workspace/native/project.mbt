///|
/// Prepare a project using the first regular source as the legacy anchor. All
/// entries are validated before reserving output; the original API is unchanged.
pub async fn prepare_project(
  input : String,
  output : String,
  ignored : Array[String],
) -> Workspace {
  let entries : Array[Entry] = []
  collect(portable(@fs.realpath(input)), "", ignored, entries, Ref(0))
  match @manifest.Snapshot::new(entries.map(e => (e.path, e.bytes))) {
    Err(e) => raise WorkspaceError(e)
    Ok(_) => ()
  }
  let anchor = match entries.iter().find_first(e => e.path.has_suffix(".mbt")) {
    Some(e) => e.path
    None =>
      raise WorkspaceError("MR_INPUT_TARGET: project has no regular mbt source")
  }
  prepare(input, anchor, output, ignored)
}

///|
/// Immutable project contents captured by this workspace.
pub fn Workspace::snapshot(
  self : Workspace,
) -> @manifest.Snapshot raise WorkspaceError {
  match @manifest.Snapshot::new(self.entries.map(e => (e.path, e.bytes))) {
    Ok(s) => s
    Err(e) => raise WorkspaceError(e)
  }
}

///|
async fn Workspace::write_snapshot(
  self : Workspace,
  dir : String,
  snapshot : @manifest.Snapshot,
) -> Unit {
  let files = snapshot.files()
  // Candidates may remove or replace existing entries, never inject new paths.
  for file in files {
    if !self.entries.iter().any(e => e.path == file.0) {
      raise WorkspaceError(
        "MR_INPUT_PATH: candidate introduced an unknown file",
      )
    }
  }
  for file in files {
    for entry in self.entries {
      if entry.path == file.0 {
        write_entry(dir, entry, file.1)
        break
      }
    }
  }
}

///|
/// Materialize a complete candidate in a uniquely owned directory, preserving
/// executable metadata from the original. No candidate shares mutable files.
pub async fn Workspace::materialize_snapshot(
  self : Workspace,
  snapshot : @manifest.Snapshot,
) -> String {
  self.sequence += 1
  let dir = self.output + "/.moonreduce/work/run-" + self.sequence.to_string()
  @fs.mkdir(dir)
  @fs.write_file(
    dir + "/.moonreduce-owner",
    "MoonReduce-v1",
    create_mode=CreateNew,
  )
  self.owned[dir] = true
  self.write_snapshot(dir, snapshot)
  dir
}

///|
/// Export exactly the selected project contents to a new reduced directory.
pub async fn Workspace::export_snapshot(
  self : Workspace,
  snapshot : @manifest.Snapshot,
) -> Unit {
  let dir = self.output + "/reduced"
  @fs.mkdir(dir)
  self.write_snapshot(dir, snapshot)
}
