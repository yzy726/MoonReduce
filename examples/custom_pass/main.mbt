///|
struct Marker {}

///|
impl @reduce.CandidateEvaluator for Marker with fn evaluate(_, snapshot) {
  Ok(
    if snapshot
      .files()
      .iter()
      .any(f => @source.decode(f.1).unwrap_or("").contains("KEEP")) {
      Interesting
    } else {
      Uninteresting
    },
  )
}

///|
struct Prefix {}

///|
impl @pass_api.ReductionPass for Prefix with fn name(_) {
  "custom:prefix-v1"
}

///|
impl @pass_api.ReductionPass for Prefix with fn propose(_, snapshot, _) {
  match snapshot.replace("repro.mbt", b"KEEP") {
    Ok(s) => [s].iter()
    Err(_) => [].iter()
  }
}

///|
struct Events {
  finals : Ref[Int]
}

///|
impl @reduce.EventSink for Events with fn emit(self, event) {
  if event.phase == "final" {
    self.finals.val += 1
  }
}

///|
fn main {
  let snapshot = @manifest.Snapshot::new([("repro.mbt", b"noise KEEP")]).unwrap()
  let config = {
    ..@reduce.default_config(),
    extra_passes: [Prefix::{  }],
    pass_include: ["custom:prefix-v1"],
  }
  let finals = Ref(0)
  match
    @reduce.reduce(snapshot, Marker::{  }, config~, sink=Events::{ finals, }) {
    Err(error) => println(error)
    Ok(result) => {
      println(@source.decode(result.best.files()[0].1).unwrap())
      println("Final observations: " + finals.val.to_string())
    }
  }
}
