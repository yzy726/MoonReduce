///|
async test "regr_invalid_json_file_is_configuration_error" {
  let root = @fs.tmpdir(prefix="moonreduce-config-error-")
  let path = root + "/invalid.json"
  @fs.write_file(path, "{ broken JSON", create_mode=CreateNew)
  assert_eq(@app.run(["reduce", "--config", path]), 1)
}

///|
async test "regr_missing_config_file_is_configuration_error" {
  let root = @fs.tmpdir(prefix="moonreduce-config-missing-")
  assert_eq(@app.run(["reduce", "--config", root + "/missing.json"]), 1)
}
