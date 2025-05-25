lib.locale()
Duty = nil

function ToggleDuty()
    Duty = not Duty
    local setNewDuty = SetDuty(Duty)
    if (not setNewDuty) then return false end
    return true
end

function SaveDutyHistory()
    local updateHistory = lib.callback.await("yecoyz_duty:updateHistory", false)
    if (not updateHistory) then return false end

    return true
end

function GetDutyHistory()
    local history = lib.callback.await("yecoyz_duty:getHistory", false)
    if (not history) then return "[]" end

    return history
end

function GetIfBoss()
    local isBoss = lib.callback.await("yecoyz_duty:isBoss", false)
    if (not isBoss) then return false end

    return isBoss
end

function HasAllowedJob(jobName)
    for i = 1, #Config.Jobs do
        if (jobName == Config.Jobs[i]) then
            return true
        end
    end
    return false
end

RegisterNUICallback("Eventhandler", function(data, cb)
    if (data.event == "toggleDuty") then
        Duty = GetPlayerOnDuty()
        local newDutyState = not Duty

        local toggleDuty = ToggleDuty()
        if (not toggleDuty) then return cb({success = false}) end

        local getActiveDutyTime = lib.callback.await("yecoyz_duty:getActiveDutyTime", false)
        local dutyHistory = GetDutyHistory()

        SendNUIMessage({
            action = "updateCharacter" and "updateShifts",
            character = {isOnDuty = newDutyState, dutyStarted = getActiveDutyTime},
            shifts = dutyHistory
        })
        return cb({ success = true, isOnDuty = Duty ,dutyStarted = getActiveDutyTime})
    elseif (data.event == "getEmployeeHistory") then
    local employeHistory = lib.callback.await("yecoyz_duty:getEmployeHistory", false, data.data)
        return cb(employeHistory)
    elseif (data.event == ("getLocale")) then
        local uiLocales = {}
        local locales = lib.getLocales()

        for k, v in pairs(locales) do
            if (k:find("^ui_")) then
                uiLocales[k] = v
            end
        end
        return cb(uiLocales)
    elseif (data.event == "closePage") then
        SetNuiFocus(false, false)
        return cb({ success = true })
    end

    return cb({ success = false })
end)

exports("GetOwnHistory", GetDutyHistory)
exports("SaveOwnDutyHistory", SaveDutyHistory)