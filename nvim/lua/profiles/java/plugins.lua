-- Java profile.
-- Universal specs (conform, lspconfig, dap, treesitter base, nvim-tree base,
-- render-markdown, claude-code, tint) live in plugins/shared.lua.
return {
  -- Java Language Server
  --
  -- `start_or_attach` attaches a client to a *single* buffer: nvim-jdtls registers
  -- no FileType autocmd of its own, and lazy.nvim runs `config` only once. Calling
  -- it straight from `config` therefore serves only the first Java file of the
  -- session; every later one gets no client, and `gd`/`K`/completion silently fall
  -- back to Vim builtins. So `config` only builds the launch config, and an
  -- autocmd starts a client per buffer.
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    config = function()
      local jdtls = require('jdtls')
      local profile_manager = require('profile-manager')
      local home = os.getenv('HOME')

      -- Get OS-specific configuration directory name
      local config_name = profile_manager.get_config_dir_name()

      -- Find the jdtls launcher jar file
      local jdtls_install = home .. '/.local/share/nvim/mason/packages/jdtls'
      local launcher_jar = vim.fn.glob(jdtls_install .. '/plugins/org.eclipse.equinox.launcher_*.jar')
      if launcher_jar == '' then
        vim.notify('jdtls launcher jar not found - install it with :Mason', vim.log.levels.ERROR)
        return
      end

      -- Get default capabilities from NvChad
      local capabilities = require("nvchad.configs.lspconfig").capabilities

      -- Anything in a jar resolves to a `jdt://` URI whose text nvim-jdtls has to
      -- fetch over LSP (`java/classFileContents`) from a `BufReadCmd`. That fetch
      -- blocks for at most `jdt_uri_timeout_ms`; a sources download or a large
      -- decompile can outlast it, and then the buffer is still empty when Neovim
      -- jumps -- `nvim_win_set_cursor` throws "Invalid cursor line: out of range".
      -- Raising the budget makes that rare (`vim.wait` blocks the UI, so this is a
      -- ceiling, not a cost), and `safe_jump` below keeps it from ever throwing.
      require('jdtls').settings.jdt_uri_timeout_ms = 20000

      -- Neovim honours `on_list` before it touches the cursor, so routing jumps
      -- through it lets us clamp to what the buffer actually holds.
      local function safe_jump(list, tagname, from, win)
        local items = list.items or {}
        if #items == 0 then
          return
        end
        if #items > 1 then
          vim.fn.setqflist({}, ' ', { title = list.title, items = items })
          vim.cmd('botright copen')
          return
        end

        local item = items[1]
        local target = item.bufnr or vim.fn.bufadd(item.filename)
        vim.fn.bufload(target)

        vim.cmd("normal! m'") -- jumplist
        vim.fn.settagstack(win, { items = { { tagname = tagname, from = from } } }, 't')
        vim.bo[target].buflisted = true
        vim.api.nvim_win_set_buf(win, target)

        -- `item.col` is derived from the target line's text, so it is 1 whenever the
        -- buffer was still empty at that point. The untouched LSP range rides along
        -- on `user_data`, and that stays right either way -- but its `character` is
        -- in the client's position encoding (UTF-16 for jdtls), not bytes, so it is
        -- converted against the line once the line is actually there.
        local range = item.user_data
          and (item.user_data.range or item.user_data.targetSelectionRange)
        local client = list.context
          and vim.lsp.get_clients({ bufnr = list.context.bufnr, name = 'jdtls' })[1]
        local encoding = client and client.offset_encoding or 'utf-16'

        local function place(row)
          local line = vim.api.nvim_buf_get_lines(target, row - 1, row, false)[1] or ''
          local col = range and vim.str_byteindex(line, encoding, range.start.character, false)
            or (item.col - 1)
          vim.api.nvim_win_set_cursor(win, { row, math.max(math.min(col, #line), 0) })
          vim.api.nvim_win_call(win, function()
            vim.cmd('normal! zv')
          end)
        end

        local lnum = math.min(item.lnum, vim.api.nvim_buf_line_count(target))
        place(lnum)
        if lnum == item.lnum then
          return
        end

        -- Clamped, so the fetch is still in flight. Finish the jump when the text
        -- lands, but only while the window is still parked where we left it -- the
        -- cursor is the user's once they move it.
        local tries = 0
        local function settle()
          if not vim.api.nvim_win_is_valid(win)
            or vim.api.nvim_win_get_buf(win) ~= target
            or vim.api.nvim_win_get_cursor(win)[1] ~= lnum
          then
            return
          end
          if vim.api.nvim_buf_line_count(target) >= item.lnum then
            place(item.lnum)
            return
          end
          tries = tries + 1
          if tries < 60 then
            vim.defer_fn(settle, 250)
          else
            vim.notify(
              ('jdtls never returned contents for this source; stayed on line %d of %d.')
                :format(lnum, item.lnum),
              vim.log.levels.WARN
            )
          end
        end
        vim.defer_fn(settle, 100)
      end

      local function jump(method)
        return function()
          local from = vim.fn.getpos('.')
          from[1] = vim.api.nvim_get_current_buf()
          local tagname = vim.fn.expand('<cword>')
          local win = vim.api.nvim_get_current_win()
          vim.lsp.buf[method]({
            on_list = function(list)
              safe_jump(list, tagname, from, win)
            end,
          })
        end
      end

      -- Setup LSP keymaps on attach
      local on_attach = function(client, bufnr)
        -- Load NvChad's default LSP keymaps (includes gd, gr, K, etc.)
        require("nvchad.configs.lspconfig").on_attach(client, bufnr)

        -- Re-map the location jumps NvChad just bound, so they go through
        -- `safe_jump`. Must come after NvChad's on_attach to win.
        local function opts(desc)
          return { buffer = bufnr, desc = 'LSP ' .. desc }
        end
        vim.keymap.set('n', 'gd', jump('definition'), opts 'Go to definition')
        vim.keymap.set('n', 'gD', jump('declaration'), opts 'Go to declaration')
        vim.keymap.set('n', '<leader>D', jump('type_definition'), opts 'Go to type definition')
      end

      -- Tiers, tried in order: a wrapper script or `.git` marks the top of a build,
      -- whereas every submodule of a multi-module build has its own `pom.xml` or
      -- `build.gradle`. Testing all markers at once would root each submodule
      -- separately and start a JVM per submodule. Bare build files are the fallback
      -- for a project that has neither.
      local root_markers = {
        { 'mvnw', 'gradlew', '.git' },
        { 'pom.xml', 'build.gradle', 'build.gradle.kts' },
      }

      -- Everything below `java` is an eclipse.jdt.ls setting and must be nested
      -- there. Keys placed at the root of `settings` are silently ignored.
      local settings = {
        java = {
          eclipse = {
            downloadSources = true,
          },
          configuration = {
            updateBuildConfiguration = "interactive",
          },
          maven = {
            downloadSources = true,
          },
          implementationsCodeLens = {
            enabled = true,
          },
          referencesCodeLens = {
            enabled = true,
          },
          references = {
            includeDecompiledSources = true,
          },
          format = {
            enabled = true,
          },
          signatureHelp = { enabled = true },
          -- Parameter names beside every argument, not only literals (the
          -- default). Displayed by the global inlay-hint switch in mappings.lua.
          inlayHints = {
            parameterNames = { enabled = "all" },
          },
          completion = {
            favoriteStaticMembers = {
              "org.hamcrest.MatcherAssert.assertThat",
              "org.hamcrest.Matchers.*",
              "org.hamcrest.CoreMatchers.*",
              "org.junit.jupiter.api.Assertions.*",
              "java.util.Objects.requireNonNull",
              "java.util.Objects.requireNonNullElse",
              "org.mockito.Mockito.*"
            }
          },
          contentProvider = { preferred = 'fernflower' },
          sources = {
            organizeImports = {
              starThreshold = 9999,
              staticStarThreshold = 9999,
            }
          },
          codeGeneration = {
            toString = {
              template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}"
            },
            useBlocks = true,
          },
        },
      }

      local function start_jdtls(bufnr)
        -- The autocmd below fires for every Java buffer, and lazy.nvim re-fires
        -- FileType after loading this plugin, so the same buffer can arrive twice.
        if next(vim.lsp.get_clients({ bufnr = bufnr, name = 'jdtls' })) then
          return
        end

        -- Per buffer, not per cwd: one nvim session can span several projects, and
        -- each needs its own jdtls client and its own workspace data directory.
        -- `jdt://` buffers are java too, but nvim-jdtls attaches those itself, and
        -- `vim.fs.root` would resolve such a name against the cwd.
        if not vim.startswith(vim.uri_from_bufnr(bufnr), 'file://') then
          return
        end
        local root_dir = vim.fs.root(bufnr, root_markers)
        if not root_dir then
          return
        end
        -- The basename keeps the directory recognisable; the hash keeps two
        -- projects that share one (`~/work/api`, `~/personal/api`) from sharing
        -- an index, which two live jdtls processes would corrupt.
        local workspace_dir = home .. '/.cache/jdtls/workspace/'
          .. vim.fn.fnamemodify(root_dir, ':t') .. '-' .. vim.fn.sha256(root_dir):sub(1, 8)

        jdtls.start_or_attach({
          cmd = {
            'java',
            '-Declipse.application=org.eclipse.jdt.ls.core.id1',
            '-Dosgi.bundles.defaultStartLevel=4',
            '-Declipse.product=org.eclipse.jdt.ls.core.product',
            '-Dlog.protocol=true',
            '-Dlog.level=ALL',
            '-Xms1g',
            '--add-modules=ALL-SYSTEM',
            '--add-opens', 'java.base/java.util=ALL-UNNAMED',
            '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
            '-jar', launcher_jar,
            '-configuration', jdtls_install .. '/' .. config_name,
            '-data', workspace_dir
          },
          root_dir = root_dir,
          settings = settings,
          -- Client-side extensions (organize imports, generate accessors, the
          -- decompiler hooks) belong in `init_options`, not `settings`.
          init_options = {
            bundles = {},
            extendedClientCapabilities = jdtls.extendedClientCapabilities,
          },
          on_attach = on_attach,
          capabilities = capabilities,
        }, nil, { bufnr = bufnr })
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("JdtlsAttach", { clear = true }),
        pattern = "java",
        desc = "Start or attach a jdtls client for this buffer",
        callback = function(args)
          start_jdtls(args.buf)
        end,
      })
    end,
  },

  -- Testing support for Java
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "rcasia/neotest-java",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-java")({
            ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
          }),
        },
      })
    end,
  },

  -- Mason tools for the Java profile. `sqlfluff` backs conform's SQL
  -- formatter (configs/conform.lua), which formats .sql files on save. See
  -- `plugins/shared.lua` for how this list is consumed.
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "sqlfluff" },
    },
  },

  -- Treesitter languages for the Java profile
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "java", "kotlin", "groovy", "xml", "json", "yaml", "markdown",
        "lua", "bash", "dockerfile", "sql", "properties"
      },
    },
  },

  -- NvimTree ignore patterns for Java projects
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      filters = {
        custom = {
          "^.git$", "^node_modules$", "^target$", "^build$",
          "^.gradle$", "^.m2$", "^.idea$"
        },
      },
    },
  },

  -- Enhanced snippets for Java
  {
    "L3MON4D3/LuaSnip",
    dependencies = { "rafamadriz/friendly-snippets" },
    build = "make install_jsregexp",
  },

  -- Project management
  {
    "ahmedkhalf/project.nvim",
    config = function()
      require("project_nvim").setup({
        patterns = {
          ".git", "pom.xml", "build.gradle", "build.gradle.kts",
          "settings.gradle", "gradlew", "mvnw"
        },
      })
    end,
  },

  -- Comments and documentation
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require('neogen').setup({
        languages = {
          java = {
            template = {
              annotation_convention = "javadoc"
            }
          }
        }
      })
    end,
  },

  -- Maven/Gradle integration
  {
    "eatgrass/maven.nvim",
    cmd = { "Maven", "MavenExec" },
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require("maven").setup({
        executable = "./mvnw", -- Try wrapper first
      })
    end,
  },

  -- Spring Boot support
  {
    "JavaHello/spring-boot.nvim",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-jdtls",
      "ibhagwan/fzf-lua",
    },
    config = function()
      -- Spring Boot's inlay hints are dropped so jdtls is the only client
      -- sending them. Neovim 0.12 keeps one version for all clients' hints,
      -- so after an edit one client's stale columns get drawn against the new
      -- text: "Invalid 'col': out of range" on pressing Return. Fixed upstream
      -- (neovim#36318); remove this once on a release with the fix.
      -- A per-client handler rather than removing the capability, because
      -- the server may register inlay hints dynamically.
      require("spring_boot").setup({
        server = {
          handlers = { ["textDocument/inlayHint"] = function() end },
        },
      })
    end,
  },
}
