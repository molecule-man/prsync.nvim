## Local development

to quickly load plugin without installing it globally

```vim
:set runtimepath+=.
:lua require("prsync").setup()
```

to reload the plugin:

```vim
:lua for k in pairs(package.loaded) do if k:match("^prsync") then package.loaded[k] = nil end end require("prsync").setup()
```
