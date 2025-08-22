vim.filetype.add({
  extension = {
    tf = "terraform",
  },
})

vim.env.SOPS_AGE_KEY_FILE = "./secrets/age.agekey"

vim.keymap.set("n", "<localleader>e", function()
  vim.cmd("!sops --encrypt --in-place " .. vim.fn.expand("%"))
  vim.cmd("edit!")
end, { desc = "SOPS | Encrypt Current Secret File" })

vim.keymap.set("n", "<localleader>d", function()
  vim.cmd("!sops --decrypt --in-place " .. vim.fn.expand("%"))
  vim.cmd("edit!")
end, { desc = "SOPS | Decrypt Current File" })
