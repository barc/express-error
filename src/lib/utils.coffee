exports.tabToSpaces = (s, spaceCount=8) ->
  chars = s.split("")
  len = chars.length
  out = ""

  for i in [0...len]
    char = chars[i]
    if char == "\t"
      spaces = spaceCount - (out.length % spaceCount)
      for k in [0...spaces]
        out += " "
    else
      out += char
  out

exports.padLeft = (s, length, char=' ') ->
  fill = length - s.length
  pad = ""
  if fill > 0
    for [0...fill]
      pad += " "
    pad + s
  else
    pad

