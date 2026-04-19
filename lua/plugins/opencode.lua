-- opencode.nvim — AI coding agent integration
-- Managed via vim.pack, deferred after first frame

vim.pack.add({ 'https://github.com/nickjvandyke/opencode.nvim.git' })

---@type opencode.Opts
vim.g.opencode_opts = {
  server = {
    start = function()
      require('opencode.terminal').open('opencode --port', {
        split = 'right',
        width = math.floor(vim.o.columns * 0.35),
      })
    end,
    stop = function()
      require('opencode.terminal').close()
    end,
    toggle = function()
      require('opencode.terminal').toggle('opencode --port', {
        split = 'right',
        width = math.floor(vim.o.columns * 0.35),
      })
    end,
  },
  events = {
    enabled = true,
    reload = true,
    permissions = { enabled = true },
  },
}

local map = vim.keymap.set

-- Toggle opencode terminal
map({ 'n', 't' }, '<C-.>', function() require('opencode').toggle() end, { desc = 'Toggle opencode' })

-- Ask opencode about selection/cursor context
map({ 'n', 'x' }, '<leader>oa', function() require('opencode').ask('@this: ', { submit = true }) end, { desc = 'Ask opencode' })

-- Open action picker (prompts, commands, server controls)
map({ 'n', 'x' }, '<leader>os', function() require('opencode').select() end, { desc = 'Opencode select' })

-- Operator for sending ranges
map({ 'n', 'x' }, '<leader>oo', function() return require('opencode').operator('@this ') end, { desc = 'Opencode operator', expr = true })

-- Quick prompts
map({ 'n', 'x' }, '<leader>oe', function() require('opencode').prompt('explain') end, { desc = 'Opencode explain' })
map({ 'n', 'x' }, '<leader>or', function() require('opencode').prompt('review') end, { desc = 'Opencode review' })
map({ 'n', 'x' }, '<leader>of', function() require('opencode').prompt('fix') end, { desc = 'Opencode fix' })
map({ 'n', 'x' }, '<leader>ot', function() require('opencode').prompt('test') end, { desc = 'Opencode test' })
map({ 'n', 'x' }, '<leader>od', function() require('opencode').prompt('document') end, { desc = 'Opencode document' })
map({ 'n', 'x' }, '<leader>oi', function() require('opencode').prompt('implement') end, { desc = 'Opencode implement' })

-- Scroll opencode messages
map('n', '<S-C-d>', function() require('opencode').command('session.half.page.down') end, { desc = 'Scroll opencode down' })
map('n', '<S-C-u>', function() require('opencode').command('session.half.page.up') end, { desc = 'Scroll opencode up' })
