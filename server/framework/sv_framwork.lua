CreateThread(function ()
    if (GetResourceState("es_extended") == "started") then
        Framework = "ESX"
        ESX = exports["es_extended"]:getSharedObject()
        print("[INFO] - ESX Framework")
    elseif (GetResourceState("qb-core") == "started") or (GetResourceState("qbx_core") == "started") then
        Framework = "QBCore"
        QBCore = exports['qb-core']:GetCoreObject()
        print("[INFO] - QBCore Framework")
    end
end)

AddEventHandler("playerDropped", function(reason)
    local allowedJob = HasAllowedJob(GetPlayerJob(source))
    if (not allowedJob) then return end
    local duty = GetPlayerOnDuty(source)
    if (duty) then
        local stopDuty = StopDuty(source)
        if (not stopDuty) then end
    end
end)

function GetPlayerFromId(source)
    if (Framework == "ESX") then
        return ESX.GetPlayerFromId(source)
    elseif (Framework == "QBCore") and (GetResourceState("qbx_core") == "started") then
        return exports.qbx_core:GetPlayer(source)
    elseif (Framework == "QBCore") then
        return QBCore.Functions.GetPlayer(source)
    end
    return nil
end

function GetIdentifier(source)
    local player = GetPlayerFromId(source)
    if (not player) then return end

    if (Framework == "ESX") then
        return player.getIdentifier()
    elseif (Framework == "QBCore") then
        return player.PlayerData.citizenid
    end

    return nil
end

function GetPlayerJob(source)
    local player = GetPlayerFromId(source)
    if (not player) then return nil end

    if (Framework == "ESX") then
        return player.getJob().name
    elseif (Framework == "QBCore") then
        return player.PlayerData.job.name
    end

    return nil
end

function GetPlayerOnDuty(source)
    local player = GetPlayerFromId(source)
    if (not player) then return nil end

    if (Framework == "ESX") and (Config.FrameworkBased) then
        return player.getJob().onDuty
    elseif (Framework == "QBCore") and (GetResourceState("qbx_core") == "started") then
        return player.PlayerData.job.onduty
    elseif (Framework == "QBCore") and (Config.FrameworkBased) then
        return player.playerData.job.onduty
    elseif (not Config.FrameworkBased) then
        if (not Cache.DutyData[source]) then
            Cache.DutyData[source] = { onDuty = false}
        end
        return Cache.DutyData[source].onDuty
    end
    return nil
end

function GetAllEmployees(jobName)
    if (Framework == "ESX") then
        local employees = MySQL.query.await("SELECT identifier, firstname, lastname, phone_number, job, job_grade FROM users WHERE job = ?", {jobName})
        
        for i = 1, #employees do
            local gradeResult = MySQL.query.await("SELECT label FROM job_grades WHERE job_name = ? AND grade = ?", {jobName, employees[i].job_grade})
            local jobResult = MySQL.query.await("SELECT label FROM jobs WHERE name = ?", {jobName})

            employees[i] = {
                identifier = employees[i].identifier,
                firstname = employees[i].firstname,
                lastname = employees[i].lastname,
                phone_number = employees[i].phone_number or "Unknown",
                job = jobResult[1] and jobResult[1].label or "Unknown",
                job_grade = gradeResult[1] and gradeResult[1].label or "Unknown",
            }
        end

        return employees
    elseif (Framework == "QBCore") then
        local rawEmployees = MySQL.query.await("SELECT citizenid, charinfo, job FROM players WHERE JSON_UNQUOTE(JSON_EXTRACT(job, '$.name')) = ?", {jobName})
        local employees = {}

        for i = 1, #rawEmployees do
            local charinfo = json.decode(rawEmployees[i].charinfo)
            local jobinfo = json.decode(rawEmployees[i].job)

            employees[i] = {
                identifier = rawEmployees[i].citizenid,
                firstname = charinfo.firstname,
                lastname = charinfo.lastname,
                phone_number = charinfo.phone,
                job = jobinfo.label,
                job_grade = jobinfo.grade.name
            }
        end

        return employees
    end
    return {}
end

function GetBossPermission(source)
    local player = GetPlayerFromId(source)
    if (not player) then return end

    if (Framework == "ESX") then
        for i = 1, #Config.BossGrades do
            if (player.getJob().grade_name == Config.BossGrades[i]) then
                return true
            end
        end
        return false
    elseif (Framework == "QBCore") then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player.PlayerData.job.isboss or false
    end

    return nil
end

function GetActiveWorkers(jobName)
    local activeWorkers = {}

    if (Framework == "ESX") then
        local playersWithSameJob = ESX.GetExtendedPlayers("job", jobName)

        for i = 1, #playersWithSameJob do
            if (playersWithSameJob[i].job.onDuty) then
                activeWorkers[i] = {
                    source = playersWithSameJob[i].source,
                    identifier = playersWithSameJob[i].identifier,
                    name = playersWithSameJob[i].name,
                    job = playersWithSameJob[i].job.label,
                    grade = playersWithSameJob[i].job.grade_label,
                    phone = GetPhoneNumber(playersWithSameJob[i].identifier) or "0",
                    dutyTime = FormatDutyTime(Cache.DutyData[playersWithSameJob[i].source] and Cache.DutyData[playersWithSameJob[i].source].startTime),
                    online = true
                }
            end
        end
        return activeWorkers
    elseif (Framework == "QBCore") then
        local activePlayers = QBCore.Functions.GetPlayers()
        for i = 1, #activePlayers do
            local player = QBCore.Functions.GetPlayer(activePlayers[i])
            
            if player.PlayerData.job.name == jobName and player.PlayerData.job.onduty then
                activeWorkers[i] = {
                    source = player.PlayerData.source,
                    identifier = player.PlayerData.citizenid,
                    name = player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname,
                    job = player.PlayerData.job.label,
                    grade = player.PlayerData.job.grade.name,
                    phone = GetPhoneNumber(player.PlayerData.citizenid) or "0",
                    dutyTime = Cache.DutyData[player.PlayerData.source] and os.date("%H:%M:%S", Cache.DutyData[player.PlayerData.source].startTime) or "N/A",
                    online = true
                }
            end
        end
        return activeWorkers
    end

    return activeWorkers
end


function GetPhoneNumber(identifier)
    if (Framework == "ESX") then
        local result = MySQL.single.await("SELECT `phone_number` FROM `users` WHERE `identifier` = ? LIMIT 1", {
            identifier
        })
        if (not result) then return "0" end

        return result.phone_number
    elseif (Framework == "QBCore") then
        local result = MySQL.single.await("SELECT `charinfo` FROM `players` WHERE `citizenid` = ? LIMIT 1", {
            identifier
        })

        if (not result) then return "0" end
        return json.decode(result.charinfo).phone
    end
    return nil
end

function SetDuty(source, status)
    if (Framework == "ESX") and (Config.FrameworkBased) then
        local Player = GetPlayerFromId(source)
        if (not Player) then return false end

        Player.setJob(Player.job.name, Player.job.grade, status)
        if (status) then
            StartDuty(source)
        else
            StopDuty(source)
        end
        return Player.job.onDuty
    elseif (Framework == "QBCore") and (GetResourceState("qbx_core") == "started") then
        local identifier = GetIdentifier(source)
        if (not identifier) then return nil end
        if (status) then
            StartDuty(source)
        else
            StopDuty(source)
        end
        return exports.qbx_core:SetJobDuty(identifier, status)
    elseif (Framework == "QBCore" and (Config.FrameworkBased)) then
        local Player = QBCore.Functions.GetPlayer(source)
        if (not Player) then return false end
        if (status) then
            StartDuty(source)
        else
            StopDuty(source)
        end
        return Player.Functions.SetJobDuty(status)
    else
        Cache.DutyData[source].onDuty = status
        if (status) then
            StartDuty(source)
        else
            StopDuty(source)
        end
        return Cache.DutyData[source].onDuty
    end

    return nil
end

function GetFullName(source)
    if (Framework == "ESX") then
        local playerData = GetPlayerFromId(source)
        local firstName = playerData?.firstName or playerData?.variables?.firstName or "Unknown"
        local lastName = playerData?.lastName or playerData?.variables?.lastName or "Unknown"

        return firstName .. " " .. lastName
    elseif (Framework == "QBCore") then
        local player = GetPlayerFromId(source)
        if (not player) then return "Unknown Unknown" end
       local firstName = player?.PlayerData?.charinfo?.firstname or "Unknown"
       local lastName = player?.PlayerData?.charinfo?.lastname or "Unknown"

        return firstName .. " " .. lastName
    end

    return "Unknown Unknown"
end

lib.callback.register("yecoyz_duty:getFullName", function(source)
    return GetFullName(source)
end)

lib.callback.register("yecoyz_duty:setDuty", function(source, status)
    SetDuty(source, status)
    return true
end)

exports("SetDuty", function(source, status)
    SetDuty(source, status)
    return true
end)

RegisterCommand("setDuty", function()
    SetDuty(1, true)
end, false)