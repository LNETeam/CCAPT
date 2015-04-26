--Developed by LNETeam
local tArgs = {...}
local bypass = false
if (#tArgs == 3) then
    if (tArgs[3] == "--suppress") then
        bypass = true
    end
end
local noPrompt = false
local actions = {}
local iLink = ""
local data = ""
local reg = {}
local info = {}
local color = term.isColor() and true or false
local author,version = ""
local repoAddr = "http://104.131.36.207"

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end


function collectBase(master)
    local base = {}
    for k,v in pairs(master) do
        local file = fs.open(v,"r")
        local data = ""
        if (not pcall(function() data = file.readAll() end)) then
            file.close()
            error("File read failed!")
        end
        file.close()
        base[v] = enc(data)
    end
    return base
end

function checkTamper(tab1)
    for k,v in pairs(tab1) do
        if (v ~= ".apt-get_ver" and v~= "info") then
            local dat = collectBase({v})

            if (masterData[v] ~= dat[v]) then
                if (color) then term.setTextColor(colors.red) end
                term.write("File changed: "..v.."! Cache original?[Y/n]: ")
                input = read()
                if (color) then term.setTextColor(colors.white) end
                if (input == "Y" or input == "y" or input == "") then
                    fs.makeDir(".cachedFiles")
                    local file = fs.open(".cachedFiles/"..v,"w")
                    file.write(dec(masterData[v]))
                    file.close()
                end
            end
        end
    end
end

function table.isEqual(tab1,tab2)
    if (#tab1 ~= #tab2) then return false end
    for k,v in pairs(tab1) do
        if (v ~= tab2[k]) then
            error(v..tab2[k])
            return false
        end
    end
    return true
end

function table.compareStructure(tab1,tab2)
    local newFiles = {}
    local removedFiles = {}
    for k,v in pairs(tab2) do
        local found = false
        for m,p in pairs(tab1) do
            if (v==p) then found = true break end
        end
        if (not found) then
            table.insert(newFiles,v) 
        end
    end
    for k,v in pairs(tab1) do
        local found = false
        for m,p in next , tab2 do
            if (v==p) then found = true break end
        end
        if (not found) then table.insert(removedFiles,v) end
    end
    return #newFiles or 0,#removedFiles or 0,newFiles or {},removedFiles or {}
end

local registry = 
{
    AddKeyValue = function(self,installVal)
        table.insert(self.keys,installVal)
    end,
    AddData = function(self,dat)
        self.keys = dat
    end,
}

local function newRegistry(existing)
    local temp = 
    {
        keys = {},z
    }
    setmetatable(temp,{__index = registry})
    return temp
end

function writeFile(stuf)
    file = io.open("info",'w')
    file:write(stuf)
    file:close()
end

---------------------------------------------------------------------------------
-- Runs an analysis of prior file structure, taking note of added/removed files
---------------------------------------------------------------------------------
local masterTable = {} --Holds all files/directories prior to running any package operations (removed from _G to prevent tampering of pre/post-action)
local total = 0
local function analyze(directory,tab)
    mindex = {}
    if (tab ~= nil) then mindex = tab end
    for v,k in pairs(fs.list(directory)) do
        if (not fs.isDir(fs.combine(directory,k))) then
            total = total + fs.getSize(fs.combine(directory,k))
            table.insert(mindex,fs.combine(directory,shell.resolve(k)))
        elseif (fs.isDir(fs.combine(directory,k)) and not fs.isReadOnly(k)) then
            --print("directory:"..k)
            mindex = analyze(fs.combine(directory,k),mindex)
        end
    end
    return mindex
end

masterTable = analyze("/")
masterData = {}
writeFile(textutils.serialize(masterData))
print("Total Size: "..(total/1000)..(((total/1000)>=1) and "kb" or "bytes"))


local function prepareKey(dat)
    local re = {}
    re.Dependencies = dat.Dependencies
    re.Name = tArgs[2]
    re.InstallHierarchy = dat.InstallHierarchy
    re.Author = author
    re.Version = version
    return re
end

local function newKeyItem(val)
    local temp = 
    {
        items = val,
        time = 0,
    }
    return temp
end

if (fs.exists("/.apt-get_ver")) then 
    local handle = fs.open("/.apt-get_ver","r")
    local existingKey = handle.readAll()
    existingKey = string.gsub(existingKey,"\\","")
    handle.close()
    if (string.len(existingKey) > 0) then
      reg = newRegistry()
    end
    reg:AddData(textutils.unserialize(existingKey))
else
    reg = newRegistry()
end

--if (#tArgs~=2 ) then
 --   print("Usage: apt-get {install/remove/update} {package} [-np]") 
 --   error()
--end

--if (#tArgs==3 and tArgs[3] == "-np") then noPrompt = true end

term.write("Checking http...")
function check()
    if (not http) then
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
        error({code=404})
    else
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
end
check()

term.write("Checking repo...")
function repo()
    local headers = 
    {
      ["stat"] = "http_test"
    }
    http.request(repoAddr.."/repo.php",nil,headers)
    requesting = true
    while requesting do
        local event, url, sourceText = os.pullEvent()
  
        if event == "http_success" then
            local respondedText = sourceText.readAll()
    
            sourceText.close()
            if (color) then term.setTextColor(colors.green) end
            print("  [OK]")
            if (color) then term.setTextColor(colors.white) end
    
            requesting = false
        elseif event == "http_failure" then
            if (color) then term.setTextColor(colors.red) end
            print("  [ERROR]")
            if (color) then term.setTextColor(colors.white) end
            error(textutils.serialize({code=404}))
        end
    end
end
repo()

if (tArgs[1] == "install") then mode = "install" end
if (tArgs[1] == "remove") then mode = "remove" end
if (tArgs[1] == "update") then mode = "update" end
if (tArgs[1] == "upgrade") then mode = "upgrade" end
if (tArgs[1] == "clean") then fs.delete(".cachedFiles") print("Done!\n") error() end



if (mode == "install") then --Install
    masterData = collectBase(masterTable)
    for k,v in ipairs(reg.keys) do
        for i,p in pairs(v) do
            if (p==tArgs[2]) then
                term.write("Package already installed!")
                if (color) then term.setTextColor(colors.green) end
                    print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
                error()
            end
        end
    end
    term.write("Locating package: "..tArgs[2].."...")
    function locate()
        local headers = 
        {
          ["pack"] = tArgs[2]
        }
        http.request(repoAddr.."/repo.php?pack="..tArgs[2])
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                info = sourceText.readAll()
                if (info == "none") then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR]")
                    if (color) then term.setTextColor(colors.white) end
                    print("No package '"..tArgs[2].."' found!")
                    error()
                end
                info = string.gsub(info,"\\","")
                
                info = textutils.unserialize(info)
                iLink = info[1]
                author = info[2]
                version = info[3]
                sourceText.close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
                requesting = false
                error()
            end
        end
    end
    locate()
    
    term.write("Resolving package from: "..iLink)
    function resolve()
        http.request(iLink)
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                data = sourceText.readAll()
                sourceText.close()
                if (string.len(data) == 0) then
                    error()
                end
                data = string.gsub(data,"\\","")
                local i = loadstring(data)
                if (i==nil) then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR] [NIL]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
                actions = i()
                if (not actions or not actions.Dependencies or not actions.InstallHierarchy) then
                    if (color) then term.setTextColor(colors.red) end
                    print(" [ERROR] [PKG Fail]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
        
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
                return
            end
        end
    end
    resolve()
    if (actions.PreAction ~= nil) then 
        if (not bypass) then
            term.write("This package has a pre-action. Execute?[Y/n]: ")
            local i = read()
            if (i=="n" or i=="N") then
                print("Skipping pre-action.")
            else
                print("Running pre action")
                actions.PreAction()
            end
        end
        comp = analyze("/")

        if (not table.isEqual(masterTable,comp)) then 
            local numA,numR = table.compareStructure(masterTable,comp)
            print(numA.." new files detected, "..numR.." files removed")
        end
    end
    local stat,err = pcall(function()
        if (#actions.Dependencies > 0) then
            for k,v in ipairs(actions.Dependencies) do
                print("Getting dependency: "..v)
                shell.run("apt-get install "..v) 
            end
        end
    end)
    
    if stat then
        term.write("Done indexing dependencies... ")
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    else
        term.write("Done indexing dependencies... ")
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
    end
    
    fs.makeDir("/~tmp")
    
    term.write("Creating temporary directory... ")
    local function temp()
        if (not fs.exists("/~tmp")) then
            fs.makeDir("/~tmp")
            if (color) then term.setTextColor(colors.green) end
            print("  [OK]")
            if (color) then term.setTextColor(colors.white) end
            requesting = false
        else
            if (color) then term.setTextColor(colors.green) end
            print(" [OK]")
            if (color) then term.setTextColor(colors.white) end
        end
    end
    temp()
    
    local isPastebin = false
    if (string.find(iLink,"pastebin")) then
        isPastebin = true
    end
    
    
    print("Getting package files... ")
    local function get()
        if (not isPastebin) then
        	local finlink = false
            for k,v in pairs(actions.InstallHierarchy) do
                if (string.find(v[1],"/") ~= 1) then
                    v[1] = "/"..v[1] 
                end
                local idx = string.find(iLink, "/[^/]*$")
                if (finlink == false) then
               		 iLink = string.sub(iLink,0,idx-1)
               		 finlink = true
            	end
                local url = iLink..v[1] 
                http.request(url)
                requesting = true
                dat = "";
                term.write(v[1])
                while requesting do
                    local event, url, sourceText = os.pullEvent()
                    if event == "http_success" then
                        dat = sourceText.readAll()
                        sourceText.close()            
                        requesting = false
                    elseif event == "http_failure" then
                        if (color) then term.setTextColor(colors.red) end

                        print("  [ERROR] "..url)
                        if (color) then term.setTextColor(colors.white) end
                        error()
                        requesting = false
                    end
                end
                local handle = io.open(v[2],'w')
                handle:write(dat)
                handle:close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            end
        else
            
            local s,err = pcall(
                function() 
                    for k,v in ipairs(actions.InstallHierarchy) do
                    shell.run("pastebin","get",v[1],v[2])
                    end 
            end)
            if (s) then
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            else
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
                error()
            end
        end
    end
    get()
    
    term.write("Adding package to registry... ")
    local function add()
        local key = newKeyItem(actions)
        reg:AddKeyValue(prepareKey(actions))
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
    add()
    
    term.write("Cleaning up files... ")
    local function clean()
        if (fs.exists("/~tmp")) then
            fs.delete("/~tmp") 
        end
        if (fs.exists(".apt-get_ver")) then
            fs.delete(".apt-get_ver") 
        end
        local handle = io.open(".apt-get_ver",'w')
        handle:write(textutils.serialize(reg.keys))
        handle:close()
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
    clean()

    if (actions.PostAction ~= nil) then
        if (not bypass) then
            term.write("This package has a post-action. Execute?[Y/n]: ")
            local i = read()
            if (i=="n" or i=="N") then
                print("Skipping post-action.")
            else
                print("Running post action")
                sleep(1)
                actions.PostAction()
            end
        end
    end
    comp = analyze("/")

    --writeFile(textutils.serialize(masterTable).."\n"..textutils.serialize(comp))

    if (not table.isEqual(masterTable,comp)) then 
        local numA,numR = table.compareStructure(masterTable,comp)
        print(numA.." new file(s) detected, "..numR.." file(s) removed")
    end
    checkTamper(masterTable)
    print("Done!\n")
elseif (mode == "remove") then --Remove
    local found = false
    local tab = {}
    for k,v in ipairs(reg.keys) do
        for i,p in pairs(v) do
            if (p==tArgs[2]) then
                found = true
                tab = v
            end
        end
    end
    if (not found) then
        term.write("Package not installed. Removed:0")
        if (color) then term.setTextColor(colors.red) end
            print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
        error()
    end
    term.write("Removing files... ")
    function remove()
        for k,v in ipairs(tab.InstallHierarchy) do
            fs.delete(v[2])
        end
    end
    local stat,err = pcall(remove)
    if (stat) then
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    else
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
    end
    term.write("Cleaning registry... ")
    function cleanReg()
        local r = {}
        for k,v in ipairs(reg.keys) do
            if (v ~= tab) then
                table.insert(r,v)
            end
        end
        reg.keys = r
        fs.delete("/.apt-get_ver")
        local handle = io.open(".apt-get_ver",'w')
        handle:write(textutils.serialize(reg.keys))
        handle:close()
    end
    local stat,err = pcall(cleanReg)
    if (stat) then
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    else
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
    end
    print("Done!\n")
elseif (mode == "update") then --Update                                                              UPDATE
    local found = false
    local tab = {}
    for k,v in ipairs(reg.keys) do
        for i,p in pairs(v) do
            if (p==tArgs[2]) then
                found = true
                tab = v
            end
        end
    end
    if (not found) then
        term.write("Package not installed. Updated:0")
        if (color) then term.setTextColor(colors.red) end
            print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
        error()
    end
    
    term.write("Locating package: "..tArgs[2].."...")
    function locate()
        local headers = 
        {
          ["pack"] = tArgs[2]
        }
        http.request(repoAddr.."/repo.php?pack="..tArgs[2])
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                info = sourceText.readAll()
                if (info == "none") then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR]")
                    if (color) then term.setTextColor(colors.white) end
                    print("No package '"..tArgs[2].."' found!")
                    error()
                end
                info = string.gsub(info,"\\","")

                inf = textutils.unserialize(info)
                writeFile(info)
                iLink = inf[1]
                author = inf[2]
                version = inf[3]
                sourceText.close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
                requesting = false
                error()
            end
        end
    end
    locate()
    if (tab.Version == version) then
        term.write("Package up to date.")
        if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
        print("Done!\n")
        error()
    end

    term.write("Removing files... ")
    function remove()
        for k,v in ipairs(tab.InstallHierarchy) do
            fs.delete(v[2])
        end
    end
    local stat,err = pcall(remove)
    if (stat) then
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    else
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
    end

    print("Updating package: "..tArgs[2].." to: "..version)

    term.write("Resolving package from: "..iLink)
    function resolve()
        http.request(iLink)
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                data = sourceText.readAll()
                sourceText.close()
                if (string.len(data) == 0) then
                    error()
                end
                data = string.gsub(data,"\\","")
                local i = loadstring(data)
                if (i==nil) then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
                actions = i()
                if (not install or not install.Dependencies or not install.InstallHierarchy) then
                if (color) then term.setTextColor(colors.red) end
                    print(" [ERROR]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
        
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
                return
            end
        end
    end
    resolve()
    --parallel.waitForAny(spool(),function() 
        
    --end)
    
    
    if (actions.PreAction ~= nil) then 
        if (not bypass) then
            term.write("This package has a pre-action. Execute?[Y/n]: ")
            local i = read()
            if (i=="n" or i=="N") then
                return
            end
        end

        print("Running pre action...")
        if (not actions.PreAction()) then return end
    end
    
    if (#actions.Dependencies > 0) then
        for k,v in ipairs(actions.Dependencies) do
            print("Getting dependency: "..v)
            shell.run(shell.getRunningProgram().." install "..v) 
        end
    end
    
    print("Done indexing dependencies...  [OK]")
    
    
    fs.makeDir("/~tmp")
    
    term.write("Creating temporary directory... ")
    function temp()
        if (not fs.exists("/~tmp")) then
            fs.makeDir("/~tmp")
            if (color) then term.setTextColor(colors.green) end
            print("  [OK]")
            if (color) then term.setTextColor(colors.white) end
            requesting = false
        else
            if (color) then term.setTextColor(colors.green) end
            print(" [OK]")
            if (color) then term.setTextColor(colors.white) end
        end
    end
    temp()
    --parallel.waitForAny(spool(),function() 
        
    --end)
    
    term.write("Getting package files... ")
    local function get()
        if (not isPastebin) then
            local finlink = false
            for k,v in pairs(actions.InstallHierarchy) do
                if (string.find(v[1],"/") ~= 1) then
                    v[1] = "/"..v[1] 
                end
                local idx = string.find(iLink, "/[^/]*$")
                if (finlink == false) then
                     iLink = string.sub(iLink,0,idx-1)
                     finlink = true
                end
                local url = iLink..v[1] 
                http.request(url)
                requesting = true
                dat = "";
                while requesting do
                    local event, url, sourceText = os.pullEvent()
                    if event == "http_success" then
                        dat = sourceText.readAll()
                        sourceText.close()            
                        requesting = false
                    elseif event == "http_failure" then
                        if (color) then term.setTextColor(colors.red) end

                        print("  [ERROR]")
                        if (color) then term.setTextColor(colors.white) end
                        error()
                        requesting = false
                    end
                end
                local handle = io.open(v[2],'w')
                handle:write(dat)
                handle:close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            end
        else
            
            local s,err = pcall(
                function() 
                    for k,v in ipairs(actions.InstallHierarchy) do
                    shell.run("pastebin","get",v[1],v[2])
                    end 
            end)
            if (s) then
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            else
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
                error()
            end
        end
    end
    get()
    --parallel.waitForAny(spool(),function() 
        
    --end)
    
    term.write("Adding package to registry... ")
    function add()
        local r = {}
        for k,v in ipairs(reg.keys) do
            if (v ~= tab) then
                table.insert(r,v)
            end
        end
        reg.keys = r
        fs.delete("/.apt-get_ver")
        local handle = io.open(".apt-get_ver",'w')
        handle:write(textutils.serialize(reg.keys))
        handle:close()
        local key = newKeyItem(actions)
        reg:AddKeyValue(prepareKey(actions))
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
    add()
    --parallel.waitForAny(spool(),function() 
        
    --end)

    term.write("Cleaning up files... ")
    function clean()
        if (fs.exists("/~tmp")) then
            fs.delete("/~tmp") 
        end
        if (fs.exists(".apt-get_ver")) then
            fs.delete(".apt-get_ver") 
        end
        local handle = io.open(".apt-get_ver",'w')
        handle:write(textutils.serialize(reg.keys))
        handle:close()
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
    clean()
    --parallel.waitForAny(spool(),function() 
        
    --end)
    
    if (actions.PostAction ~= nil) then
        if (not bypass) then
            term.write("This package has a post-action. Execute?[Y/n]: ")
            local i = read()
            if (i=="n" or i=="N") then
                return
            end
        end

        print("Running post action")
        sleep(2)
        actions.PostAction()
    end

    print("Done!\n")
elseif (mode == "list") then --not working
    term.clear()
    term.setCursorPos(1,1)
    i = 0
    local out = {}
    t = #out
    c=0
    local buffer = {}
    local width,height = term.getSize()
    table.insert(out,"List of packages: ")
    for k,v in ipairs(reg.keys) do
        print()
        for i,p in pairs(v) do
            if (type(p)~="table") then
                table.insert(out,i..":"..p)
            else
                table.insert(out,i..":"..textutils.serialize(p))
            end
        end
    end
    term.clear()
    term.setCursorPos(1,1)
    while true do
        table.insert(buffer,out[1])
        table.insert(buffer,out[2])
        for m=0,19,1 do
            --table.insert(buffer,out[m])
        end
        writeFile(textutils.serialize(buffer))
        for k,v in pairs(buffer) do
            print(v)
        end
        buffer = {}
        local _,scroll = os.pullEvent("mouse_scroll")

        if (scroll==1 and c~=t) then
            i = i + 1
            t = t + 1
            --term.scroll(i)
            i=0
            c = c+1
        elseif (scroll==-1 and c ~= 1) then
            i = i - 1
            t = t - 1 
            --term.scroll(i)
            i=0
            c = c- 1
        end
        term.clear()
        term.setCursorPos(1,1)
        sleep(.1)
    end
elseif (mode == "upgrade") then
    tArgs[2] = "ccapt"
    print("Upgrading APT...")
    term.write("Locating package: "..tArgs[2].."...")
    function locate()
        local headers = 
        {
          ["pack"] = "ccapt"
        }
        http.request(repoAddr.."/repo.php?pack="..tArgs[2])
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                info = sourceText.readAll()
                if (info == "none") then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR]")
                    if (color) then term.setTextColor(colors.white) end
                    print("No package '"..tArgs[2].."' found!")
                    error()
                end
                info = string.gsub(info,"\\","")
                
                info = textutils.unserialize(info)
                iLink = info[1]
                author = info[2]
                version = info[3]
                sourceText.close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
                requesting = false
                error()
            end
        end
    end
    locate()
    
    term.write("Resolving package from: "..iLink)
    function resolve()
        http.request(iLink)
        requesting = true
        while requesting do
            local event, url, sourceText = os.pullEvent()
      
            if event == "http_success" then
                data = sourceText.readAll()
                sourceText.close()
                if (string.len(data) == 0) then
                    error()
                end
                data = string.gsub(data,"\\","")
                local i = loadstring(data)
                if (i==nil) then
                    if (color) then term.setTextColor(colors.red) end
                    print("  [ERROR] [NIL]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
                actions = i()
                if (not actions or not actions.Dependencies or not actions.InstallHierarchy) then
                    if (color) then term.setTextColor(colors.red) end
                    print(" [ERROR] [PKG Fail]")
                    if (color) then term.setTextColor(colors.white) end
                    error()
                end
        
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
            elseif event == "http_failure" then
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
        
                requesting = false
                return
            end
        end
    end
    resolve()
    
    if (actions.PreAction ~= nil) then 
        print("Running pre action...")
        actions.PreAction()
        --if (not actions.PreAction()) then return end
    end
    local stat,err = pcall(function()
        if (#actions.Dependencies > 0) then
            for k,v in ipairs(actions.Dependencies) do
                print("Getting dependency: "..v)
                shell.run("apt-get install "..v) 
            end
        end
    end)
    
    if stat then
        term.write("Done indexing dependencies... ")
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    else
        term.write("Done indexing dependencies... ")
        if (color) then term.setTextColor(colors.red) end
        print("  [ERROR]")
        if (color) then term.setTextColor(colors.white) end
    end
    
    fs.makeDir("/~tmp")
    
    term.write("Creating temporary directory... ")
    local function temp()
        if (not fs.exists("/~tmp")) then
            fs.makeDir("/~tmp")
            if (color) then term.setTextColor(colors.green) end
            print("  [OK]")
            if (color) then term.setTextColor(colors.white) end
            requesting = false
        else
            if (color) then term.setTextColor(colors.green) end
            print(" [OK]")
            if (color) then term.setTextColor(colors.white) end
        end
    end
    temp()
    
    local isPastebin = false
    if (string.find(iLink,"pastebin")) then
        isPastebin = true
    end
    
    
    term.write("Getting package files... ")
    local function get()
        if (not isPastebin) then
            local finlink = false
            for k,v in pairs(actions.InstallHierarchy) do
                if (string.find(v[1],"/") ~= 1) then
                    v[1] = "/"..v[1] 
                end
                local idx = string.find(iLink, "/[^/]*$")
                if (finlink == false) then
                     iLink = string.sub(iLink,0,idx-1)
                     finlink = true
                end
                local url = iLink..v[1] 
                http.request(url)
                requesting = true
                dat = "";
                while requesting do
                    local event, url, sourceText = os.pullEvent()
                    if event == "http_success" then
                        dat = sourceText.readAll()
                        sourceText.close()            
                        requesting = false
                    elseif event == "http_failure" then
                        if (color) then term.setTextColor(colors.red) end

                        print("  [ERROR] "..url)
                        if (color) then term.setTextColor(colors.white) end
                        error()
                        requesting = false
                    end
                end
                local handle = io.open(v[2],'w')
                handle:write(dat)
                handle:close()
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            end
        else
            
            local s,err = pcall(
                function() 
                    for k,v in ipairs(actions.InstallHierarchy) do
                    shell.run("pastebin","get",v[1],v[2])
                    end 
            end)
            if (s) then
                if (color) then term.setTextColor(colors.green) end
                print("  [OK]")
                if (color) then term.setTextColor(colors.white) end
            else
                if (color) then term.setTextColor(colors.red) end
                print("  [ERROR]")
                if (color) then term.setTextColor(colors.white) end
                error()
            end
        end
    end
    get()
    
    term.write("Cleaning up files... ")
    local function clean()
        if (fs.exists("/~tmp")) then
            fs.delete("/~tmp") 
        end
        if (fs.exists(".apt-get_ver")) then
            fs.delete(".apt-get_ver") 
        end
        local handle = io.open(".apt-get_ver",'w')
        handle:write(textutils.serialize(reg.keys))
        handle:close()
        if (color) then term.setTextColor(colors.green) end
        print("  [OK]")
        if (color) then term.setTextColor(colors.white) end
    end
    clean()
    
    if (actions.PostAction ~= nil) then
        print("Running post action...")
        local stat,err = pcall(actions.PostAction)
        if not stat then error("Prob:"..err) end
    end

    print("Done!\n")
end

function IndexProgram(pname) --API
    if (fs.exists(".apt-get_ver")) then
        local handle = io.open(".apt-get_ver","r")
        local dat = handle:read("*")
        handle:close()
        local tReg = textutils.unserialize(dat)
        for k,v in pairs(tReg) do
            if (v.Name == pname) then
                return v
            end
        end
    else
        return nil 
    end
end
