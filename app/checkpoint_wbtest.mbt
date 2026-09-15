///|
async test "checkpoint atomic replacement leaves no partial file" {
  let root = @fs.tmpdir(prefix="moonreduce-atomic-")
  let path = root + "/checkpoint.json"
  save_checkpoint(path, { "step": 1, "large": "old content" })
  save_checkpoint(path, { "step": 2 })
  assert_eq(@json.parse(@fs.read_file(path).text()), { "step": 2 })
  assert_true(!@fs.exists(path + ".tmp"))
}

///|
async test "checkpoint occupied temporary path preserves both files" {
  let root = @fs.tmpdir(prefix="moonreduce-atomic-refuse-")
  let path = root + "/checkpoint.json"
  save_checkpoint(path, { "step": 1 })
  @fs.write_file(path + ".tmp", "not ours", create_mode=CreateNew)
  let failed = try {
    save_checkpoint(path, { "step": 2 })
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  assert_eq(@json.parse(@fs.read_file(path).text()), { "step": 1 })
  assert_eq(@fs.read_file(path + ".tmp").text(), "not ours")
}
