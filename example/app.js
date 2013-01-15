/**
 * Module dependencies.
 */

// allow coffee files to be used directly
require('coffee-script');

var express = require('express');
var routes = require('./routes');
var http = require('http');
var path = require('path');
var app = express();
var errorPage = require('./routes/errorPage');
var expressError = require('..');

app.configure(function() {
  app.set('port', process.env.PORT || 3000);
  app.set('views', __dirname + '/views');
  app.set('view engine', 'jade');
  app.use(express.favicon());
  app.use(express.logger('dev'));
  app.use(express.bodyParser());
  app.use(express.methodOverride());
  app.use(app.router);
  app.use(express.static(path.join(__dirname, 'public')));
});

app.configure('development', function() {
  app.use(expressError.express3({contextLinesCount: 3, handleUncaughtException: true}));
});

app.get('/', routes.index);
app.get('/error', errorPage.index);
app.get('/number', function(req, res, next) {
  next(404);
});
app.get('/string', function(req, res, next) {
  next("some string explaining error");
});
app.get('/null', function(req, res, next) {
  next(null);
});
app.get('/undefined', function(req, res, next) {
  next(undefined);
});
app.get('/object', function(req, res, next) {
  next({some: 'a', undefinedprop: undefined, nullprop: null});
});

http.createServer(app).listen(app.get('port'), function() {
  console.log("Express server listening on port " + app.get('port'));
});
