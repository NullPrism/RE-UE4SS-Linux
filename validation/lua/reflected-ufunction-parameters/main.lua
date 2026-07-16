local PREFIX = "[NullPrismReflectedUFunctionParameters]"
local callback_seen = false

local function log(message)
    print(PREFIX .. " " .. message .. "\n")
end

local function fail(message)
    log(message)
    log("RESULT=FAIL")
    log("test completed")
end

log("main.lua loaded")

if type(RegisterInitGameStatePostHook) ~= "function" then
    fail(
        "registration FAILED: "
            .. "RegisterInitGameStatePostHook unavailable"
    )
    return
end

local registration_ok, registration_error = pcall(function()
    RegisterInitGameStatePostHook(function()
        if callback_seen then
            log("additional InitGameState callback ignored")
            return
        end

        callback_seen = true
        log("InitGameState post-hook fired")

        if type(StaticFindObject) ~= "function" then
            fail("StaticFindObject unavailable")
            return
        end

        local object_ok, math_library = pcall(function()
            return StaticFindObject(
                "/Script/Engine.Default__KismetMathLibrary"
            )
        end)

        if not object_ok then
            fail(
                "KismetMathLibrary lookup FAILED: "
                    .. tostring(math_library)
            )
            return
        end

        if math_library == nil then
            fail("KismetMathLibrary lookup returned nil")
            return
        end

        local valid_ok, is_valid = pcall(function()
            return math_library:IsValid()
        end)

        if not valid_ok then
            fail(
                "KismetMathLibrary IsValid FAILED: "
                    .. tostring(is_valid)
            )
            return
        end

        log(
            "KismetMathLibrary IsValid="
                .. tostring(is_valid)
        )

        if not is_valid then
            fail("KismetMathLibrary is invalid")
            return
        end

        local full_name_ok, full_name = pcall(function()
            return math_library:GetFullName()
        end)

        if full_name_ok then
            log(
                "KismetMathLibrary full name="
                    .. tostring(full_name)
            )
        end

        local function_ok, add_int_int = pcall(function()
            return math_library.Add_IntInt
        end)

        if not function_ok then
            fail(
                "Add_IntInt lookup FAILED: "
                    .. tostring(add_int_int)
            )
            return
        end

        log(
            "Add_IntInt Lua type="
                .. type(add_int_int)
        )

        if type(add_int_int) ~= "userdata" then
            fail("Add_IntInt did not resolve as userdata")
            return
        end

        local callable_valid_ok, callable_valid = pcall(function()
            return add_int_int:IsValid()
        end)

        if not callable_valid_ok then
            fail(
                "Add_IntInt IsValid FAILED: "
                    .. tostring(callable_valid)
            )
            return
        end

        log(
            "Add_IntInt userdata IsValid="
                .. tostring(callable_valid)
        )

        if not callable_valid then
            fail("Add_IntInt callable is invalid")
            return
        end

        local function_name_ok, function_name = pcall(function()
            return add_int_int:GetFullName()
        end)

        if function_name_ok then
            log(
                "Add_IntInt full name="
                    .. tostring(function_name)
            )
        end

        local left = 20
        local right = 22
        local expected = 42

        log("left argument=" .. tostring(left))
        log("right argument=" .. tostring(right))
        log("expected result=" .. tostring(expected))

        -- The callable userdata retains the KismetMathLibrary default-object
        -- context. Only the reflected UFunction parameters are supplied here.
        local invoke_ok, return_value = pcall(function()
            return add_int_int(left, right)
        end)

        if not invoke_ok then
            fail(
                "Add_IntInt invocation FAILED: "
                    .. tostring(return_value)
            )
            return
        end

        log("invocation completed")
        log("return Lua type=" .. type(return_value))
        log("return value=" .. tostring(return_value))

        if type(return_value) ~= "number" then
            fail("return value is not a Lua number")
            return
        end

        local result_verified = return_value == expected

        log(
            "result verified="
                .. tostring(result_verified)
        )

        if not result_verified then
            fail(
                "unexpected result: "
                    .. tostring(return_value)
            )
            return
        end

        log("RESULT=PASS")
        log("test completed")
    end)
end)

if not registration_ok then
    fail(
        "registration FAILED: "
            .. tostring(registration_error)
    )
    return
end

log("InitGameState post-hook registered")
