---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ---@type Mason.Package[]
      ensure_installed = {
        "ansible-language-server",
        "ansible-lint",
        "jinja-lsp",
      },
    },
    opts_extend = {
      "ensure_installed",
    },
    optional = true,
  },
}
