dofile("table_show.lua")
dofile("urlcode.lua")
JSON = (loadfile "JSON.lua")()

local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

local posts = {}
local requested_children = {}
local outlinks = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end


wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  -- storage.sketch
  if (string.match(url["host"], "^storage\.sketch\.sonymobile\.com") and status_code == 307) then
    return wget.actions.NOTHING
  end

  -- storage.sketch
  if (string.match(url["host"], "^storage\.sketch\.sonymobile\.com") and status_code == 404) then
    return wget.actions.EXIT
  end

  -- AWS S3
  if (string.match(url["host"], "^sketch[-]cloud[-]storage\.s3\.amazonaws\.com") and status_code == 200) then
    return wget.actions.EXIT
  end

  abortgrab = true
  return wget.actions.ABORT
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end
