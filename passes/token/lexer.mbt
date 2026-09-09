///|
/// Lossless UTF-16 span in the original MoonBit String; never a byte offset.
pub(all) struct Token {
  start : Int
  end : Int
  kind : String
  text : String
} derive(Debug, Eq, ToJson)

///|
fn digit(c : UInt16) -> Bool {
  c >= 48 && c <= 57
}

///|
fn word(c : UInt16) -> Bool {
  (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c >= 128
}

///|
fn space(c : UInt16) -> Bool {
  c == 32 || c == 9 || c == 13 || c == 10
}

///|
/// Lossless tolerant scanner. Strings, character literals, nested block comments
/// and MoonBit multiline string lines are opaque to delimiter matching.
pub fn scan(s : String) -> Array[Token] {
  let tokens : Array[Token] = []
  let mut i = 0
  while i < s.length() {
    let start = i
    let c = s[i]
    let mut kind = "punct"
    if space(c) {
      kind = "space"
      i += 1
      while i < s.length() && space(s[i]) {
        i += 1
      }
    } else if c == 47 && i + 1 < s.length() && s[i + 1] == 47 {
      kind = if i + 2 < s.length() && s[i + 2] == 47 {
        "doc"
      } else {
        "line-comment"
      }
      i += 2
      while i < s.length() && s[i] != 10 {
        i += 1
      }
    } else if c == 47 && i + 1 < s.length() && s[i + 1] == 42 {
      kind = "block-comment"
      i += 2
      let mut depth = 1
      while i < s.length() && depth > 0 {
        if i + 1 < s.length() && s[i] == 47 && s[i + 1] == 42 {
          depth += 1
          i += 2
        } else if i + 1 < s.length() && s[i] == 42 && s[i + 1] == 47 {
          depth -= 1
          i += 2
        } else {
          i += 1
        }
      }
    } else if c == 34 || c == 39 {
      kind = if c == 34 { "string" } else { "char" }
      i += 1
      while i < s.length() {
        if s[i] == 92 {
          i = (i + 2).min(s.length())
        } else if s[i] == c {
          i += 1
          break
        } else {
          i += 1
        }
      }
    } else if c == 35 &&
      i + 1 < s.length() &&
      (s[i + 1] == 124 || s[i + 1] == 33) {
      kind = "raw-string"
      i += 2
      while i < s.length() && s[i] != 10 {
        i += 1
      }
    } else if digit(c) {
      kind = "number"
      i += 1
      while i < s.length() {
        let n = s[i]
        if digit(n) || word(n) || n == 46 {
          i += 1
        } else if (n == 43 || n == 45) && (s[i - 1] == 101 || s[i - 1] == 69) {
          i += 1
        } else {
          break
        }
      }
    } else if word(c) {
      kind = "word"
      i += 1
      while i < s.length() && (word(s[i]) || digit(s[i])) {
        i += 1
      }
    } else {
      i += 1
    }
    tokens.push({ start, end: i, kind, text: s[start:i].to_owned() })
  }
  tokens
}
