local number_length = 10 -- 19 Max !! NEVER GO BELOW YOUR PLAYER LIST
local number_prefix = 213

apps = {}

users = {}

--------------------------------------------------------------------------------
--
--									EVENTS
--
--------------------------------------------------------------------------------

AddEventHandler('chatMessage', function(name, color, message)
    getApp("contact", function(app)
        RconPrint("\n" .. tostring(app))
    end)
end)

AddEventHandler('playerConnecting', function(playerName, setKickReason)
    getUser(source)
end)

AddEventHandler('playerDropped', function(reason)
    local player = source
    if users[player] then
        RconPrint("\n\nDROP : " .. tostring(users[player].id .. " + " .. tostring(users[player].battery)))
        updateBattery(users[player].id, users[player].battery)
        users[player] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == "ephone" then
        setupPhone()
        RconPrint("\n\n\nStarting\n\n\n\n")
        for k, v in pairs(GetPlayers()) do
            getUser(v)
        end
        RconPrint("\n\n\n\nAfter while\n\n\n\n")
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == "ephone" then
        for k, v in pairs(users) do
            if users[v] then
                updateBattery(users[v].id, users[v].battery)
            end
        end
    end
end)

RegisterServerEvent('ephone:updateBattery')
AddEventHandler('ephone:updateBattery', function(battery)
    if users[source] then
        users[source].battery = battery
    end
end)

RegisterServerEvent('ephone:addApp')
AddEventHandler('ephone:addApp', function(name, display_name, description, icon)
    addApp(name, display_name, description, icon)
end)

RegisterServerEvent('ephone:deleteApp')
AddEventHandler('ephone:deleteApp', function(name)
    deleteApp(name)
end)

RegisterServerEvent('ephone:addGroup')
AddEventHandler('ephone:addGroup', function(name, phone_number)
    checkGroupName(name, function(bool)
        if not bool then
            addGroup(name, phone_number)
        end
    end)
end)

RegisterServerEvent('ephone:deleteGroup')
AddEventHandler('ephone:deleteGroup', function(name)
    deleteGroup(name)
end)

RegisterServerEvent('ephone:changePhoneNumber')
AddEventHandler('ephone:changePhoneNumber', function(new_phone_number)
    checkPhoneNumber(new_phone_number, function(bool)
        changePhoneNumber(users[source].id, new_phone_number)
    end)
end)

RegisterServerEvent('ephone:updateGroup')
AddEventHandler('ephone:updateGroup', function(name, new_name, phone_number, new_phone_number)
    checkGroupName(new_name, function(bool)
        if not bool then
            checkPhoneNumber(new_phone_number, function(bool)
                if not bool then
                    updateGroup(name, newname, phone_number, new_phone_number)
                else
                    -- Log: new phone number already in use
                end
            end)
        else
            -- Log: new name already in use
        end
    end)
end)

RegisterServerEvent('ephone:joinGroup')
AddEventHandler('ephone:joinGroup', function(name)
    getGroupId(name, function(gid)
        isUserInGroup(gid, function(bool)
            if not bool then
                joinGroup(users[source].id, gid)
            else
                -- Log: User is already in the group
            end
        end)
    end)
end)

RegisterServerEvent('ephone:leaveGroup')
AddEventHandler('ephone:leaveGroup', function(name)
    getGroupId(name, function(gid)
        isUserInGroup(gid, function(bool)
            if bool then
                leaveGroup(users[source].id, gid)
            else
                -- Log: User is not in the group
            end
        end)
    end)
end)


--------------------------------------------------------------------------------
--
--								FUNCTIONS
--
--------------------------------------------------------------------------------
function setupPhone()
    -- AddEventHandler('onMySQLReady', function ()
    MySQL.ready(function ()
        MySQL.Async.execute("CREATE TABLE IF NOT EXISTS `ephone_users` (`id` int(11) NOT NULL AUTO_INCREMENT, `playerid` varchar(255) NOT NULL, `phone_number` bigint(20) NOT NULL, `battery` int(11) NOT NULL DEFAULT '100', PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;", {}, function(changes)
            checkColumn("ephone_users", "id", "int(11) NOT NULL AUTO_INCREMENT")
            checkColumn("ephone_users", "playerid", "varchar(255) NOT NULL AFTER `id`")
            checkColumn("ephone_users", "phone_number", "bigint(20) NOT NULL AFTER `playerid`")
            checkColumn("ephone_users", "battery", "int(11) NOT NULL DEFAULT '100' AFTER `phone_number`")
        end)

        MySQL.Async.execute("CREATE TABLE IF NOT EXISTS `ephone_groups` (`id` int(11) NOT NULL AUTO_INCREMENT, `name` varchar(30) NOT NULL, `phone_number` bigint(20) NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;", {}, function(changes)
            checkColumn("ephone_groups", "id", "int(11) NOT NULL AUTO_INCREMENT")
            checkColumn("ephone_groups", "name", "varchar(30) NOT NULL AFTER `id`")
            checkColumn("ephone_groups", "phone_number", "bigint(20) NOT NULL AFTER `name`")
        end)

        MySQL.Async.execute("CREATE TABLE IF NOT EXISTS `ephone_app` (`id` int(11) NOT NULL AUTO_INCREMENT, `name` varchar(20) NOT NULL, `display_name` varchar(20) NOT NULL, `description` text NOT NULL, `icon` varchar(20) NOT NULL, PRIMARY KEY (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;", {}, function(changes)
            checkColumn("ephone_app", "id", "int(11) NOT NULL AUTO_INCREMENT")
            checkColumn("ephone_app", "name", "varchar(20) NOT NULL AFTER `id`")
            checkColumn("ephone_app", "display_name", "varchar(20) NOT NULL AFTER `name`")
            checkColumn("ephone_app", "description", "text NOT NULL AFTER `display_name`")
            checkColumn("ephone_app", "icon", "varchar(20) NOT NULL AFTER `description`")
        end)

        MySQL.Async.execute("CREATE TABLE IF NOT EXISTS `ephone_users_group` (`user` int(11) NOT NULL, `group` int(11) NOT NULL, PRIMARY KEY (`user`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;", {}, function(changes)
            checkColumn("ephone_app", "user", "int(11) NOT NULL")
            checkColumn("ephone_app", "group", "int(11) NOT NULL")
        end)
    end)
end

function checkTable(table, callback)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = @table", {['@table'] = table}, function(data)
        if data == 0 then
            callback(false)
        else
            callback(true)
        end
    end)
end

function checkColumn(table, column, settings)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @table AND COLUMN_NAME = @column", {['@table'] = table, ['@column'] = column}, function(data)
        if data == 0 then
            MySQL.Async.execute(string.format("ALTER TABLE `%s` ADD `%s` %s", table, column, settings))
        else
            MySQL.Async.execute(string.format("ALTER TABLE `%s` CHANGE `%s` `%s` %s", table, column, column, settings))
        end
    end)
end

function getApps(callback)
    MySQL.Async.fetchAll("SELECT * FROM ephone_app", {}, function(apps)
        callback(apps)
    end)
end

function getApp(name, callback)
    MySQL.Async.fetchAll("SELECT * FROM ephone_app WHERE name = @name", {['@name'] = name}, function(data)
        callback(data[1])
    end)
end

function checkApp(name, callback)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_app WHERE name = @name", {['@name'] = name}, function(data)
        if data == 0 then
            callback(false)
        else
            callback(true)
        end
    end)
end

function addApp(name, display_name, description, icon)
    getApp(name, function(app)
        if not app then
            MySQL.Async.execute("INSERT INTO ephone_app (`name`, `display_name`, `description`, `icon`) VALUES (@name, @display_name, @description, @icon)", {['@name'] = name, ['@display_name'] = display_name, ['@description'] = description, ['@icon'] = icon})
        end
    end)
end

function deleteApp(name)
    MySQL.Async.execute("DELETE FROM ephone_app WHERE name=@name", {['@name'] = name})
end

function getUser(source)
    if not users[source] then
        local identifier = GetPlayerIdentifiers(source)

        if identifier[1] then
            MySQL.Async.fetchAll("SELECT * FROM ephone_users WHERE playerid = @source LIMIT 1", {['@source'] = identifier[1]}, function(user)
                if user[1] then
                    users[source] = user[1]
                    return user[1]
                else
                    MySQL.Sync.execute("INSERT INTO ephone_users (`playerid`, `phone_number`) VALUES (@identifier, @number)", {['@identifier'] = identifier[1], ['@number'] = generatePhoneNumber()})
                    return getUser(source)
                end
            end)
        end
    end
end

function getGroupId(name, callback)
    MySQL.Async.fetchAll("SELECT * FROM ephone_groups WHERE name = @name", {['@name'] = name}, function(data)
        if data[1].id then
            callback(data[1].id)
        else
            callback(nil)
        end
    end)
end

function checkPhoneNumber(number, callback)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_users WHERE phone_number = @number", {['@number'] = number}, function(data)
        if data == 0 then
            MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_groups WHERE phone_number = @number", {['@number'] = number}, function(data)
                if data == 0 then
                    callback(false)
                else
                    callback(true)
                end
            end)
        else
            callback(true)
        end
    end)
end

function generatePhoneNumber()
    local newnumber = tostring(number_prefix)

    for length=string.len(tostring(number_prefix)), number_length - 1 do
        newnumber = newnumber .. tostring(math.random(10))
    end
    checkPhoneNumber(newnumber, function(bool, err)
        if bool then
            return generatePhoneNumber()
        end
    end)
    return tonumber(newnumber)
end

function checkUser(source, callback)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_users WHERE playerid = @identifier", {['@identifier'] = GetPlayerIdentifiers(source)[1]}, function(data)
        if data == 0 then
            callback(false)
        else
            callback(true)
        end
    end)
end

function addUser(source)
    checkUser(source, function(bool)
        if not bool then
            MySQL.Async.execute("INSERT INTO ephone_users (`playerid`, `phone_number`) VALUES (@identifier, @number)", {['@identifier'] = GetPlayerIdentifiers(source)[1], ['@number'] = generatePhoneNumber()})
        end
    end)
end

function isUserInGroup(uid, gid)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_users_group WHERE user = @user AND group = @group", {['@user'] = uid, ['@group'] = gid}, function(data)
        if data == 0 then
            callback(false)
        else
            callback(true)
        end
    end)
end

function joinGroup(uid, gid)
    MySQL.Async.execute("INSERT INTO ephone_users_group (`user`, `group`) VALUES (@user, @group)", {['@user'] = uid, ['@group'] = gid})
end

function leaveGroup(uid, gid)
    MySQL.Async.execute("DELETE FROM ephone_users_group WHERE user = @user AND group = @group", {['@user'] = uid, ['@group'] = gid})
end

function checkGroupName(name, callback)
    MySQL.Async.fetchScalar("SELECT COUNT(1) FROM ephone_groups WHERE name = @name", {['@name'] = name}, function(data)
        if data == 0 then
            callback(false)
        else
            callback(true)
        end
    end)
end

function addGroup(name, number)
    MySQL.Async.execute("INSERT INTO ephone_groups (`name`, `phone_number`) VALUES (@name, @number)", {['@name'] = name, ['@number'] = tonumber(number)})
end

function  changePhoneNumber(uid, new_phone_number)
    MySQL.Async.execute("UPDATE ephone_users SET phone_number=@new_phone_number WHERE playerid = @uid", {['new_phone_number'] = new_phone_number,  ['uid'] = uid})
end

function updateGroup(name, new_name, phone_number, new_phone_number)
    MySQL.Async.execute("UPDATE ephone_groups SET name=@new_name, phone_number=@new_phone_number WHERE name = @name", {['@new_phone_number'] = new_phone_number,  ['@name'] = name, ['@new_name'] = new_name})
end

function deleteGroup(name)
    MySQL.Async.execute("DELETE FROM ephone_groups WHERE name=@name", {['@name'] = name})
end

function updateBattery(uid, battery)
    MySQL.Sync.execute("UPDATE ephone_users SET battery=@battery WHERE id = @id", {['@battery'] = battery,  ['@id'] = uid})
end
