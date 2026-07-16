local PREFIX = "[NullPrismReflectedUFunction]"
local callback_seen = false

local function log(message)
    print(PREFIX .. " " .. message .. "\n")
end

local candidates = {
    {
        name = "GetActorTimeDilation",
        expected_type = "number",
    },
    {
        name = "GetGameTimeSinceCreation",
        expected_type = "number",
    },
    {
        name = "GetActorTickInterval",
        expected_type = "number",
    },
    {
        name = "IsActorTickEnabled",
        expected_type = "boolean",
    },
    {
        name = "HasAuthority",
        expected_type = "boolean",
    },
}

local function resolve_candidate(context, candidate)
    local read_ok, callable = pcall(function()
        return context[candidate.name]
    end)

    if not read_ok then
        log(
            "candidate "
                .. candidate.name
                .. " lookup FAILED: "
                .. tostring(callable)
        )

        return nil
    end

    local lua_type = type(callable)

    log(
        "candidate "
            .. candidate.name
            .. " Lua type="
            .. lua_type
    )

    if lua_type == "function" then
        log(
            "candidate "
                .. candidate.name
                .. " resolution=callable function"
        )

        return callable
    end

    if lua_type ~= "userdata" then
        log(
            "candidate "
                .. candidate.name
                .. " resolution=unsupported Lua type"
        )

        return nil
    end

    local valid_ok, is_valid = pcall(function()
        return callable:IsValid()
    end)

    if not valid_ok then
        log(
            "candidate "
                .. candidate.name
                .. " IsValid FAILED: "
                .. tostring(is_valid)
        )

        return nil
    end

    log(
        "candidate "
            .. candidate.name
            .. " userdata IsValid="
            .. tostring(is_valid)
    )

    if not is_valid then
        log(
            "candidate "
                .. candidate.name
                .. " resolution=missing reflected function"
        )

        return nil
    end

    local full_name_ok, full_name = pcall(function()
        return callable:GetFullName()
    end)

    if full_name_ok then
        log(
            "candidate "
                .. candidate.name
                .. " full name="
                .. tostring(full_name)
        )
    else
        log(
            "candidate "
                .. candidate.name
                .. " GetFullName unavailable: "
                .. tostring(full_name)
        )
    end

    log(
        "candidate "
            .. candidate.name
            .. " resolution=valid callable userdata"
    )

    return callable
end

log("main.lua loaded")

if type(RegisterInitGameStatePostHook) ~= "function" then
    log(
        "registration FAILED: "
            .. "RegisterInitGameStatePostHook unavailable"
    )
    log("RESULT=FAIL")
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
            log("context unwrap FAILED: " .. tostring(context))
            log("RESULT=FAIL")
            return
        end

        if context == nil or not context:IsValid() then
            log("context invalid")
            log("RESULT=FAIL")
            return
        end

        log("context full name=" .. context:GetFullName())
        log(
            "context address="
                .. string.format("0x%X", context:GetAddress())
        )

        local property_ok, custom_time_dilation = pcall(function()
            return context.CustomTimeDilation
        end)

        if property_ok then
            log(
                "CustomTimeDilation property="
                    .. tostring(custom_time_dilation)
            )
        else
            log(
                "CustomTimeDilation property read FAILED: "
                    .. tostring(custom_time_dilation)
            )
        end

        local selected_candidate = nil
        local selected_callable = nil

        for _, candidate in ipairs(candidates) do
            local callable = resolve_candidate(context, candidate)

            if callable ~= nil and selected_callable == nil then
                selected_candidate = candidate
                selected_callable = callable
            end
        end

        if selected_callable == nil then
            log("no reflected getter candidate resolved")
            log("RESULT=FAIL")
            log("test completed")
            return
        end

        log(
            "selected function="
                .. selected_candidate.name
        )

        -- The reflected UFunction object already retains its UObject context.
        -- Do not pass context again as an explicit argument.
        local invoke_ok, return_value = pcall(function()
            return selected_callable()
        end)

        if not invoke_ok then
            log(
                "invocation FAILED: "
                    .. tostring(return_value)
            )
            log("RESULT=FAIL")
            log("test completed")
            return
        end

        local return_type = type(return_value)

        log("invocation completed")
        log("return Lua type=" .. return_type)
        log("return value=" .. tostring(return_value))
        log(
            "expected Lua type="
                .. selected_candidate.expected_type
        )

        if return_type ~= selected_candidate.expected_type then
            log("return type verification=false")
            log("RESULT=FAIL")
            log("test completed")
            return
        end

        if return_type == "number" then
            local finite =
                return_value == return_value
                and return_value ~= math.huge
                and return_value ~= -math.huge

            log("numeric return finite=" .. tostring(finite))

            if not finite then
                log("RESULT=FAIL")
                log("test completed")
                return
            end
        end

        if selected_candidate.name == "GetActorTimeDilation"
            and property_ok
            and type(custom_time_dilation) == "number"
            and type(return_value) == "number" then

            log(
                "getter/property delta="
                    .. tostring(
                        math.abs(
                            return_value
                                - custom_time_dilation
                        )
                    )
            )
        end

        log("return type verification=true")
        log("RESULT=PASS")
        log("test completed")
    end)
end)

if not registration_ok then
    log("registration FAILED: " .. tostring(registration_error))
    log("RESULT=FAIL")
    return
end

log("InitGameState post-hook registered")
