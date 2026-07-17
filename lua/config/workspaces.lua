local LazyVim = require("lazyvim.util")

local M = {}

local starter_filetypes = {
  alpha = true,
  dashboard = true,
  ministarter = true,
  snacks_dashboard = true,
}

local function normalize(path)
  if not path or path == "" then
    return nil
  end
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function is_directory(path)
  local stat = path and vim.uv.fs_stat(path) or nil
  return stat and stat.type == "directory"
end

local function is_git_workspace(path)
  return path and vim.uv.fs_stat(path .. "/.git") ~= nil
end

local function workspace_name(path)
  local name = vim.fn.fnamemodify(path, ":t")
  return name ~= "" and name or path
end

local function tab_root(tab)
  local ok, root = pcall(vim.api.nvim_tabpage_get_var, tab, "workspace_root")
  if ok and root ~= "" then
    return normalize(root)
  end
  local windows = vim.api.nvim_tabpage_list_wins(tab)
  return normalize(windows[1] and vim.api.nvim_win_call(windows[1], vim.fn.getcwd) or vim.fn.getcwd())
end

local function tab_has_content(tab)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = buf })
      local buftype = vim.api.nvim_get_option_value("buftype", { buf = buf })
      if filetype ~= "neo-tree" and not starter_filetypes[filetype] then
        if
          vim.api.nvim_buf_get_name(buf) ~= ""
          or vim.api.nvim_get_option_value("modified", { buf = buf })
          or buftype ~= ""
        then
          return true
        end
      end
    end
  end
  return false
end

local function remember(path)
  local history = require("project_nvim.utils.history")
  for _, project in ipairs(history.get_recent_projects()) do
    if normalize(project) == path then
      return
    end
  end
  history.session_projects[#history.session_projects + 1] = path
end

local function set_current_workspace(path)
  vim.cmd("tcd " .. vim.fn.fnameescape(path))
  vim.t.workspace_root = path
  vim.t.workspace_name = workspace_name(path)
  require("project_nvim.project").set_pwd(path, "workspace")
  remember(path)
end

local function find_open_workspace(path)
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if tab_root(tab) == path then
      return tab
    end
  end
end

function M.list()
  local projects = {}
  local seen = {}
  local function add(path)
    path = normalize(path)
    if path and is_directory(path) and not seen[path] then
      seen[path] = true
      projects[#projects + 1] = path
    end
  end

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    add(tab_root(tab))
  end
  for _, path in ipairs(require("project_nvim.utils.history").get_recent_projects()) do
    add(path)
  end
  add(LazyVim.root())
  return projects
end

function M.add(path)
  path = normalize(path or vim.fn.getcwd())
  if not is_directory(path) then
    vim.notify("Workspace directory does not exist: " .. tostring(path), vim.log.levels.ERROR)
    return false
  end

  remember(path)
  require("project_nvim.utils.history").write_projects_to_history()
  vim.notify("Workspace saved: " .. path)
  return true
end

function M.remove(path)
  path = normalize(path)
  if not path then
    return false
  end

  local history = require("project_nvim.utils.history")
  for _, collection in ipairs({ history.recent_projects or {}, history.session_projects }) do
    for index = #collection, 1, -1 do
      if normalize(collection[index]) == path then
        table.remove(collection, index)
      end
    end
  end
  history.write_projects_to_history()
  vim.notify("Workspace removed from the saved list: " .. path)
  return true
end

function M.open(path, force_new_tab)
  path = normalize(path)
  if not is_directory(path) then
    vim.notify("Workspace directory does not exist: " .. tostring(path), vim.log.levels.ERROR)
    return false
  end

  if not force_new_tab then
    local existing = find_open_workspace(path)
    if existing then
      vim.api.nvim_set_current_tabpage(existing)
      return true
    end
  end

  if force_new_tab or tab_has_content(vim.api.nvim_get_current_tabpage()) then
    vim.cmd.tabnew()
  end
  set_current_workspace(path)
  require("config.workspace").open()
  vim.cmd.redrawtabline()
  return true
end

function M.close()
  if #vim.api.nvim_list_tabpages() == 1 then
    vim.notify("This is the only open workspace")
    return false
  end
  local ok, err = pcall(vim.cmd.tabclose)
  if not ok then
    vim.notify(err, vim.log.levels.ERROR, { title = "Close workspace" })
  end
  return ok
end

function M.show()
  local projects = M.list()
  if #projects == 0 then
    vim.notify("No workspaces are saved yet. Use :WorkspaceAdd <directory>.")
    return
  end

  local display_to_path = {}
  local entries = {}
  for _, path in ipairs(projects) do
    local entry = string.format("%-24s  %s", workspace_name(path), path)
    display_to_path[entry] = path
    entries[#entries + 1] = entry
  end

  local function selected_path(selected)
    return selected and display_to_path[selected[1]] or nil
  end

  require("fzf-lua").fzf_exec(entries, {
    prompt = "Workspaces> ",
    winopts = { width = 0.78, height = 0.62 },
    fzf_opts = {
      ["--header"] = "ENTER open | CTRL-T new tab | CTRL-A save current | CTRL-D remove",
    },
    actions = {
      ["default"] = {
        function(selected)
          M.open(selected_path(selected), false)
        end,
      },
      ["ctrl-t"] = {
        function(selected)
          M.open(selected_path(selected), true)
        end,
      },
      ["ctrl-a"] = function()
        M.add(vim.fn.getcwd())
        vim.schedule(M.show)
      end,
      ["ctrl-d"] = function(selected)
        M.remove(selected_path(selected))
        vim.schedule(M.show)
      end,
    },
  })
end

function M.tabline()
  local current = vim.api.nvim_get_current_tabpage()
  local parts = {}
  for index, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local root = tab_root(tab)
    local ok, name = pcall(vim.api.nvim_tabpage_get_var, tab, "workspace_name")
    name = ok and name or workspace_name(root)
    name = vim.fn.strcharpart(name:gsub("%%", "%%%%"), 0, 24)

    local modified = false
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_get_option_value("modified", { buf = vim.api.nvim_win_get_buf(win) }) then
        modified = true
        break
      end
    end

    local highlight = tab == current and "TabLineSel" or "TabLine"
    parts[#parts + 1] = string.format("%%#%s#%%%dT 󰉋 %s%s %%T", highlight, index, name, modified and " +" or "")
  end
  return table.concat(parts) .. "%#TabLineFill#%T"
end

function M.setup()
  if M._setup then
    return
  end
  M._setup = true

  local root = normalize(LazyVim.root())
  vim.t.workspace_root = root
  vim.t.workspace_name = workspace_name(root)
  if is_git_workspace(root) then
    remember(root)
  end

  vim.api.nvim_create_user_command("Workspaces", M.show, { desc = "Show saved and open workspaces" })
  vim.api.nvim_create_user_command("WorkspaceAdd", function(command)
    M.add(command.args ~= "" and command.args or vim.fn.getcwd())
  end, { nargs = "?", complete = "dir", desc = "Save a workspace directory" })
  vim.api.nvim_create_user_command("WorkspaceClose", M.close, { desc = "Close the current workspace tab" })

  local group = vim.api.nvim_create_augroup("workspace_manager", { clear = true })
  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function(event)
      local path = normalize(event.file)
      if path then
        vim.t.workspace_root = path
        vim.t.workspace_name = workspace_name(path)
        if is_git_workspace(path) then
          remember(path)
        end
        vim.cmd.redrawtabline()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "TabEnter", "BufModifiedSet" }, {
    group = group,
    callback = function()
      vim.cmd.redrawtabline()
    end,
  })

  _G.NvimWorkspacesTabline = M.tabline
  vim.opt.showtabline = 2
  vim.opt.tabline = "%!v:lua.NvimWorkspacesTabline()"
end

return M
