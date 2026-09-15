///|
priv suberror RegexError {
  RegexError(String)
}

///|
priv struct CharSet {
  ranges : Array[(Int, Int)]
  negate : Bool
}

///|
priv enum State {
  Character(CharSet, Int)
  Fork(Int, Int)
  Jump(Int)
  Begin(Int)
  End(Int)
  Accept
}

///|
priv struct Fragment {
  start : Int
  exits : Array[(Int, Bool)]
}

///|
priv struct Parser {
  chars : Array[Char]
  mut position : Int
  states : Array[State]
  mut depth : Int
}

///|
/// Immutable Thompson automaton for a bounded portable regular-expression subset.
pub struct Regex {
  priv start : Int
  priv states : Array[State]
}

///|
fn Parser::emit(self : Parser, state : State) -> Int raise RegexError {
  if self.states.length() >= 4096 {
    raise RegexError("MR_REGEX_SIZE: too many states")
  }
  let index = self.states.length()
  self.states.push(state)
  index
}

///|
fn Parser::peek(self : Parser) -> Char? {
  self.chars.get(self.position)
}

///|
fn Parser::take(self : Parser) -> Char raise RegexError {
  match self.peek() {
    Some(c) => {
      self.position += 1
      c
    }
    None => raise RegexError("MR_REGEX_SYNTAX: unexpected end")
  }
}

///|
fn Parser::patch(self : Parser, exits : Array[(Int, Bool)], next : Int) -> Unit {
  for exit in exits {
    let (index, second) = exit
    self.states[index] = match self.states[index] {
      Character(set, _) => Character(set, next)
      Jump(_) => Jump(next)
      Begin(_) => Begin(next)
      End(_) => End(next)
      Fork(a, b) => if second { Fork(a, next) } else { Fork(next, b) }
      Accept => Accept
    }
  }
}

///|
fn Parser::single(self : Parser, state : State) -> Fragment raise RegexError {
  let start = self.emit(state)
  { start, exits: [(start, false)] }
}

///|
fn literal(c : Char) -> CharSet {
  { ranges: [(c.to_int(), c.to_int())], negate: false }
}

///|
fn Parser::escape(self : Parser) -> CharSet raise RegexError {
  let c = self.take()
  match c {
    'd' | 'D' => { ranges: [(48, 57)], negate: c == 'D' }
    'w' | 'W' =>
      { ranges: [(48, 57), (65, 90), (95, 95), (97, 122)], negate: c == 'W' }
    's' | 'S' => { ranges: [(9, 13), (32, 32)], negate: c == 'S' }
    'n' => literal('\n')
    'r' => literal('\r')
    't' => literal('\t')
    '\\'
    | '.'
    | '^'
    | '$'
    | '['
    | ']'
    | '('
    | ')'
    | '{'
    | '}'
    | '*'
    | '+'
    | '?'
    | '|'
    | '-' => literal(c)
    _ => raise RegexError("MR_REGEX_SYNTAX: unsupported escape")
  }
}

///|
fn Parser::class_atom(self : Parser) -> CharSet raise RegexError {
  let c = self.take()
  if c == '\\' {
    self.escape()
  } else {
    literal(c)
  }
}

///|
fn Parser::character_class(self : Parser) -> CharSet raise RegexError {
  let negate = self.peek() == Some('^')
  if negate {
    self.position += 1
  }
  let ranges : Array[(Int, Int)] = []
  while self.peek() != Some(']') {
    let first = self.class_atom()
    if first.negate {
      raise RegexError("MR_REGEX_SYNTAX: negated shorthand inside class")
    }
    if self.peek() == Some('-') &&
      self.chars.get(self.position + 1) != Some(']') {
      self.position += 1
      let last = self.class_atom()
      if first.ranges.length() != 1 ||
        last.ranges.length() != 1 ||
        last.negate ||
        first.ranges[0].0 != first.ranges[0].1 ||
        last.ranges[0].0 != last.ranges[0].1 ||
        first.ranges[0].0 > last.ranges[0].0 {
        raise RegexError("MR_REGEX_SYNTAX: invalid character range")
      }
      ranges.push((first.ranges[0].0, last.ranges[0].0))
    } else {
      ranges.append(first.ranges)
    }
  }
  ignore(self.take())
  if ranges.is_empty() {
    raise RegexError("MR_REGEX_SYNTAX: empty character class")
  }
  { ranges, negate }
}

///|
fn Parser::atom(self : Parser) -> Fragment raise RegexError {
  let c = self.take()
  let fragment = match c {
    '(' => {
      self.depth += 1
      if self.depth > 32 {
        raise RegexError("MR_REGEX_SIZE: nesting exceeds 32")
      }
      let fragment = self.expression()
      if self.take() != ')' {
        raise RegexError("MR_REGEX_SYNTAX: unclosed group")
      }
      self.depth -= 1
      fragment
    }
    '[' => self.single(Character(self.character_class(), -1))
    '.' => self.single(Character({ ranges: [(10, 10)], negate: true }, -1))
    '^' => self.single(Begin(-1))
    '$' => self.single(End(-1))
    '\\' => self.single(Character(self.escape(), -1))
    '*' | '+' | '?' | '{' | '}' | ')' | ']' =>
      raise RegexError("MR_REGEX_SYNTAX: unsupported or misplaced operator")
    _ => self.single(Character(literal(c), -1))
  }
  match self.peek() {
    Some('*') | Some('+') => {
      let quantifier = self.take()
      let fork = self.emit(Fork(fragment.start, -1))
      self.patch(fragment.exits, fork)
      {
        start: if quantifier == '*' {
          fork
        } else {
          fragment.start
        },
        exits: [(fork, true)],
      }
    }
    Some('?') => {
      self.position += 1
      let fork = self.emit(Fork(fragment.start, -1))
      { start: fork, exits: fragment.exits + [(fork, true)] }
    }
    _ => fragment
  }
}

///|
fn Parser::sequence(self : Parser) -> Fragment raise RegexError {
  let mut fragment = self.single(Jump(-1))
  while self.peek() is Some(c) && c != ')' && c != '|' {
    let next = self.atom()
    self.patch(fragment.exits, next.start)
    fragment = { start: fragment.start, exits: next.exits }
  }
  fragment
}

///|
fn Parser::expression(self : Parser) -> Fragment raise RegexError {
  let mut fragment = self.sequence()
  while self.peek() == Some('|') {
    self.position += 1
    let next = self.sequence()
    fragment = {
      start: self.emit(Fork(fragment.start, next.start)),
      exits: fragment.exits + next.exits,
    }
  }
  fragment
}

///|
/// Compile literals, ., ^/$, groups, alternatives, classes and */+/? operators.
/// ASCII d/w/s shorthands and their complements are supported. Backreferences,
/// lookaround, counted repeats and inline flags are explicitly rejected.
pub fn Regex::compile(pattern : String) -> Result[Regex, String] {
  if pattern.length() > 1024 {
    return Err("MR_REGEX_SIZE: pattern exceeds 1024 code units")
  }
  let parser : Parser = {
    chars: pattern.iter().to_array(),
    position: 0,
    states: [],
    depth: 0,
  }
  try {
    let fragment = parser.expression()
    if parser.position != parser.chars.length() {
      raise RegexError("MR_REGEX_SYNTAX: unexpected closing group")
    }
    parser.patch(fragment.exits, parser.emit(Accept))
    Ok({ start: fragment.start, states: parser.states })
  } catch {
    RegexError(message) => Err(message)
  }
}

///|
/// Search Unicode scalar input without backtracking. Anchors mean absolute
/// input boundaries, dot excludes LF, and budget exhaustion is an error rather
/// than a false negative. Input and work limits apply even to hostile patterns.
pub fn Regex::matches(
  self : Regex,
  text : String,
  max_steps? : Int = 20000000,
) -> Result[Bool, String] {
  if text.length() > 2097152 || max_steps < 1 || max_steps > 20000000 {
    return Err("MR_REGEX_BUDGET: input or execution limit")
  }
  let chars = text.iter().to_array()
  let mut active : Array[Int] = []
  let mut steps = 0
  for position in 0..<(chars.length() + 1) {
    steps += self.states.length()
    if steps > max_steps {
      return Err("MR_REGEX_BUDGET: execution limit")
    }
    let seen = Array::make(self.states.length(), false)
    active.push(self.start)
    let next : Array[Int] = []
    while active.pop() is Some(index) {
      if seen[index] {
        continue
      }
      seen[index] = true
      match self.states[index] {
        Accept => return Ok(true)
        Jump(target) => active.push(target)
        Fork(a, b) => {
          active.push(a)
          active.push(b)
        }
        Begin(target) => if position == 0 { active.push(target) }
        End(target) => if position == chars.length() { active.push(target) }
        Character(set, target) =>
          if chars.get(position) is Some(c) {
            steps += set.ranges.length()
            if steps > max_steps {
              return Err("MR_REGEX_BUDGET: character class execution limit")
            }
            let code = c.to_int()
            let found = set.ranges.iter().any(r => code >= r.0 && code <= r.1)
            if found != set.negate {
              next.push(target)
            }
          }
      }
    }
    active = next
  }
  Ok(false)
}
