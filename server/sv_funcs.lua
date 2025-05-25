lib.callback.register("yecoyz_duty:getActiveWorkers", function (soure, jobName)
    return GetActiveWorkers(jobName)
end)

lib.callback.register("yecoyz_duty:getAllEmployees", function(source, jobName)
    return GetAllEmployees(jobName)
end)

lib.callback.register("yecoyz_duty:getActiveDutyTime", function(source)
    return Cache.DutyData[source].startTime
end)

function StartDuty(source)
    local getMultiplier = GetMultiplier(source)
    local timeNow = os.time()
    Cache.DutyData[source] = {
        onDuty = true,
        startTime = timeNow,
        multiplier = getMultiplier,
    }
end

lib.callback.register("yecoyz_duty:startDuty", function(source)
    StartDuty(source)
    return true
end)

lib.callback.register("yecoyz_duty:stopDuty", function(source)
    return StopDuty(source)
end)

function StopDuty(source)
    local saveData = SaveMultiplierAndEndTime(source)
    if (not saveData) then return false end
    UpdateHistory(source)
    print(Cache.DutyData[source].startTime)
    Cache.DutyData[source] = {}
    return true
end

function HasAllowedJob(jobName)
    for i = 1, #Config.Jobs do
        if (jobName == Config.Jobs[i]) then
            return true
        end
    end
    return false
end

lib.callback.register("yecoyz_duty:isBoss", function(source)
    return GetBossPermission(source)
end)

function SaveMultiplierAndEndTime(source)
    local updateData = MySQL.update.await("UPDATE yecoyz_duty SET multiplier = ?, offDuty = ? WHERE identifier = ?", {
        CalculateSalaryMultiplier(source), os.time(), GetIdentifier(source)
    })

    if (not updateData) then return false end

    return true
end

function FormatDutyTime(startTime)
    if (not startTime) then return "N/A" end
    local elapsedSeconds = os.time() - startTime
    return string.format("%d h, %d m", math.floor(elapsedSeconds / 3600), math.floor((elapsedSeconds % 3600) / 60))
end

function UpdateHistory(source)
    print("knas", Cache.DutyData[source].startTime)
    local startTime = Cache.DutyData[source].startTime
    local endTime = os.time()

    local duration = endTime - startTime

    local result = MySQL.single.await("SELECT `history` FROM `yecoyz_duty` WHERE `identifier` = ? LIMIT 1", {
        GetIdentifier(source)
    })

    local history = {
        startTime = startTime,
        endTime = endTime,
        startTimeFormatted = os.date("%Y-%m-%d %H:%M:%S", startTime),
        endTimeFormatted = os.date("%Y-%m-%d %H:%M:%S", endTime),
        duration = duration,
    }

    if (not result) then
        local initialHistory = {history}
        local initializeHistory = MySQL.insert.await("INSERT INTO `yecoyz_duty` (identifier, history) VALUES (?, ?)", {
            GetIdentifier(source), json.encode(initialHistory)
        })
        if (not initializeHistory) then return false end
        
        return true
    end

    local getHistory = json.decode(result.history) or {}
    table.insert(getHistory, history)

    local updateHistory = MySQL.update.await("UPDATE yecoyz_duty SET history = ? WHERE identifier = ?", {
        json.encode(getHistory), GetIdentifier(source)
    })
    if (not updateHistory) then return false end

    return true
end

lib.callback.register("yecoyz_duty:updateHistory", function(source)
    local updateHistory = UpdateHistory(source)
    if (not updateHistory) then return false end

    return true
end)

lib.callback.register("yecoyz_duty:getHistory", function(source)
    local result = MySQL.single.await("SELECT `history` FROM `yecoyz_duty` WHERE `identifier` = ? LIMIT 1", {
        GetIdentifier(source)
    })

    if (not result) then return {} end
    local historyData = json.decode(result.history) or {}

    return historyData
end)

lib.callback.register("yecoyz_duty:getEmployeHistory", function (source, identifier)
    local employeeHistory = MySQL.single.await("SELECT `history` FROM `yecoyz_duty` WHERE `identifier` = ? LIMIT 1", {
        identifier
    })
    if (not employeeHistory) then return {} end
    local employeHistoyData = json.decode(employeeHistory.history) or {}

    return employeHistoyData
end)

function GetMultiplier(source)
    local identifier = GetIdentifier(source)
    if (not identifier) then return nil end

    local job = GetPlayerJob(source)
    if (not job) then return nil elseif (not Config.MultiplierSettings.Multiplier[job]) then return 1.0 end

    local multiplierData = MySQL.single.await("SELECT `multiplier`, `offDuty` FROM yecoyz_duty WHERE `identifier` = ? LIMIT 1", {identifier})
    if (not multiplierData) then return nil end

    local timeNow = os.time()
    
    local hoursPassed = (timeNow - multiplierData.offDuty) / 3600
    
    local multiplier = multiplierData.multiplier
    if (hoursPassed >= 1) then
        multiplier = multiplierData.multiplier - (Config.MultiplierSettings.Hourlyloss * hoursPassed)
        if multiplier < 1.0 then
            multiplier = 1.0
        end
    end
    
    return multiplier or 1.0
end

function CalculateSalaryMultiplier(source)
    if (not Config.MultiplierSettings.SalaryMultiplier) then return 1.0 end
    if (not Cache.DutyData[source]) or (not Cache.DutyData[source].startTime) then
        return 1.0
    end
    
    local job = GetPlayerJob(source)
    if (not job) then return nil elseif (not Config.MultiplierSettings.Multiplier[job]) then return 1.0 end

    local currentTime = os.time()
    local startTime = Cache.DutyData[source].startTime
    local hoursOnDuty = (currentTime - startTime) / 3600
    
    local baseMultiplier = Cache.DutyData[source].multiplier or 1.0

    local multiplier = baseMultiplier + (hoursOnDuty * Config.MultiplierSettings.Multiplier[job].increasePerHour)

    if multiplier > Config.MultiplierSettings.Multiplier[job].maxMultiplier then
        multiplier = Config.MultiplierSettings.Multiplier[job].maxMultiplier
    end

    return multiplier
end

lib.callback.register("yecoyz_duty:getStandaloneDuty", function(source)
    return GetPlayerOnDuty(source)
end)

exports("GetDutyState", function(source)
    return GetPlayerOnDuty(source)
end)

exports("GetSalaryMultiplier", function(source)
    return CalculateSalaryMultiplier(source)
end)

exports("GetOffDutyPayInfo", function()
    local offDutyInfo = {
        offDutyPay = Config.OffDutySettings.PayOffDuty,
        multiplier  = Config.OffDutySettings.OffDutyMultiplier,
    }
    return offDutyInfo
end)