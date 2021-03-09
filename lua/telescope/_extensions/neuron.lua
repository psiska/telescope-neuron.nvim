if vim.fn.executable'neuron' == 0 then
  error("Unable to find neuron executable on the path. Install it.")
end
local neuron_builtin = require'telescope._extensions.neuron_builtin'
return require'telescope'.register_extension{
  exports = {
    list = neuron_builtin.list,
    backlinks = neuron_builtin.backlinks
  },
}
