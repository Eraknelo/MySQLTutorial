class "MySQLTest"

function MySQLTest:__init()
	-- Initialize LuaSQL Module
	local luaSql = require('luasql.mysql')
	
	-- Initialize MySQL connector
	local connector = luaSql.mysql()
	
	-- Connect to the MySQL server, and grab the connection, and the error.
	-- (database[, username[, password[, hostname[, port]]]]), [] = optional
	local connection, err = connector:connect("database_name", "username", "password", "webserverip.com", 3306)
	
	-- There is an error, print it and exit module
	if err ~= nil then
		print("Failed to connect to MySQL: " .. tostring(err))
		return
	end
	
	-- Save connection for later use
	self.sqlConnection = connection
	
	-- Call SetUpSql function. If it returns false, stop initializing
	if not self:SetUpSql() then return end
	
	-- Subscribe to player join event, upon which we want to increase player join count
	Events:Subscribe("PlayerJoin", self, self.PlayerJoin)
	
	-- Subscribe to unload event, so we can close the MySQL connection
	Events:Subscribe("ModuleUnload", self, self.ModuleUnload)
	
	-- Subscribe to console command "joincount <name>"
	Console:Subscribe("joincount", self, self.GetJoinCount)
end

function MySQLTest:SetUpSql()
	-- Create our table
	if self.sqlConnection:execute("CREATE TABLE IF NOT EXISTS `players` (`steam_id` TEXT UNIQUE NOT NULL, `name` TEXT NOT NULL, `join_count` INTEGER NOT NULL DEFAULT 1, PRIMARY KEY (`steam_id`));") == nil then
		-- Execute returned nil, this means an error occurred
		print("Failed to create table.")
		return false
	end
	
	-- All is well, return true
	return true
end

function MySQLTest:PlayerJoin(args)
	-- Player joined, increase the amount of times this player has joined in the database
	self:IncreasePlayerJoinCount(args.player)
end

function MySQLTest:IncreasePlayerJoinCount(player)
	-- Connection was never initialized. Safety feature, could possibly be removed, but we keep it here to prevent POSSIBLE errors
	if self.sqlConnection == nil then return end
	
	-- Get player steam ID string and name, and escape them, so we can prevent SQL injection
	local steamId = self.sqlConnection:escape(player:GetSteamId().string)
	local name = self.sqlConnection:escape(player:GetName())
	
	-- Insert the player into the database with a join count of 1, but if they already exist, add 1
	local sql = "INSERT INTO `players` (`steam_id`, `name`, `join_count`) VALUES ('" .. steamId .. "', '" .. name .. "', 1) ON DUPLICATE KEY UPDATE `join_count` = `join_count` + 1, `name` = '" .. name .. "';"
	
	-- Execute the SQL query
	if self.sqlConnection:execute(sql) == nil then
		-- SQL could not be executed
		print("Could not update join count for player " .. player:GetName())
	end
end

function MySQLTest:GetJoinCount(args)
	-- No player name was specified
	if args.text == nil or args.text == "" then
		print("Please give the name of a player.")
		return
	end
	
	-- Connection was never initialized. Safety feature, could possibly be removed, but we keep it here to prevent POSSIBLE errors
	if self.sqlConnection == nil then
		print("Not connected to the MySQL database.")
		return
	end
	
	-- Character escape the player name 
	local playerName = self.sqlConnection:escape(args.text)
	
	-- Our select query
	local sql = "SELECT `name`, `join_count` FROM `players` WHERE `name` LIKE '%" .. playerName .. "%';"
	
	-- Execute SQL query
	local result = self.sqlConnection:execute(sql)
	
	-- The query was unsuccessful
	if result == nil then
		-- SQL could not be executed
		print("Could not get player join count.")
		return
	end
	
	-- Check if result count is 0, A.K.A. the player has never been logged in the database
	if result:numrows() <= 0 then
		print("Player not found.")
		return
	end
	
	-- Print the amount of times the player has joined
	local row = result:fetch({})
	
	-- Loops through the rows until the next row is nil, A.K.A. we have reached the last row
	while row != nil do
		-- Print the found player their name, and amount of joins
		print("Player join count: ", row[1], row[2])
		
		-- Fetch next row
		row = result:fetch({})
	end
end

function MySQLTest:ModuleUnload()
	-- Connection was never initialized
	if self.sqlConnection == nil then return end
	
	-- Close connection
	self.sqlConnection:close()
end

-- Initialize class/module
MySQLTest()