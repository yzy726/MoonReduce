///|
fn evidence_files() -> Array[String] {
  [
    "checkpoint.json", "environment.json", "events.ndjson", "original-summary.json",
    "reduction.diff", "report.json", "report.md", "reproduce.txt",
  ]
}

///|
async fn read_bounded(path : String, limit : Int) -> Bytes {
  if @fs.kind(path, follow_symlink=false) != Regular {
    raise ProjectError("MR_EVIDENCE_PATH: expected regular file")
  }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  if size < 0L || size > limit.to_int64() {
    raise ProjectError("MR_EVIDENCE_SIZE: artifact exceeds limit")
  }
  file.read_exactly_at(size.to_int(), position=0L)
}

///|
async fn collect_evidence(
  root : String,
  relative : String,
  paths : Array[String],
) -> Unit {
  if @fs.kind(root + "/" + relative, follow_symlink=false) != Directory {
    raise ProjectError("MR_EVIDENCE_PATH: expected ordinary directory")
  }
  for name in @fs.readdir(root + "/" + relative, include_hidden=true, sort=true) {
    let path = relative + "/" + name
    if @source.validate_path(path) is Err(_) {
      raise ProjectError("MR_EVIDENCE_PATH: invalid relative path")
    }
    match @fs.kind(root + "/" + path, follow_symlink=false) {
      Directory => collect_evidence(root, path, paths)
      Regular => {
        if paths.length() >= 1010 {
          raise ProjectError("MR_EVIDENCE_SIZE: too many files")
        }
        paths.push(path)
      }
      _ =>
        raise ProjectError("MR_EVIDENCE_PATH: links and special files rejected")
    }
  }
}

///|
async fn seal_bundle(
  output : String,
  c : @config.Config,
  toolchain : String,
) -> Unit {
  let names = c.predicate.environment.keys().to_array()
  names.sort()
  let environment : Json = {
    "schema_version": 1,
    "moonreduce_version": "0.1.0",
    "toolchain": toolchain,
    "environment_override_names": names.to_json(),
    "environment_values_recorded": false,
    "inherits_parent_environment": true,
    "hash_algorithm": "sha256",
  }
  save(output + "/environment.json", environment.stringify(indent=2))
  let paths = evidence_files()
  if @fs.exists(output + "/error.txt") {
    paths.push("error.txt")
  }
  collect_evidence(output, "reduced", paths)
  paths.sort()
  let lines = StringBuilder()
  for path in paths {
    let bytes = read_bounded(output + "/" + path, 268435456)
    lines.write_string(@sha256.digest(bytes) + "  " + path + "\n")
  }
  save(output + "/checksums.txt", lines.to_string())
}

///|
/// Verify SHA-256, complete reduced-file inventory and ordinary file kinds before
/// replay. This detects corruption; it does not authenticate an untrusted bundle.
pub async fn verify_bundle(directory : String) -> Unit {
  let root = @fs.realpath(directory)
  let encoded = read_bounded(root + "/checksums.txt", 1048576)
  let text = match @source.decode(encoded) {
    Ok(s) => s
    Err(e) => raise ProjectError(e)
  }
  let expected = evidence_files()
  if @fs.exists(root + "/error.txt") {
    expected.push("error.txt")
  }
  collect_evidence(root, "reduced", expected)
  expected.sort()
  let seen : Array[String] = []
  let mut total = 0L
  for line in text.split("\n") {
    if line.is_empty() {
      continue
    }
    let (hash, path) = match line.split_once("  ") {
      Some((hash, path)) => (hash.to_owned(), path.to_owned())
      None => raise ProjectError("MR_EVIDENCE_FORMAT: invalid checksum line")
    }
    if hash.length() != 64 ||
      !hash.iter().all(c => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) ||
      !expected.contains(path) ||
      seen.contains(path) {
      raise ProjectError("MR_EVIDENCE_FORMAT: invalid or duplicate entry")
    }
    let limit = if path.has_prefix("reduced/") { 1048576 } else { 268435456 }
    let bytes = read_bounded(root + "/" + path, limit)
    total += bytes.length().to_int64()
    if total > 536870912L {
      raise ProjectError("MR_EVIDENCE_SIZE: bundle exceeds 512 MiB")
    }
    if @sha256.digest(bytes) != hash {
      raise ProjectError("MR_EVIDENCE_CHECKSUM: content mismatch for " + path)
    }
    seen.push(path)
  }
  seen.sort()
  if seen != expected {
    raise ProjectError("MR_EVIDENCE_FORMAT: incomplete file inventory")
  }
}
