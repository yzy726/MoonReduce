extern "C" fn exit_code(x : Int)  = "exit"
fn main { println("MR_TARGET_EXIT"); exit_code(1) }
