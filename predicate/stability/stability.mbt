///|
pub(all) enum Decision {
  Interesting
  Uninteresting
  Unresolved
} derive(Debug, Eq, ToJson)

///|
/// Validated fixed-size evidence policy; None means an unresolved execution.
pub struct Policy {
  repeat : Int
  quorum : Int
  consecutive : Bool
}

///|
/// Bound evaluation cost and reject impossible quorum settings.
pub fn Policy::new(
  repeat : Int,
  quorum : Int,
  consecutive? : Bool = false,
) -> Result[Policy, String] {
  if repeat < 1 || repeat > 100 || quorum < 1 || quorum > repeat {
    Err("MR_CFG_STABILITY: require 1 <= quorum <= repeat <= 100")
  } else {
    Ok({ repeat, quorum, consecutive })
  }
}

///|
/// Decide only complete batches. Unknown outcomes pass only when success is
/// already certain, fail only when success is impossible, otherwise unresolved.
pub fn Policy::decide(self : Policy, observations : Array[Bool?]) -> Decision {
  if observations.length() != self.repeat {
    return Unresolved
  }
  let mut certain = 0
  let mut possible = 0
  let mut best_certain = 0
  let mut best_possible = 0
  for observation in observations {
    match observation {
      Some(true) => {
        certain += 1
        possible += 1
      }
      Some(false) =>
        if self.consecutive {
          certain = 0
          possible = 0
        }
      None => {
        possible += 1
        if self.consecutive {
          certain = 0
        }
      }
    }
    best_certain = best_certain.max(certain)
    best_possible = best_possible.max(possible)
  }
  if best_certain >= self.quorum {
    Interesting
  } else if best_possible < self.quorum {
    Uninteresting
  } else {
    Unresolved
  }
}

///|
pub(all) struct Statistics {
  attempts : Int
  resolved : Int
  passed : Int
  rate : Double
  lower : Double
  upper : Double
} derive(Debug, ToJson)

///|
/// Observed success rate and two-sided 95% Wilson interval among resolved runs.
/// Unresolved counts remain explicit; an empty sample has interval [0, 1].
pub fn summarize(observations : Array[Bool?]) -> Statistics {
  let mut resolved = 0
  let mut passed = 0
  for observation in observations {
    if observation is Some(value) {
      resolved += 1
      if value {
        passed += 1
      }
    }
  }
  if resolved == 0 {
    return {
      attempts: observations.length(),
      resolved,
      passed,
      rate: 0.0,
      lower: 0.0,
      upper: 1.0,
    }
  }
  let n = resolved.to_double()
  let rate = passed.to_double() / n
  let z = 1.959963984540054
  let denominator = 1.0 + z * z / n
  let center = (rate + z * z / (2.0 * n)) / denominator
  let radius = z *
    (rate * (1.0 - rate) / n + z * z / (4.0 * n * n)).sqrt() /
    denominator
  {
    attempts: observations.length(),
    resolved,
    passed,
    rate,
    lower: (center - radius).max(0.0),
    upper: (center + radius).min(1.0),
  }
}
