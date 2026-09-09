///|
/// Balanced contiguous half-open partitions. No empty groups; multiplication
/// is avoided so a large element count cannot overflow an intermediate product.
pub fn partitions(count : Int, groups : Int) -> Array[(Int, Int)] {
  if count <= 0 || groups <= 0 {
    return []
  }
  let groups = groups.min(count)
  let base = count / groups
  let extra = count % groups
  let result = []
  let mut start = 0
  for i in 0..<groups {
    let end = start + base + (if i < extra { 1 } else { 0 })
    result.push((start, end))
    start = end
  }
  result
}
