local M = {}

local conf = {
  max_lines = 50,
  run_on_every_keystroke = true,
  provider = 'HF',
  provider_options = {},
  notify = true,
  notify_callback = function(msg)
    vim.notify(msg)
  end,
  ignored_file_types = {},
}

function M:setup(params)
  -- Debug: Print incoming params
  vim.notify("Debug - Incoming params:\n" .. vim.inspect(params))
  
  -- Apply configuration
  for k, v in pairs(params or {}) do
    conf[k] = v
  end
  
  -- Debug: Print provider options before initialization
  vim.notify("Debug - Provider options:\n" .. vim.inspect(conf.provider_options))
  
  local status, provider = pcall(require, 'cmp_ai.backends.' .. conf.provider:lower())
  if status then
    local name = conf.provider
    -- Create new provider instance with options
    conf.provider = provider:new(nil, conf.provider_options)
    conf.provider.name = name
    
    -- Debug: Print provider params after initialization
    vim.notify("Debug - Provider params:\n" .. vim.inspect(conf.provider.params))
  else
    vim.notify('Bad provider in config: ' .. conf.provider, vim.log.levels.ERROR)
  end
end

function M:get(what)
  return conf[what]
end

return M
