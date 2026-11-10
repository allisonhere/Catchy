--[[
Name: CatchyApi-1.0
Maintainers: Sutorix <sutorix@hotmail.com>
Description: A library for the Catchy functions usable by plugins and other code.
Copyright (c) by Bob Schumaker
Licensed under a Creative Commons "Attribution Non-Commercial Share Alike" License
--]]
local addonName, FBStorage = ...
local  FBI = FBStorage

local MAJOR_VERSION = "CatchyApi-1.0"
local MINOR_VERSION = 90000 + tonumber(("$Rev: 678 $"):match("%d+"))

if not LibStub then error(MAJOR_VERSION .. " requires LibStub") end

local FBAPI, oldLib = LibStub:NewLibrary(MAJOR_VERSION, MINOR_VERSION)
if not FBAPI then
	return
end

local FL = LibStub("LibFishing-1.0");

-- 5.0.4 has a problem with a global "_"
local _

FBAPI.FBConstants = FBI.FBConstants;

-- Identify Catchy
function FBAPI:GetKey()
	local key = Catchy_Info["CatchyKey"];
	if ( not key ) then
		-- This was removed in 3.1, lets just assume we have enough randomness already
		-- math.randomseed(time());
		-- generate a random key to identify this instance of the plugin
		local n = 16 + random(4) + random(4);
		key = "";
		for _=1,n do
			key = key .. string.char(64+math.random(26));
		end
		Catchy_Info["CatchyKey"] = key;
	end
	return key;
end

function FBAPI:CheckForeignKey(foreignKey, foreignDate, saveKey)
	if ( not Catchy_Info["ForeignKeys"] ) then
		Catchy_Info["ForeignKeys"] = {};
	end
	if ( saveKey ) then
		Catchy_Info["ForeignKeys"][foreignKey] = foreignDate;
		return;
	end
	if ( not Catchy_Info["ForeignKeys"][foreignKey] ) then
		Catchy_Info["ForeignKeys"][foreignKey] = foreignDate;
		return true;
	end
	return ( Catchy_Info["ForeignKeys"][foreignKey] < foreignDate );
end

function FBAPI:ResetKey()
	Catchy_Info["CatchyKey"] = nil;
	local key = self:GetKey();
	if (FB_MergeDatabase) then
		FB_MergeDatabase.key = key;
	end
	FBI:Message("Key reset.");
	return key;
end

-- Miscellaneous functions
for _, apifunc in ipairs(FBI.APIFunctions) do
	FBAPI[apifunc] = function(self, ...) return FBI[apifunc](FBI, ...); end;
end
