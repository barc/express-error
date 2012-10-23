exports.index = function(req, res) {
  // throw an error by requiring something which does not exist
  require('./foobar');
};

