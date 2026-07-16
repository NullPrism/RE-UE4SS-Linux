local PREFIX = "[NullPrismReflectedPropertyWrite]"
local EPSILON = 0.000001
local callback_seen = false

local function log(message)
    print(PREFIX .. " " .. message .. "\n")
end

local function approximately_equal(left, right)
    return type(left) == "number"
        and type(right) == "number"
        and math.abs(left - right) <= EPSILON
end

local function read_property(object, property_name)
    return pcall(function()
        return object[property_name]
    end)
end

local function write_property(object, property_name, value)
    return pcall(function()
        object[property_name] = value
    end)
end

log("main.lua loaded")

if type(RegisterInitGameStatePostHook) ~= "function" then
    log("registration FAILED: RegisterInitGameStatePostHook unavailable")
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

        local property_name = "CustomTimeDilation"

        local original_read_ok, original_value =
            read_property(context, property_name)

        if not original_read_ok then
            log("original read FAILED: " .. tostring(original_value))
            log("RESULT=FAIL")
            return
        end

        log("original Lua type=" .. type(original_value))
        log("original value=" .. tostring(original_value))

        if type(original_value) ~= "number" then
            log("original value is not a Lua number")
            log("RESULT=FAIL")
            return
        end

        local temporary_value = 0.99

        if approximately_equal(original_value, temporary_value) then
            temporary_value = 0.98
        end

        log("temporary target=" .. tostring(temporary_value))

        local temporary_write_ok, temporary_write_error =
            write_property(context, property_name, temporary_value)

        if temporary_write_ok then
            log("temporary write completed")
        else
            log(
                "temporary write FAILED: "
                    .. tostring(temporary_write_error)
            )
        end

        local temporary_read_ok, temporary_readback =
            read_property(context, property_name)

        local temporary_verified = false

        if temporary_read_ok then
            log(
                "temporary readback Lua type="
                    .. type(temporary_readback)
            )
            log(
                "temporary readback value="
                    .. tostring(temporary_readback)
            )

            temporary_verified =
                approximately_equal(temporary_readback, temporary_value)

            log(
                "temporary readback verified="
                    .. tostring(temporary_verified)
            )
        else
            log(
                "temporary readback FAILED: "
                    .. tostring(temporary_readback)
            )
        end

        -- Restoration is attempted regardless of the temporary-write result.
        local restore_write_ok, restore_write_error =
            write_property(context, property_name, original_value)

        if restore_write_ok then
            log("restore write completed")
        else
            log(
                "restore write FAILED: "
                    .. tostring(restore_write_error)
            )
        end

        local restore_read_ok, restored_value =
            read_property(context, property_name)

        local restore_verified = false

        if restore_read_ok then
            log(
                "restored readback Lua type="
                    .. type(restored_value)
            )
            log(
                "restored readback value="
                    .. tostring(restored_value)
            )

            restore_verified =
                approximately_equal(restored_value, original_value)

            log(
                "restore verified="
                    .. tostring(restore_verified)
            )
        else
            log(
                "restored readback FAILED: "
                    .. tostring(restored_value)
            )
        end

        local test_passed =
            temporary_write_ok
            and temporary_read_ok
            and temporary_verified
            and restore_write_ok
            and restore_read_ok
            and restore_verified

        if test_passed then
            log("RESULT=PASS")
        else
            log("RESULT=FAIL")
        end

        log("test completed")
    end)
end)

if not registration_ok then
    log("registration FAILED: " .. tostring(registration_error))
    return
end

log("InitGameState post-hook registered")
