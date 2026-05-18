-- Plugins shared across ALL profiles (default, dotnet, java).
-- Imported once from init.lua so it isn't duplicated per profile.
return {
  -- Dim inactive windows/splits.
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    config = function()
      require "configs.tint"
    end,
  },
}
