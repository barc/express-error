FS = require("fs")
Path = require("path")
Utils = require("./utils")
http = require("http")
env = process.env.NODE_ENV || "development"
HOME = process.env.HOME || process.env.USERPROFILE
CWD = process.cwd()


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

##
# HTML escapes a string
#
htmlEscape = (s) ->
  String(s)
    .replace(/&(?!\w+;)/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')


##
# Gets original source line and injects into stack.
#
# @param {Array} lines Array of lines from stack.
# @param {Integer} contextLinesCount The number of context lines to insert
#                                    before and after the error line.
#
# @returns [
#   {
#     frame: 'stack line', code: [
#       { linenum: 123, code: 'compiled line'},
#       { linenum: 124, code: 'compiled line'},
#       { linenum: 125, code: 'compiled line', isErrorLine: true},
#       { linenum: 126, code: 'compiled line'},
#       { linenum: 127, code: 'compiled line'},
#     ]
#   },
#   {
#     frame: 'stack line', code: [
#       { linenum: 123, code: 'compiled line'},
#       { linenum: 124, code: 'compiled line'},
#       { linenum: 125, code: 'compiled line', isErrorLine: true},
#       { linenum: 126, code: 'compiled line'},
#       { linenum: 127, code: 'compiled line'},
#     ]
#   }
# ]
#
injectSourceLines = (lines, contextLinesCount) ->
  newLines = []
  collectSource = true
  cache = {}

  i = 1
  while i < lines.length
    # push error statement
    lineObj = {frame: lines[i], code: []}
    newLines.push lineObj

    if collectSource
      #re = new XRegExp(/(~[^:]+):(\d+):(\d+)/)
      if lines[i].indexOf('(') > 0
        re = /\((.*):(\d+):(\d+)\)/
      else
        re = /at (.*):(\d+):(\d+)/
      matches = re.exec(lines[i])

      # parse the error statement, getting line, code file
      if matches
        console.log "MATCH>>", matches
        codeFile = matches[1]

        if codeFile.indexOf(HOME) is 0
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
          text = cache[codeFile]
          unless text
            text = FS.readFileSync(codeFile, "utf8")
            if ext is ".js"
              cache[codeFile] = text
            else if ext is ".coffee"
              coffee = require("coffee-script")
              text = coffee.compile(text, {})
              cache[codeFile] = text

          pushLine text

        catch err
          console.log err.stack

    i++
  newLines


###
Removes nodeunit specic line trace from stack and colors any
line from current test module.

@param {String} stack Error stack.
@param {Object} mod The test module.
@returns {String} Returns the modified stack trace.
###
betterStack = (stack, contextLinesCount) ->
  return "" unless stack
  result = []

  lines = stack.split("\n")

  for line in lines
    if line.indexOf(CWD) > 0
      result.push line.replace(CWD, ".")
    else if line.indexOf(HOME) > 0
      result.push line.replace(HOME, "~")
    else
      result.push line

  injectSourceLines result, contextLinesCount


##
#
formatText = (frames) ->
  return "" unless Array.isArray(frames) and frames.length > 0

  result = ""
  for frame in frames
    result += frame.frame + "\n"
    if frame.code?.length > 0
      for line in frame.code
        result += "        #{Utils.padLeft(line.linenum.toString(), 4)}: #{line.code}\n"
  result


formatHtml = (frames) ->
  return "" unless Array.isArray(frames) and frames.length > 0

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
# Handles uncaught exceptions and display them on the console. Does not send to
# http client.
#
handleUncaughtExceptions = (contextLinesCount) ->
  process.on "uncaughtException", (err) ->
    stack = if err.stack then formatText(betterStack(err.stack, contextLinesCount)) else ""
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
  handleUncaughtException = options.handleUncaughtException || false
  contextLinesCount = options.contextLinesCount || 0
  title = options.title || "express-error"

  handleUncaughtExceptions(contextLinesCount) if handleUncaughtException

  return (err, req, res, next) ->
    if typeof err is "number"
      status = err
      name = http.STATUS_CODES[status]
      err = new Error(name)
      err.name = name
      err.status = status
    else if typeof err is "string"
      name = err
      err = new Error(name)
      err.name = name
      err.status = 500

    res.statusCode = err.status  if err.status
    res.statusCode = 500  if res.statusCode < 400
    accept = req.headers.accept or ""

    if err instanceof Error
      newerr =
        message: err.message
        stack: betterStack(err.stack, contextLinesCount)
    else if err
      if typeof err is 'string'
        newerr =
          message: err
          stack: null
      else
        message = JSON.stringify(err)
        newerr =
          message: message
          stack: null
    else
      message = "(empty error)"
      newerr =
        message: message
        stack: null

    console.error formatText(newerr.stack) if env is "development"

    # html
    if ~accept.indexOf("html")
      FS.readFile __dirname + "/../public/style.css", "utf8", (e, style) ->
        FS.readFile __dirname + "/../public/error.html", "utf8", (e, html) ->
          stack = formatHtml(newerr.stack)
          html = html.replace("{style}", style).replace("{stack}", stack).replace("{title}", title).replace("{statusCode}", res.statusCode).replace(/\{error\}/g, htmlEscape(newerr.message))
          res.setHeader "Content-Type", "text/html; charset=utf-8"
          res.end html

    # json
    else if ~accept.indexOf("json")
      res.json newerr

    # plain text
    else
      res.setHeader "Content-Type", "text/plain"
      res.end JSON.stringify(newerr)

##
# Express 2 signature.
#
exports.express2 = exports.express3

