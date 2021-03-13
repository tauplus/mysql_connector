
func to_string*(str: openArray[char]): string =
  result = newStringOfCap(len(str))
  for ch in str:
    add(result, ch)