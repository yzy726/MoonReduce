///|
/// Bounded local test helper. Never launches a shell; every branch expires in 10s.
async fn main {
  let args = @env.args()
  guard args.length() == 3 else { return }
  if args[1] == "parent" {
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
