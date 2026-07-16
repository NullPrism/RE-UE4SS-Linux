local PREFIX = "[NullPrismRepeatedStartupShutdown]"
local callback_seen = false

local function log(message)
    print(PREFIX .. " " .. message .. "\n")
end

local function fail(message)
    log(message)
    log("RESULT=FAIL")
    log("startup complete")
end

log("main.lua loaded")

if type(RegisterInitGameStatePostHook) ~= "function" then
    fail("RegisterInitGameStatePostHook unavailable")
    return
end

local registration_ok, registration_error = pcall(function()
    RegisterInitGameStatePostHook(function(ContextParameter)
        if callback_seen then
            log("additional InitGameState callback ignored")
            return
        end

        callback_seen = true
        log("InitGameState post-hook fired")

        local unwrap_ok, context = pcall(function()
            return ContextParameter:get()
        end)

        if not unwrap_ok then
            fail("context unwrap FAILED: " .. tostring(context))
            return
        end

        if context == nil or not context:IsValid() then
            fail("context is invalid")
            return
        end

        log("context full name=" .. tostring(context:GetFullName()))
        log("context address=" .. string.format("0x%X", context:GetAddress()))
        log("RESULT=PASS")
        log("startup complete")
    end)
end)

if not registration_ok then
    fail("hook registration FAILED: " .. tostring(registration_error))
    return
end

log("InitGameState post-hook registered")
