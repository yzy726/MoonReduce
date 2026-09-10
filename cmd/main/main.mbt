///|
extern "C" fn exit_process(code : Int) -> Unit = "exit"

///|
async fn main {
  let code = @app.run(@env.args()[1:].to_owned()) catch {
    e => {
      @stdio.stderr.write("MR_EXEC_FAILURE: " + e.to_string() + "\n")
      6
    }
  }
  if code != 0 {
    exit_process(code)
  }
}
