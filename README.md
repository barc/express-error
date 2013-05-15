# express-error

Enhanced express 3 error handler which displays source code within error stack for
JavaScript and CoffeeScript.

Open sourced by [Barc](http://barc.com), instant real-time forum on any website.

## Usage

```javascript
var expressError = require('express-error');

app.configure('development', function() {
  app.use(expressError.express3({contextLinesCount: 3, handleUncaughtException: true}));
});
```

## Options

```javascript
{
    contextLinesCount: Integer,         // Number of lines to insert before and after the error line.
    handleUncaughtException: Boolean,   // Whether to handle uncaught exception.
    title: String                       // The title for HTML error page
}
```

## Screenshot

![screenshot](https://github.com/barc/express-error/raw/master/img/stack.png)

## To run the example and see error

    npm install -d
    node example/app.js

    # browse http://localhost:3000/error

## License

The MIT License (MIT) Copyright (c) 2012 Barc, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


