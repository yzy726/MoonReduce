extern "C" fn exit_code(x : Int)  = "exit"
fn main { println("MR_EXIT_TARGET"); exit_code(1) }
