local requests = require('cmp_ai.requests')

OpenAI = requests:new(nil)

function OpenAI:new(o, params)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  
  -- Merge user params with defaults
  params = params or {}
  self.params = {
    model = params.model or 'gpt-3.5-turbo',
    temperature = params.temperature or 0.1,
    n = params.n or 1,
    base_url = params.base_url and (params.base_url:gsub("/$", "") .. "/v1/chat/completions") 
              or 'https://api.openai.com/v1/chat/completions',
    api_key_env = params.api_key_env or 'OPENAI_API_KEY',
    additional_headers = params.additional_headers or {},
  }

  -- Get API key from env var or direct config
  self.api_key = params.api_key or os.getenv(self.params.api_key_env)
  if not self.api_key then
    vim.schedule(function()
      vim.notify(string.format('%s environment variable or api_key not set', self.params.api_key_env), vim.log.levels.ERROR)
    end)
    self.api_key = 'NO_KEY'
  end

  -- Setup headers with auth and any additional headers
  self.headers = vim.tbl_extend('force',
    { 'Authorization: Bearer ' .. self.api_key },
    vim.tbl_map(function(k, v) return k .. ': ' .. v end, self.params.additional_headers)
  )
  return o
end

function OpenAI:complete(lines_before, lines_after, cb)
  if not self.api_key or self.api_key == 'NO_KEY' then
    vim.schedule(function()
      vim.notify('API key not configured', vim.log.levels.ERROR)
    end)
    return
  end
  local data = {
    messages = {
      {
        role = 'system',
        content = [=[You are a coding companion.
You need to suggest code for the language ]=] .. vim.o.filetype .. [=[
Given some code prefix and suffix for context, output code which should follow the prefix code.
You should only output valid code in the language ]=] .. vim.o.filetype .. [=[
. to clearly define a code block, including white space, we will wrap the code block
with tags.
Make sure to respect the white space and indentation rules of the language.
Do not output anything in plain language, make sure you only use the relevant programming language verbatim.
For example, consider the following request:
<begin_code_prefix>def print_hello():<end_code_prefix><begin_code_suffix>\n    return<end_code_suffix><begin_code_middle>
Your answer should be:

    print("Hello")<end_code_middle>
]=],
      },
      {
        role = 'user',
        content = '<begin_code_prefix>' .. lines_before .. '<end_code_prefix>' .. '<begin_code_suffix>' .. lines_after .. '<end_code_suffix><begin_code_middle>',
      },
    },
    model = self.params.model,
    temperature = self.params.temperature,
    n = self.params.n,
  }
  
  self:Get(self.params.base_url, self.headers, data, function(answer)
    local new_data = {}
    
    -- Handle API errors
    if answer.error then
      local error_msg = answer.error.message or "Unknown API error"
      vim.schedule(function()
        vim.notify("API Error: " .. error_msg, vim.log.levels.ERROR)
      end)
      cb({ { error = error_msg } })
      return
    end
    
    -- Handle successful responses
    if answer.choices and #answer.choices > 0 then
      for _, response in ipairs(answer.choices) do
        -- Handle both standard OpenAI and compatible API response formats
        local content = response.message and response.message.content or response.text
        if content then
          local entry = content:gsub('<end_code_middle>', '')
          entry = entry:gsub('```', '')
          table.insert(new_data, entry)
        end
      end
      if #new_data > 0 then
        cb(new_data)
      else
        local error_msg = "No valid completions in response"
        vim.schedule(function()
          vim.notify(error_msg, vim.log.levels.ERROR)
        end)
        cb({ { error = error_msg } })
      end
    else
      -- Handle unexpected response format
      local error_msg = "Unexpected API response format"
      vim.schedule(function()
        vim.notify(error_msg, vim.log.levels.ERROR)
      end)
      cb({ { error = error_msg } })
    end
  end)
end

function OpenAI:test()
  self:complete('def factorial(n)\n    if', '    return ans\n', function(data)
    dump(data)
  end)
end

return OpenAI
