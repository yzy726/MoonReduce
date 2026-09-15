///|
test "sha256 empty standard vector" {
  assert_eq(
    @sha256.digest(b""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
}

///|
test "sha256 abc standard vector" {
  assert_eq(
    @sha256.digest(b"abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
}

///|
test "sha256 multiblock padding vector" {
  assert_eq(
    @sha256.digest(b"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
  )
}

///|
test "sha256 binary vector" {
  assert_eq(
    @sha256.digest(Bytes::from_array([0, 255, 128, 1])),
    "6509423fd9da5c225d2f8619ffae394b40f9f7686fee55a38c54b1424ac65f46",
  )
}

///|
test "sha256 independent boundary 55" {
  let bytes = Bytes::from_array(Array::makei(55, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "463eb28e72f82e0a96c0a4cc53690c571281131f672aa229e0d45ae59b598b59",
  )
}

///|
test "sha256 independent boundary 56" {
  let bytes = Bytes::from_array(Array::makei(56, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "da2ae4d6b36748f2a318f23e7ab1dfdf45acdc9d049bd80e59de82a60895f562",
  )
}

///|
test "sha256 independent boundary 63" {
  let bytes = Bytes::from_array(Array::makei(63, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488",
  )
}

///|
test "sha256 independent boundary 64" {
  let bytes = Bytes::from_array(Array::makei(64, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108",
  )
}

///|
test "sha256 independent boundary 65" {
  let bytes = Bytes::from_array(Array::makei(65, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781",
  )
}

///|
test "sha256 independent boundary 1000" {
  let bytes = Bytes::from_array(Array::makei(1000, i => (i % 256).to_byte()))
  assert_eq(
    @sha256.digest(bytes),
    "a8af099bf2e878609558dbf69d8f88f4a31040a8cf84b549a0cfa912f12ffc3f",
  )
}
