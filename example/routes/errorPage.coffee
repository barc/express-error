exports.index = (req, res) ->
  # throw an error by requiring something which does not exist
  require './foobar'

