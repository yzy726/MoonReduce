///|
fn any_rule(rules : Array[String], path : String, ancestors : Bool) -> Bool {
  let mut prefix = path
  while true {
    for rule in rules {
      if @glob.matches(rule, prefix) == Ok(true) {
        return true
      }
    }
    if !ancestors {
      return false
    }
    let parts = prefix.split("/").map(x => x.to_owned()).to_array()
    if parts.length() <= 1 {
      return false
    }
    let _ = parts.pop()
    prefix = parts.join("/")
  } nobreak {
    false
  }
}

///|
fn protected_by_default(path : String) -> Bool {
  let parts = path.to_lower().split("/").map(x => x.to_owned()).to_array()
  for part in parts {
    if part == "scripts" ||
      part == ".git" ||
      part == ".github" ||
      part == ".githooks" ||
      part == "readme" ||
      part.has_prefix("readme.") ||
      part == "license" ||
      part.has_prefix("license.") {
      return true
    }
  }
  false
}

///|
/// Sorted eligible mbt paths. Empty includes means **/*.mbt. Ignore/protect
/// rules match files or ancestors and override includes. Documentation, script
/// directories and Git metadata remain protected. This only selects mutation
/// targets; it never removes ignored or protected support files from a snapshot.
/// Invalid rules fail even when there are no files. At most 128 rules total.
pub fn select(
  snapshot : Snapshot,
  includes : Array[String],
  protects : Array[String],
  ignores : Array[String],
) -> Result[Array[String], String] {
  if includes.length() + protects.length() + ignores.length() > 128 {
    return Err("MR_GLOB_LIMIT: too many selection rules")
  }
  for rules in [includes, protects, ignores] {
    for rule in rules {
      match @glob.matches(rule, "validation.mbt") {
        Err(e) => return Err(e)
        Ok(_) => ()
      }
    }
  }
  let includes = if includes.is_empty() { ["**/*.mbt"] } else { includes }
  let selected : Array[String] = []
  for entry in snapshot.entries {
    let path = entry.0
    if path.has_suffix(".mbt") &&
      !protected_by_default(path) &&
      any_rule(includes, path, false) &&
      !any_rule(protects, path, true) &&
      !any_rule(ignores, path, true) {
      selected.push(path)
    }
  }
  Ok(selected)
}

///|
/// Select manifest metadata for package deletion or explicitly enabled edits.
/// Root metadata is eligible only when include_root is true. Includes and all
/// default/user protection rules apply before any path becomes mutable.
pub fn select_manifests(
  snapshot : Snapshot,
  includes : Array[String],
  protects : Array[String],
  ignores : Array[String],
  include_root~ : Bool,
) -> Result[Array[String], String] {
  match select(snapshot, includes, protects, ignores) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  let result : Array[String] = []
  for entry in snapshot.entries {
    let path = entry.0
    let supported = path.has_suffix("/moon.pkg") ||
      (include_root && (path == "moon.pkg" || path == "moon.mod"))
    if supported &&
      !protected_by_default(path) &&
      (includes.is_empty() || any_rule(includes, path, false)) &&
      !any_rule(protects, path, true) &&
      !any_rule(ignores, path, true) {
      result.push(path)
    }
  }
  Ok(result)
}
