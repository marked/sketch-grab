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

  if (status_code >= 300 and status_code <= 399) then
    local newloc = string.match(http_stat["newloc"], "^([^#]+)")
    if string.match(newloc, "^//") then
      newloc = string.match(url["url"], "^(https?:)") .. string.match(newloc, "^//(.+)")
    elseif string.match(newloc, "^/") then
      newloc = string.match(url["url"], "^(https?://[^/]+)") .. newloc
    elseif not string.match(newloc, "^https?://") then
      newloc = string.match(url["url"], "^(https?://.+/)") .. newloc
    end
    if downloaded[newloc] == true or addedtolist[newloc] == true then
      return wget.actions.EXIT
    end
  end
  
  if (status_code >= 200 and status_code <= 399) then
    downloaded[url["url"]] = true
    downloaded[string.gsub(url["url"], "https?://", "http://")] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    return wget.actions.ABORT
  end
  
  if status_code >= 500
      or (status_code >= 400 and status_code ~= 403 and status_code ~= 404)
      or status_code  == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    local maxtries = 8
    if not allowed(url["url"], nil) then
        maxtries = 2
    end
    if tries > maxtries then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if allowed(url["url"], nil) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end
