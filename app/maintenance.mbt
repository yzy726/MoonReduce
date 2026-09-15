///|
async fn maintenance(argv : Array[String]) -> String {
  if argv.get(0) == Some("config") {
    if argv.length() != 3 || argv[1] != "validate" {
      raise ProjectError("MR_CFG_VALIDATE: config validate FILE")
    }
    let document = artifact_json(argv[2])
    match @config.parse(["check"], Some(document)) {
      Err(e) => raise ProjectError(e)
      Ok(_) => return "Configuration valid (schema 1)\n"
    }
  }
  if argv.get(0) == Some("diff") {
    if argv.length() != 2 {
      raise ProjectError("MR_CFG_DIFF: diff report.json")
    }
    let path = @fs.realpath(argv[1]).replace_all(old="\\", new="/")
    let root = match path.rev_split_once("/") {
      Some((parent, "report.json")) => parent.to_owned()
      _ => raise ProjectError("MR_CFG_DIFF: expected report.json")
    }
    verify_bundle(root)
    return match
      @source.decode(read_bounded(root + "/reduction.diff", 67108864)) {
      Ok(s) => s
      Err(e) => raise ProjectError(e)
    }
  }
  if argv.get(0) != Some("cache") ||
    ![Some("stats"), Some("clean")].contains(argv.get(1)) {
    raise ProjectError("MR_CFG_CACHE: cache stats|clean [--run DIRECTORY]")
  }
  let clean = argv[1] == "clean"
  let root = if argv.length() == 4 && argv[2] == "--run" {
    @fs.realpath(argv[3])
  } else if argv.length() == 2 && !clean {
    @fs.realpath(".")
  } else {
    raise ProjectError("MR_CFG_CACHE: clean requires --run DIRECTORY")
  }
  verify_bundle(root)
  let document = artifact_json(root + "/checkpoint.json")
  let (envelope, engine, entries) = match document {
    Object(envelope) =>
      match envelope.get("engine") {
        Some(Object(engine)) =>
          match
            (
              envelope.get("schema_version"),
              engine.get("schema_version"),
              engine.get("cache"),
            ) {
            (Some(1), Some(4), Some(Array(entries))) =>
              (envelope, engine, entries)
            _ =>
              raise ProjectError(
                "MR_CHECKPOINT_FORMAT: unsupported cache schema",
              )
          }
        _ => raise ProjectError("MR_CHECKPOINT_FORMAT: missing engine")
      }
    _ => raise ProjectError("MR_CHECKPOINT_FORMAT: missing envelope")
  }
  let count = entries.length()
  let size = @source.encode(entries.to_json().stringify()).length()
  if clean {
    let empty : Array[Json] = []
    engine["cache"] = empty.to_json()
    envelope["engine"] = engine.to_json()
    envelope["engine_sha256"] = @sha256.digest(
      @source.encode(engine.to_json().stringify()),
    ).to_json()
    let updated = envelope.to_json()
    let checksums = match
      @source.decode(read_bounded(root + "/checksums.txt", 1048576)) {
      Ok(s) => s
      Err(e) => raise ProjectError(e)
    }
    let new_hash = @sha256.digest(@source.encode(updated.stringify()))
    let lines : Array[String] = []
    for line in checksums.split("\n") {
      if line.has_suffix("  checkpoint.json") {
        lines.push(new_hash + "  checkpoint.json")
      } else {
        lines.push(line.to_owned())
      }
    }
    @async.protect_from_cancel(resume_on_cancel=false, () => {
      save_checkpoint(root + "/checkpoint.json", updated)
      @fs.write_file(root + "/checksums.txt", lines.join("\n"), sync=Full)
    })
    verify_bundle(root)
  }
  let result : Json = {
    "schema_version": 1,
    "entries": count,
    "encoded_bytes": size,
    "cleaned": clean,
  }
  result.stringify(indent=2) + "\n"
}
