///|
/// Bounded local test helper. Never launches a shell; every branch expires in 10s.
async fn main {
  let args = @env.args()
  guard args.length() == 3 else { return }
  if args[1] == "flaky" {
    let state = match @env.get_env_var("MR_FLAKY_STATE") {
      Some(s) => s
      None => return
    }
    let previous = @fs.read_file(state).text()
    guard previous.length() < 100000 else { return }
    @fs.write_file(state, previous + "x")
    if previous.length() % 5 != 4 &&
      @fs.read_file(args[2]).text().contains("KEEP") {
      println("KEEP")
    }
    return
  }
  if args[1] == "contains" || args[1] == "consume" || args[1] == "fingerprint" {
    if @fs.read_file(args[2]).text().contains("KEEP") {
      println("KEEP")
      if args[1] == "fingerprint" {
        println("Error: [E1234] test \"case\" failed")
      }
      if args[1] == "consume" {
        @fs.write_file(args[2], "")
      }
    }
  } else if args[1] == "wrapper" {
    if @fs.read_file(args[2]).text().contains("KEEP") {
      println("{\"schema_version\":1,\"interesting\":true}")
    } else {
      println("{\"schema_version\":1,\"interesting\":false}")
    }
  } else if args[1] == "parent" {
    ignore(
      @child.spawn_orphan(
        args[0],
        ["heartbeat", args[2]],
        no_console_window=true,
      ),
    )
    @async.sleep(10000)
  } else if args[1] == "heartbeat" {
    for i in 0..<100 {
      @fs.write_file(args[2], i.to_string(), create_mode=CreateOrTruncate)
      @async.sleep(100)
    }
  }
}
