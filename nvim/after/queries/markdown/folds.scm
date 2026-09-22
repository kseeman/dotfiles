;; extends

; The YAML front matter block. nvim-treesitter's markdown folds cover sections,
; code blocks and lists, but not this. In the python profile, jupytext writes
; each notebook's metadata here, and it is folded closed when a notebook opens
; (profiles/python/plugins.lua). Everywhere else foldlevel=99 leaves it open.
(minus_metadata) @fold
