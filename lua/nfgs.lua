require("subprocess_plugin")

__SUBPROCESS = __SUBPROCESS or {}
for i, v in pairs(__SUBPROCESS) do
    v:kill()
end

function initNode(path, options, bindingObjects)
    options = options or {}
    options.commandLineArguments = options.commandLineArguments or {}
    if(options.debugPort) then
        table.insert(options.commandLineArguments, "--inspect-brk=" .. options.debugPort)
    end
    local cmdArg = table.concat(options.commandLineArguments, " ")
    if(cmdArg ~= "") then
        cmdArg = cmdArg .. " ";
    end
    local returnObj = {
        listeners = {},
        exceptionListeners = {},
        ptr = ___SUBPROCESS___WRAPPER___TABLE___.instantiate("node " .. cmdArg .. path),
        running = true,
    }
    __SUBPROCESS[returnObj.ptr] = returnObj;
    hook.Add("Tick", returnObj.ptr, function()
        if(returnObj.running) then
            returnObj:think();
        end
    end)
    function returnObj:addListener(key, func)
        self.listeners[key] = self.listeners[key] or {}
        table.insert(self.listeners[key], func)
    end
    function returnObj:listen(key, func)
        self:addListener(key, func)
    end
    function returnObj:addExceptionListerner(key, func)
        self.exceptionListeners[key] = self.exceptionListeners[key] or {}
        table.insert(self.exceptionListeners[key], func)
    end
    function returnObj:exceptionListen(key, func)
        self:addExceptionListerner(key, func)
    end
    function returnObj:removeListener(key, func)
        table.remove(self.listeners[key], func)
    end
    function returnObj:think()
        local nodeCommands = ___SUBPROCESS___WRAPPER___TABLE___.think(self.ptr);
        if(nodeCommands == nil) then
            return nil;
        end
        if(nodeCommands == false) then
            self.running = false;
            return false;
        end
        for _, v in pairs(nodeCommands) do
            print(v)
            local command = util.JSONToTable(v)
            if(!command) then
              ErrorNoHalt("Unknown command? " .. v .. "\n")
              
              continue
            end
            if(command.command == "exception") then
                local listeners = self.exceptionListeners[command.eventName] or {}
                for _, f in pairs(listeners) do
                    f(command.data)
                end 
                if(command.eventName == "crash") then
                    self.running = false;
                    if(options.debug) then
                        print("process "..path.." stopped running")
                    end
                end
            end
            if(command.command == "event") then
                local listeners = self.listeners[command.eventName] or {}
                for _, f in pairs(listeners) do
                    f(command.data)
                end 

            end
            if(command.command == "print" and options.debug) then
                if (type(command.data) == "table" and PrintTable) then
                  PrintTable(command.data)
                else
                  print(command.data)
                end
            end
            if(command.command == "exception") then
                if (options.debug) then
                  print(command.eventName + " happened: " + command.data)
                end
                
                if(command.eventName == "uncaughtException") then
                    self:kill()
                end
            end
            if(command.command == "get/set/call") then
                local data = command.data
                local index = tonumber(data.index)
                local pathResult = nil
                if(index == -1) then
                    pathResult = _G
                else 
                    pathResult = bindingObjects[index + 1]
                end
                local path = data.path
                local action = data.action
                local exception = nil
                for i, v in ipairs(path) do
                    if(pathResult == nil) then
                        exception = "could not find property "..v.." on nil"
                        break;
                    end
                    pathResult = pathResult[v]
                end
            
                if(exception == nil) then
                    local res = nil
                    if(action:sub(0, 3) == "get") then
                        print("get")
                        res = pathResult
                    elseif(action:sub(0, 4) == "set=") then
                        print("set")
                        pathResult = action:sub(4, action:len())
                    elseif(action:sub(0, 5) == "call(") then
                        print("call")
                        if(type(pathResult)=="function") then
                            res = pathResult(util.JSONToTable(action:sub(5, action:len() - 1)))
                        else
                            res = pathResult
                        end
                    end 
                    print(res)
                    ___SUBPROCESS___WRAPPER___TABLE___.send(self.ptr, util.TableToJSON({
                        command = "get/set/call",
                        eventName = index.."",
                        data = res
                    }))
                else
                    print(exception)
                    ___SUBPROCESS___WRAPPER___TABLE___.send(self.ptr, util.TableToJSON({
                        command = "get/set/call",
                        eventName = index.."",
                        data = {
                            ___exception = exception
                        }
                    }))
                end
            end
        end
        return true
    end
    function returnObj:kill()
        running = false
        hook.Remove("Tick", returnObj.ptr)
        ___SUBPROCESS___WRAPPER___TABLE___.kill(self.ptr)
    end
    function returnObj:send(key, data)
        ___SUBPROCESS___WRAPPER___TABLE___.send(self.ptr, util.TableToJSON({
            command = "event",
            eventName = key,
            data = data
        }))
    end
    return returnObj;
end