local popup = require("neogit.lib.popup")
local cli = require("neogit.lib.git.cli")
local Buffer = require("neogit.lib.buffer")
local a = require('neogit.async')

local get_commit_message = a.wrap(function (content, cb)
  Buffer.create {
    name = ".git/COMMIT_EDITMSG",
    filetype = "gitcommit",
    modifiable = true,
    readonly = false,
    initialize = function(buffer)
      buffer:set_lines(0, -1, false, content)

      local mappings = buffer.mmanager.mappings

      mappings["control-c control-c"] = function()
        vim.cmd([[
          silent set buftype=
          silent g/^#/d
          silent w!
          silent bw!
        ]])

        cb()
      end
    end
  }
end)

local prompt_commit_message = a.sync(function (msg)
  local output = {}

  if msg then
    for _, line in ipairs(msg) do
      table.insert(output, line)
    end
  else
    table.insert(output, "")
  end

  table.insert(output, "# Please enter the commit message for your changes. Lines starting")
  table.insert(output, "# with '#' will be ignored, and an empty message aborts the commit.")

  local status_output = a.wait(cli.exec('status'))
  status_output = vim.split(status_output, '\n')

  for _, line in pairs(status_output) do
    if not vim.startswith(line, "  (") then
      table.insert(output, "# " .. line)
    end
  end

  a.wait_for_textlock()
  a.wait(get_commit_message(output))
end)

local function create()
  popup.create(
    "NeogitCommitPopup",
    {
      {
        key = "a",
        description = "Stage all modified and deleted files",
        cli = "all",
        enabled = false
      },
      {
        key = "e",
        description = "Allow empty commit",
        cli = "allow-empty",
        enabled = false
      },
      {
        key = "v",
        description = "Show diff of changes to be committed",
        cli = "verbose",
        enabled = false
      },
      {
        key = "h",
        description = "Disable hooks",
        cli = "no-verify",
        enabled = false
      },
      {
        key = "s",
        description = "Add Signed-off-by line",
        cli = "signoff",
        enabled = false
      },
      {
        key = "R",
        description = "Claim authorship and reset author date",
        cli = "reset-author",
        enabled = false
      },
    },
    {
      {
        key = "A",
        description = "Override the author",
        cli = "author",
        value = ""
      },
      {
        key = "S",
        description = "Sign using gpg",
        cli = "gpg-sign",
        value = ""
      },
      {
        key = "C",
        description = "Reuse commit message",
        cli = "reuse-message",
        value = ""
      },
    },
    {
      {
        {
          key = "c",
          description = "Commit",
          callback = function(popup)
            a.dispatch(function ()
              a.wait(prompt_commit_message(nil))
              local args = vim.list_extend({"-F", ".git/COMMIT_EDITMSG"}, popup.get_arguments())
              local _, code = a.wait(cli.exec("commit", args))
              if code == 0 then
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
      },
      {
        {
          key = "e",
          description = "Extend",
          callback = function() end
        },
        {
          key = "w",
          description = "Reword",
          callback = function() end
        },
        {
          key = "a",
          description = "Amend",
          callback = function(popup)
            a.dispatch(function ()
              local msg = a.wait(cli.exec("log", {"-1", "--pretty=%B"}))
              msg = vim.split(msg, '\n')

              a.wait(prompt_commit_message(msg))
              local _, code = a.wait(cli.exec("commit", {"-F", ".git/COMMIT_EDITMSG", "--amend"}))
              if code == 0 then
                __NeogitStatusRefresh(true)
              end
            end)
          end
        },
      },
      {
        {
          key = "f",
          description = "Fixup",
          callback = function() end
        },
        {
          key = "s",
          description = "Squash",
          callback = function() end
        },
        {
          key = "A",
          description = "Augment",
          callback = function() end
        },
      },
      {
        {
          key = "F",
          description = "Instant Fixup",
          callback = function() end
        },
        {
          key = "S",
          description = "Instant Squash",
          callback = function() end
        },
      }
    })
end

return {
  create = create
}
