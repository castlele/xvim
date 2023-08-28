#! /bin/sh

xvim_path=~/.config/nvim/lua/castlelecs
xvim=./xvim.lua
xvim_ui=./xvim_vim_ui.lua
xvim_binding=./xvim_binding.lua

find $xvim_path -name "xvim*" -delete
cp $xvim $xvim_path
cp $xvim_ui $xvim_path
cp $xvim_binding $xvim_path
