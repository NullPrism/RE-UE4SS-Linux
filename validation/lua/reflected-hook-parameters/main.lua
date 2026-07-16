local PREFIX = "[NullPrismReflectedHookParameters]"
local HOOK_PATH = "/Script/Engine.Actor:SetActorTickInterval"
local EPSILON = 0.000001

local init_callback_seen = false
local hook_registered = false
local hook_pre_id = nil
local hook_post_id = nil

local target_address = nil
local target_interval = nil

local hook_callback_count = 0
local matching_callback_seen = false
local callback_error_seen = false

local function log(message)
    print(PREFIX .. " " .. message .. "\n")
end

local function unregister_test_hook()
    if not hook_registered then
        return true
    end

    local unregister_ok, unregister_error = pcall(function()
        UnregisterHook(
            HOOK_PATH,
            hook_pre_id,
            hook_post_id
        )
    end)

    if unregister_ok then
        log("hook unregistered")
        hook_registered = false
        return true
    end

    log(
        "hook unregistration FAILED: "
            .. tostring(unregister_error)
    )

    return false
end

local function fail(message)
    log(message)

    if hook_registered then
        unregister_test_hook()
    end

    log("RESULT=FAIL")
    log("test completed")
end

local function describe_wrapper(label, wrapper)
    log(label .. " Lua type=" .. type(wrapper))

    if type(wrapper) ~= "userdata" then
        return
    end

    local wrapper_type_ok, wrapper_type = pcall(function()
        return wrapper:type()
    end)

    if wrapper_type_ok then
        log(
            label
                .. " wrapper type="
                .. tostring(wrapper_type)
        )
    else
        log(
            label
                .. " wrapper type unavailable: "
                .. tostring(wrapper_type)
        )
    end
end

local function reflected_pre_hook(
    ContextParameter,
    TickIntervalParameter
)
    hook_callback_count = hook_callback_count + 1

    local callback_ok, callback_error = pcall(function()
        log(
            "pre-hook fired count="
                .. tostring(hook_callback_count)
        )

        describe_wrapper(
            "context parameter",
            ContextParameter
        )

        describe_wrapper(
            "tick interval parameter",
            TickIntervalParameter
        )

        local context_unwrap_ok, hook_context = pcall(function()
            return ContextParameter:get()
        end)

        if not context_unwrap_ok then
            callback_error_seen = true

            log(
                "context parameter unwrap FAILED: "
                    .. tostring(hook_context)
            )

            return
        end

        local interval_unwrap_ok, hook_interval = pcall(function()
            return TickIntervalParameter:get()
        end)

        if not interval_unwrap_ok then
            callback_error_seen = true

            log(
                "tick interval parameter unwrap FAILED: "
                    .. tostring(hook_interval)
            )

            return
        end

        if hook_context == nil then
            callback_error_seen = true
            log("hook context is nil")
            return
        end

        local context_valid_ok, context_valid = pcall(function()
            return hook_context:IsValid()
        end)

        if not context_valid_ok or not context_valid then
            callback_error_seen = true

            log(
                "hook context validity="
                    .. tostring(context_valid)
            )

            return
        end

        local hook_address = hook_context:GetAddress()

        log(
            "hook context full name="
                .. tostring(hook_context:GetFullName())
        )

        log(
            "hook context address="
                .. string.format("0x%X", hook_address)
        )

        log(
            "hook interval Lua type="
                .. type(hook_interval)
        )

        log(
            "hook interval value="
                .. tostring(hook_interval)
        )

        if type(hook_interval) ~= "number" then
            callback_error_seen = true
            log("hook interval is not a Lua number")
            return
        end

        if target_address == nil or target_interval == nil then
            log("target values are not initialized")
            return
        end

        local context_matches =
            hook_address == target_address

        local interval_delta =
            math.abs(hook_interval - target_interval)

        local interval_matches =
            interval_delta <= EPSILON

        log(
            "context matches target="
                .. tostring(context_matches)
        )

        log(
            "interval delta="
                .. tostring(interval_delta)
        )

        log(
            "interval matches target="
                .. tostring(interval_matches)
        )

        if context_matches and interval_matches then
            matching_callback_seen = true
            log("matching pre-hook callback observed")
        else
            log("nonmatching pre-hook callback ignored")
        end
    end)

    if not callback_ok then
        callback_error_seen = true

        log(
            "pre-hook callback FAILED: "
                .. tostring(callback_error)
        )
    end
end

log("main.lua loaded")

if type(RegisterHook) ~= "function" then
    fail("RegisterHook unavailable")
    return
end

if type(UnregisterHook) ~= "function" then
    fail("UnregisterHook unavailable")
    return
end

if type(RegisterInitGameStatePostHook) ~= "function" then
    fail("RegisterInitGameStatePostHook unavailable")
    return
end

local registration_ok, registration_error = pcall(function()
    RegisterInitGameStatePostHook(function(ContextParameter)
        if init_callback_seen then
            log("additional InitGameState callback ignored")
            return
        end

        init_callback_seen = true
        log("InitGameState post-hook fired")

        local context_unwrap_ok, context = pcall(function()
            return ContextParameter:get()
        end)

        if not context_unwrap_ok then
            fail(
                "InitGameState context unwrap FAILED: "
                    .. tostring(context)
            )
            return
        end

        if context == nil or not context:IsValid() then
            fail("InitGameState context is invalid")
            return
        end

        target_address = context:GetAddress()

        log(
            "target context full name="
                .. tostring(context:GetFullName())
        )

        log(
            "target context address="
                .. string.format("0x%X", target_address)
        )

        local getter_lookup_ok, getter = pcall(function()
            return context.GetActorTickInterval
        end)

        if not getter_lookup_ok then
            fail(
                "GetActorTickInterval lookup FAILED: "
                    .. tostring(getter)
            )
            return
        end

        local setter_lookup_ok, setter = pcall(function()
            return context.SetActorTickInterval
        end)

        if not setter_lookup_ok then
            fail(
                "SetActorTickInterval lookup FAILED: "
                    .. tostring(setter)
            )
            return
        end

        log(
            "GetActorTickInterval Lua type="
                .. type(getter)
        )

        log(
            "SetActorTickInterval Lua type="
                .. type(setter)
        )

        if type(getter) ~= "userdata"
            or not getter:IsValid() then

            fail(
                "GetActorTickInterval did not resolve "
                    .. "as valid callable userdata"
            )

            return
        end

        if type(setter) ~= "userdata"
            or not setter:IsValid() then

            fail(
                "SetActorTickInterval did not resolve "
                    .. "as valid callable userdata"
            )

            return
        end

        local getter_call_ok, original_interval = pcall(function()
            return getter()
        end)

        if not getter_call_ok then
            fail(
                "initial tick interval read FAILED: "
                    .. tostring(original_interval)
            )
            return
        end

        if type(original_interval) ~= "number" then
            fail(
                "initial tick interval is not a Lua number: "
                    .. type(original_interval)
            )
            return
        end

        target_interval = original_interval

        log(
            "original tick interval="
                .. tostring(target_interval)
        )

        local hook_registration_ok
        local pre_id
        local post_id

        hook_registration_ok, pre_id, post_id = pcall(function()
            return RegisterHook(
                HOOK_PATH,
                reflected_pre_hook
            )
        end)

        if not hook_registration_ok then
            fail(
                "RegisterHook FAILED: "
                    .. tostring(pre_id)
            )
            return
        end

        hook_pre_id = pre_id
        hook_post_id = post_id
        hook_registered = true

        log(
            "hook pre ID="
                .. tostring(hook_pre_id)
        )

        log(
            "hook post ID="
                .. tostring(hook_post_id)
        )

        if type(hook_pre_id) ~= "number"
            or type(hook_post_id) ~= "number" then

            fail("RegisterHook returned invalid hook IDs")
            return
        end

        log(
            "invoking SetActorTickInterval with existing value="
                .. tostring(target_interval)
        )

        local setter_call_ok, setter_result = pcall(function()
            return setter(target_interval)
        end)

        if not setter_call_ok then
            fail(
                "SetActorTickInterval invocation FAILED: "
                    .. tostring(setter_result)
            )
            return
        end

        log("SetActorTickInterval invocation completed")

        local unregister_ok = unregister_test_hook()

        if not unregister_ok then
            fail("hook cleanup verification failed")
            return
        end

        local readback_ok, readback_interval = pcall(function()
            return getter()
        end)

        if not readback_ok then
            fail(
                "tick interval readback FAILED: "
                    .. tostring(readback_interval)
            )
            return
        end

        log(
            "readback tick interval="
                .. tostring(readback_interval)
        )

        if type(readback_interval) ~= "number" then
            fail("readback interval is not a Lua number")
            return
        end

        local readback_delta =
            math.abs(readback_interval - target_interval)

        local state_unchanged =
            readback_delta <= EPSILON

        log(
            "readback delta="
                .. tostring(readback_delta)
        )

        log(
            "state unchanged="
                .. tostring(state_unchanged)
        )

        log(
            "hook callback count="
                .. tostring(hook_callback_count)
        )

        log(
            "matching callback seen="
                .. tostring(matching_callback_seen)
        )

        log(
            "callback error seen="
                .. tostring(callback_error_seen)
        )

        if not matching_callback_seen then
            fail("matching reflected pre-hook callback was not observed")
            return
        end

        if callback_error_seen then
            fail("one or more reflected hook callbacks reported an error")
            return
        end

        if not state_unchanged then
            fail("actor tick interval changed unexpectedly")
            return
        end

        log("RESULT=PASS")
        log("test completed")
    end)
end)

if not registration_ok then
    fail(
        "InitGameState hook registration FAILED: "
            .. tostring(registration_error)
    )
    return
end

log("InitGameState post-hook registered")
