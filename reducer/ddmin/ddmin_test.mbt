///|
test "property/partitions disjoint complete and deterministic" {
  for n in 0..<65 {
    for groups in 1..<17 {
      let ps = @ddmin.partitions(n, groups)
      let mut last = 0
      for p in ps {
        assert_eq(p.0, last)
        assert_true(p.1 > p.0)
        last = p.1
      }
      assert_eq(last, n)
      assert_eq(ps, @ddmin.partitions(n, groups))
    }
  }
}

///|
test "edge/invalid groups produce no partitions" {
  assert_eq(@ddmin.partitions(4, 0), [])
  assert_eq(@ddmin.partitions(-1, 2), [])
  assert_eq(@ddmin.partitions(1, 99), [(0, 1)])
}
