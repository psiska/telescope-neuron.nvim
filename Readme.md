# telescope-neuron.nvim

`telescope-neuron` is an extension for [telescope.nvim][] that provides its users with option to browse  [srid/neuron][] Zettel database

[telescope.nvim]: https://github.com/nvim-telescope/telescope.nvim
[srid/neuron]: https://github.com/srid/neuron

## Installation

```lua
require'telescope'.load_extension'neuron'
```

## Requirements

Local installation of `neuron` available on the path. See the [Neuron installation guide](https://neuron.zettel.page/install)

## Usage

Now supports `neuron list` only.


### list

`:Telescope neuron list`

Runnning `neuron list` will show all notes in standard directory (~/Sync/neuron)

#### options

#### `bin`

Filepath for the binary `neuron`.

```vim
" path can be expanded
:Telescope neuron list bin=~/neuron  neuron_db_path=~/neuron
```

#### neuron_db_path

Path to neuron database.
```vim
:Telescope neuron list neuron_db_path=~/Sync/neuron
```

