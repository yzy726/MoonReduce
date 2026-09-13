///|
/// Stop without discarding the last accepted source; no final success is implied.
pub fn Session::stop(self : Session, status : @model.RunStatus) -> Unit {
  self.status = status
  self.phase = 3
  self.pending = None
}

///|
/// Cooperative cancellation, usable by an IO adapter or deterministic tests.
pub fn Session::cancel(self : Session) -> Unit {
  self.stop(Cancelled)
}

///|
/// Supply elapsed milliseconds from the driver. A hard wall budget never overruns
/// merely to obtain final evidence; such results have final_passed less than three.
pub fn Session::elapsed(self : Session, elapsed_ms : Int64) -> Unit {
  if self.phase != 3 && elapsed_ms >= self.budget.max_time_ms {
    self.stop(BudgetExhausted)
  }
}
