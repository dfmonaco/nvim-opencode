local MiniTest = require('mini.test')
local T = MiniTest.new_set()

T['allocate_port allocates in correct range'] = function()
  local State = require('plugin.state')
  State.set_port(nil) -- Reset port state to avoid leaks
  local Client = require('plugin.client')
  local port = Client.allocate_port()

  MiniTest.expect.no_equality(port, nil, "allocate_port() failed: port is nil.")
  MiniTest.expect.equality(type(port), 'number')
  MiniTest.expect.equality(port >= 60000 and port <= 61000, true)
  -- Confirm state synced
  MiniTest.expect.equality(State.get_port(), port)
end

return T
