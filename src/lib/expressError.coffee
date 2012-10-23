FS = require("fs")
HOME = process.env.HOME
Path = require("path")
Utils = require("./utils")

env = process.env.NODE_ENV || "development"
color = (s) -> s

##
# Align code to left on first non-whitespace
alignLeft = (lines) ->
  result = []
  left = Number.MAX_VALUE
  for line in lines
    line.code = Utils.tabToSpaces(line.code)
    for i in [0...line.code.length]
      if line.code[i] != " "
        left = Math.min(left, i)

  for line in lines
    line.code = line.code.slice(left)


###
Gets original source line and injects into stack.

@param {Array} lines Array of lines from stack.
@param {String} fileName The file being tested.


@returns [
  {
    frame: 'stack line', code: [
      { linenum: 123, code: 'compiled line'},
      { linenum: 124, code: 'compiled line'},
      { linenum: 125, code: 'compiled line', isErrorLine: true},
      { linenum: 126, code: 'compiled line'},
      { linenum: 127, code: 'compiled line'},
    ]
  },
  {
    frame: 'stack line', code: [
      { linenum: 123, code: 'compiled line'},
      { linenum: 124, code: 'compiled line'},
      { linenum: 125, code: 'compiled line', isErrorLine: true},
      { linenum: 126, code: 'compiled line'},
      { linenum: 127, code: 'compiled line'},
    ]
  }
]
###
injectSourceLines = (lines, fileName, contextLinesCount) ->
  newLines = []
  collectSource = true
  cache = {}

  # start at line after error message
  i = 1

  while i < lines.length
    # push error statement
    lineObj = {frame: lines[i], code: []}
    newLines.push lineObj

    if collectSource
      #re = new XRegExp(/(~[^:]+):(\d+):(\d+)/)
      re = /(~[^:]+):(\d+):(\d+)/
      matches = re.exec(lines[i])

      # parse the error statement, getting line, code file
      if matches
        codeFile = matches[1]
        codeFile = codeFile.replace("~", HOME)
        linenum = parseInt(matches[2])
        col = matches[3]
        ext = Path.extname(codeFile)

        pushLine = (text, suffix) ->
          suffix = suffix or ""
          textLines = text.split("\n")
          j = 0


          # get source and context lines
          while j < textLines.length
            # show contextual lines before
            if j >= (linenum - 1 - contextLinesCount) and (j < linenum - 1)
              lineObj.code.push linenum: j + 1, code: textLines[j]

            else if j is linenum - 1
              lineObj.code.push linenum: j + 1, code: textLines[j], isErrorLine: true
              break unless contextLinesCount > 0

            else if (j > linenum - 1) and (j < linenum + contextLinesCount)
              lineObj.code.push linenum: j + 1, code: textLines[j]
              break if j == (linenum - 1 + contextLinesCount)

            j++

          alignLeft lineObj.code

        try
          if ext is ".js"
            text = cache[codeFile]
            unless text
              text = FS.readFileSync(codeFile, "utf8")
              cache[codeFile] = text
            pushLine text
          else if ext is ".coffee"
            text = cache[codeFile]
            unless text
              coffee = require("coffee-script")
              buffer = FS.readFileSync(codeFile, "utf8")
              text = coffee.compile(buffer, {})
              cache[codeFile] = text
            pushLine text
        catch err
          console.log err.stack

      # swallow any error since we should always see the stack

    i++
  newLines


###
Removes nodeunit specic line trace from stack and colors any
line from current test module.

@param {String} stack Error stack.
@param {Object} mod The test module.
@returns {String} Returns the modified stack trace.
###
betterStack = (stack, contextLinesCount, fileName='foo') ->
  lines = stack.split("\n")
  result = []
  i = 0

  while i < lines.length
    line = lines[i]
    if i is 0
      line = "  " + line
    else
      # emphasize lines that are part of `filename
      if line.indexOf(fileName) >= 0
        #line = line.replace('at', color('⇢ ', 'magenta+b'));
        line = color(line, "white+b")
      else
        # deemphasize lines we don't care about
        line = color(line, "black+b")  if line.indexOf(HOME) < 0
    result.push line.replace(HOME, "~")
    i += 1
  result = injectSourceLines(result, fileName, contextLinesCount)


##
#
formatText = (frames) ->
  return "" unless frames

  result = ""
  for frame in frames
    result += frame.frame + "\n"
    if frame.code?.length > 0
      for line in frame.code
        result += "        #{Utils.padLeft(line.linenum.toString(), 4)}: #{line.code}\n"
  result


formatHtml = (frames) ->
  return "" unless frames

  result = "<ul>"
  for frame in frames
    result += "<li>"
    result += "  <div class='frame'>" + htmlEscape(frame.frame) + "</div>"
    if frame.code?.length > 0
      result += "  <ul class='source'>"
      for line in frame.code
        attr = if line.isErrorLine then "class='error-line'" else ""
        result += "  <li #{attr}>"
        result += "<pre>" + Utils.padLeft(line.linenum.toString(), 4) + ": " + htmlEscape(line.code) + "</pre>"
        result += "  </li>"
      result += "  </ul>"
    result += "</li>"
  result += "</ul>"


##
# Handles uncaught exceptions and display them on the console,
# NOT through the web server.
#
handleUncaughtExceptions = ->
  process.on "uncaughtException", (err) ->
    message = err
    stack = ""
    if (err.stack)
      stack = formatText(betterStack(err.stack, contextLinesCount))
    console.error "Uncaught exception", "#{err.message}\n#{stack}"


##
# Returns a function with signature compatible with express 3.
#
# @param {Object} options {enableUncaughtExceptions: "set to true to let this handle uncaught exceptions",
#                          contextLinesCount: "the number of lines to print before and after an error line"
#                         }
#
exports.express3 = (options={}) ->
  showStack = options.showStack || false
  dumpExceptions = options.dumpExceptions || false
  enableUncaughtExceptions = options.enableUncaughtExceptions || false
  contextLinesCount = options.contextLinesCount || 0

  handleUncaughtExceptions() if enableUncaughtExceptions

  return (err, req, res, next) ->
    res.statusCode = err.status  if err.status
    res.statusCode = 500  if res.statusCode < 400
    accept = req.headers.accept or ""

    stack = betterStack(err.stack, contextLinesCount)
    console.error formatText(stack) if env is "development"

    # html
    if ~accept.indexOf("html")
      FS.readFile __dirname + "/../public/style.css", "utf8", (e, style) ->
        FS.readFile __dirname + "/../public/error.html", "utf8", (e, html) ->
          stack = formatHtml(stack)
          html = html.replace("{style}", style).replace("{stack}", stack).replace("{title}", exports.title).replace("{statusCode}", res.statusCode).replace(/\{error\}/g, htmlEscape(err.toString()))
          res.setHeader "Content-Type", "text/html; charset=utf-8"
          res.end html

    # json
    else if ~accept.indexOf("json")
      error =
        message: err.message
        stack: stack

      for prop of err
        error[prop] = err[prop]
      json = JSON.stringify(error: error)
      res.setHeader "Content-Type", "application/json"
      res.end json

    # plain text
    else
      res.writeHead res.statusCode,
        "Content-Type": "text/plain"

      res.end stack


htmlEscape = (s) ->
  String(s)
    .replace(/&(?!\w+;)/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')


exports.title = "express-error"

