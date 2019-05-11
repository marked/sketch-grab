dofile("table_show.lua")
JSON = (loadfile "JSON.lua")() -- one-time load of the routines

local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')
local tracker_host = os.getenv('tracker_host')

local url_count = 0
local downloaded = {}
local abortgrab = false
local code_counts = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

local resp_codes_file = io.open(item_dir..'/'..warc_file_base..'_data.txt', 'w')
local resp_codes_file_json = io.open(item_dir..'/'..warc_file_base..'_data.json', 'w')

-----------------------------------------------------------------------------------------------------------------------

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  if code_counts[status_code] == nil then
    code_counts[status_code] = 1
  else
    code_counts[status_code] = code_counts[status_code] + 1
  end

  local ts = os.time()
  local log_line = ts .. "\t" .. item_type .. ":" .. item_value  .. "\t" .. status_code .. "\t" .. url["url"]
  local log_line_json = JSON:encode( { ts = ts, item = item_type .. ":" .. item_value, status_code = status_code, url = url["url"] } )

  -- Any result -> log
  os.execute("/bin/bash -c 'echo \"" .. log_line .. "\" > /dev/udp/" .. tracker_host .. "/3333 '" )
  resp_codes_file:write(log_line .. "\n")
  resp_codes_file_json:write(log_line_json .. "\n")
  
  -- Expected result -> continue
  if (string.match(url["host"], "^storage%.sketch%.sonymobile%.com") and status_code == 307) or 
     (string.match(url["host"], "^storage%.sketch%.sonymobile%.com") and status_code == 404) or
     (string.match(url["host"], "^sketch[-]cloud[-]storage%.s3%.amazonaws%.com") and status_code == 200) then

    return wget.actions.NOTHING
  end

  -- Unexpected result -> quit
  abortgrab = true
  return wget.actions.ABORT
end

-----------------------------------------------------------------------------------------------------------------------

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  io.stdout:write(table.show(code_counts,'\nResponse Code Frequency'))
  io.stdout:flush()

  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end

-----------------------------------------------------------------------------------------------------------------------
