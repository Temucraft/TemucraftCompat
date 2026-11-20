-- C_ namespaces, built on the 3.3.5 functions. Each table is only filled with functions it doesn't have.
local function ns(name) _G[name] = _G[name] or {} return _G[name] end
local function fill(t, fns) for k, v in pairs(fns) do if t[k] == nil then t[k] = v end end end
local function packAura(name, rank, icon, count, debuffType, duration, expirationTime, source, isStealable, shouldConsolidate, spellId)
	if not name then return nil end
	return { name = name, rank = rank, icon = icon, applications = count or 0, dispelName = debuffType, duration = duration or 0,
		expirationTime = expirationTime or 0, sourceUnit = source, isStealable = isStealable, spellId = spellId,
		isFromPlayerOrPlayerPet = source == "player" or source == "pet" }
end

fill(ns("C_AddOns"), {
	IsAddOnLoaded = function(a) return IsAddOnLoaded(a) end,
	LoadAddOn = function(a) return LoadAddOn(a) end,
	GetAddOnMetadata = function(a, f) return GetAddOnMetadata(a, f) end,
	GetNumAddOns = function() return GetNumAddOns() end,
	GetAddOnInfo = function(a) return GetAddOnInfo(a) end,
	EnableAddOn = function(a, c) return EnableAddOn(a, c) end,
	DisableAddOn = function(a, c) return DisableAddOn(a, c) end,
	IsAddOnLoadOnDemand = function(a) return IsAddOnLoadOnDemand(a) end,
	GetAddOnEnableState = function(c, a) return GetAddOnEnableState and GetAddOnEnableState(c, a) or (select(4, GetAddOnInfo(a)) and 2 or 0) end,
	DoesAddOnExist = function(a) return GetAddOnInfo(a) ~= nil end,
	SaveAddOns = function() if SaveAddOns then SaveAddOns() end end,
})

fill(ns("C_Container"), {
	GetContainerNumSlots = GetContainerNumSlots,
	GetContainerNumFreeSlots = GetContainerNumFreeSlots,
	GetContainerItemLink = GetContainerItemLink,
	GetContainerItemID = GetContainerItemID,
	PickupContainerItem = PickupContainerItem,
	UseContainerItem = UseContainerItem,
	SplitContainerItem = SplitContainerItem,
	GetContainerItemCooldown = GetContainerItemCooldown,
	GetBagName = GetBagName,
	ContainerIDToInventoryID = ContainerIDToInventoryID,
	GetContainerItemInfo = function(bag, slot)
		local icon, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bag, slot)
		if not icon then return nil end
		return { iconFileID = icon, stackCount = count, isLocked = locked, quality = quality, isReadable = readable,
			hasLoot = lootable, hyperlink = link, itemID = link and tonumber(link:match("item:(%d+)")), isBound = false, hasNoValue = false }
	end,
	SortBags = function() end,
	SetSortBagsRightToLeft = function() end,
})

fill(ns("C_Item"), {
	GetItemInfo = GetItemInfo,
	GetItemInfoInstant = GetItemInfoInstant,
	GetItemCount = GetItemCount,
	GetItemQualityColor = GetItemQualityColor,
	GetItemIconByID = function(id) return select(10, GetItemInfo(id)) end,
	GetItemNameByID = function(id) return (GetItemInfo(id)) end,
	GetItemQualityByID = function(id) return select(3, GetItemInfo(id)) end,
	GetDetailedItemLevelInfo = GetDetailedItemLevelInfo,
	IsEquippableItem = IsEquippableItem,
	IsDressableItemByID = function(id) return IsEquippableItem(id) end,
	RequestLoadItemDataByID = function(id) GameTooltip:SetHyperlink("item:" .. id) GameTooltip:Hide() end,
	DoesItemExistByID = function(id) return GetItemInfo(id) ~= nil end,
	IsItemDataCachedByID = function(id) return GetItemInfo(id) ~= nil end,
	GetItemSpell = GetItemSpell,
	IsUsableItem = IsUsableItem,
	GetItemCooldown = GetItemCooldown,
	GetItemClassInfo = function(c) return nil end,
})

do
	local tip
	local function description(spell)
		tip = tip or CreateFrame("GameTooltip", "TemucraftCompatScanTip", nil, "GameTooltipTemplate")
		tip:SetOwner(WorldFrame, "ANCHOR_NONE")
		local link = GetSpellLink(spell)
		if not link then return "" end
		tip:SetHyperlink(link)
		local n = tip:NumLines()
		local text = n > 0 and _G["TemucraftCompatScanTipTextLeft" .. n]:GetText() or ""
		tip:Hide()
		return text or ""
	end
	fill(ns("C_Spell"), {
		GetSpellInfo = function(spell)
			local name, rank, icon, cost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spell)
			if not name then return nil end
			return { name = name, rank = rank, iconID = icon, originalIconID = icon, castTime = castTime, minRange = minRange,
				maxRange = maxRange, spellID = type(spell) == "number" and spell or nil }
		end,
		GetSpellName = function(spell) return (GetSpellInfo(spell)) end,
		GetSpellTexture = function(spell) return (select(3, GetSpellInfo(spell))) end,
		GetSpellSubtext = function(spell) return (select(2, GetSpellInfo(spell))) end,
		GetSpellDescription = description,
		GetSpellLink = GetSpellLink,
		IsSpellUsable = function(spell) return IsUsableSpell(spell) end,
		GetSpellCooldown = function(spell)
			local start, duration, enabled = GetSpellCooldown(spell)
			return { startTime = start or 0, duration = duration or 0, isEnabled = enabled == 1, modRate = 1 }
		end,
		DoesSpellExist = function(spell) return GetSpellInfo(spell) ~= nil end,
		IsSpellInRange = function(spell, unit) return IsSpellInRange(spell, unit) == 1 end,
	})
end

fill(ns("C_UnitAuras"), {
	GetAuraDataByIndex = function(unit, index, filter) return packAura(UnitAura(unit, index, filter)) end,
	GetBuffDataByIndex = function(unit, index, filter) return packAura(UnitBuff(unit, index, filter)) end,
	GetDebuffDataByIndex = function(unit, index, filter) return packAura(UnitDebuff(unit, index, filter)) end,
	GetPlayerAuraBySpellID = function(spellId)
		for _, f in ipairs({ "HELPFUL", "HARMFUL" }) do
			for i = 1, 40 do
				local a = packAura(UnitAura("player", i, f))
				if not a then break end
				if a.spellId == spellId then return a end
			end
		end
	end,
	GetAuraDataBySpellName = function(unit, name, filter)
		for i = 1, 40 do
			local a = packAura(UnitAura(unit, i, filter))
			if not a then break end
			if a.name == name then return a end
		end
	end,
})
fill(ns("C_Secrets"), { ShouldAurasBeSecret = function() return false end, ShouldUnitAuraIndexBeSecret = function() return false end })
fill(ns("C_Seasons"), { HasActiveSeason = function() return false end, GetActiveSeason = function() return nil end })
fill(ns("C_GameRules"), { IsHardcoreActive = function() return false end, IsGameRuleActive = function() return false end })

fill(ns("C_CVar"), {
	GetCVar = GetCVar, SetCVar = SetCVar,
	GetCVarBool = function(n) return GetCVarBool(n) end,
	GetCVarDefault = function(n) return GetCVarDefault(n) end,
	RegisterCVar = function(n, v) if RegisterCVar then RegisterCVar(n, v) end end,
})

fill(ns("C_ChatInfo"), {
	SendAddonMessage = function(prefix, text, chatType, target) return SendAddonMessage(prefix, text, chatType, target) end,
	RegisterAddonMessagePrefix = function() return true end,
	IsAddonMessagePrefixRegistered = function() return true end,
	SendChatMessage = function(msg, chatType, lang, target) return SendChatMessage(msg, chatType, lang, target) end,
	GetNumActiveChannels = function() return #{ GetChannelList() } / 2 end,
})

fill(ns("C_FriendList"), {
	GetNumFriends = function() return GetNumFriends() end,
	GetNumOnlineFriends = function() return select(2, GetNumFriends()) end,
	ShowFriends = function() ShowFriends() end,
	AddFriend = function(n, note) AddFriend(n) if note then SetFriendNotes(n, note) end end,
	RemoveFriend = function(n) RemoveFriend(n) end,
	GetFriendInfoByIndex = function(i)
		local name, level, class, area, connected, status, note = GetFriendInfo(i)
		if not name then return nil end
		return { name = name, level = level, className = class, area = area, connected = connected, afk = status == CHAT_FLAG_AFK, dnd = status == CHAT_FLAG_DND, notes = note }
	end,
	IsFriend = function(guidOrName)
		for i = 1, GetNumFriends() do if GetFriendInfo(i) == guidOrName then return true end end
		return false
	end,
	IsIgnored = function(name) for i = 1, GetNumIgnores() do if GetIgnoreName(i) == name then return true end end return false end,
	AddIgnore = function(n) AddIgnore(n) end,
	SendWho = function(f) SendWho(f) end,
})
fill(ns("C_BattleNet"), { GetFriendAccountInfo = function() return nil end, GetFriendNumGameAccounts = function() return 0 end, GetFriendGameAccountInfo = function() return nil end })

fill(ns("C_PartyInfo"), {
	InviteUnit = function(n) InviteUnit(n) end,
	LeaveParty = function() LeaveParty() end,
	ConvertToRaid = function() ConvertToRaid() end,
	GetLootMethod = function() return GetLootMethod() end,
	IsPartyFull = function() return GetNumPartyMembers() >= 4 end,
})

fill(ns("C_GossipInfo"), {
	GetText = function() return GetGossipText() end,
	GetNumOptions = function() return GetNumGossipOptions() end,
	GetNumActiveQuests = function() return GetNumGossipActiveQuests() end,
	GetNumAvailableQuests = function() return GetNumGossipAvailableQuests() end,
	GetOptions = function()
		local r, raw = {}, { GetGossipOptions() }
		for i = 1, #raw, 2 do r[#r + 1] = { name = raw[i], type = raw[i + 1], icon = nil, gossipOptionID = (i + 1) / 2, orderIndex = (i + 1) / 2 } end
		return r
	end,
	SelectOption = function(id) SelectGossipOption(id) end,
	SelectOptionByIndex = function(i) SelectGossipOption(i) end,
	GetActiveQuests = function()
		local r, raw = {}, { GetGossipActiveQuests() }
		for i = 1, #raw, 4 do r[#r + 1] = { title = raw[i], questLevel = raw[i + 1], isTrivial = raw[i + 2], isComplete = raw[i + 3], questID = (i + 3) / 4 } end
		return r
	end,
	GetAvailableQuests = function()
		local r, raw = {}, { GetGossipAvailableQuests() }
		for i = 1, #raw, 3 do r[#r + 1] = { title = raw[i], questLevel = raw[i + 1], isTrivial = raw[i + 2], questID = (i + 2) / 3 } end
		return r
	end,
	SelectActiveQuest = function(i) SelectGossipActiveQuest(i) end,
	SelectAvailableQuest = function(i) SelectGossipAvailableQuest(i) end,
	CloseGossip = function() CloseGossip() end,
})

do
	local completed = {}
	local f = CreateFrame("Frame")
	f:RegisterEvent("QUEST_QUERY_COMPLETE")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("QUEST_TURNED_IN")
	f:SetScript("OnEvent", function(_, event, id)
		if event == "PLAYER_LOGIN" then QueryQuestsCompleted()
		elseif event == "QUEST_QUERY_COMPLETE" then GetQuestsCompleted(completed)
		elseif event == "QUEST_TURNED_IN" and id then completed[id] = true end
	end)
	local function idOf(i) local link = GetQuestLink(i) return link and tonumber(link:match("quest:(%d+)")) end
	fill(ns("C_QuestLog"), {
		GetNumQuestLogEntries = function() return GetNumQuestLogEntries() end,
		GetInfo = function(i)
			local title, level, tag, group, header, collapsed, complete, daily = GetQuestLogTitle(i)
			if not title then return nil end
			return { title = title, level = level, suggestedGroup = group, isHeader = header, isCollapsed = collapsed,
				isComplete = complete, frequency = daily and 1 or 0, questID = idOf(i) or 0, questLogIndex = i }
		end,
		GetLogIndexForQuestID = function(id) local i = GetQuestLogIndexByID(id) return i > 0 and i or nil end,
		GetQuestIDForLogIndex = idOf,
		IsComplete = function(id) return IsQuestComplete(id) end,
		IsOnQuest = function(id) return GetQuestLogIndexByID(id) > 0 end,
		IsQuestFlaggedCompleted = function(id) return completed[id] == true end,
		GetTitleForQuestID = function(id) local i = GetQuestLogIndexByID(id) return i > 0 and GetQuestLogTitle(i) or nil end,
		GetQuestTagInfo = function(id) return nil end,
		GetQuestInfo = function(id) local i = GetQuestLogIndexByID(id) return i > 0 and GetQuestLogTitle(i) or nil end,
		GetQuestObjectives = function(id)
			local i = GetQuestLogIndexByID(id)
			local r = {}
			for o = 1, i > 0 and GetNumQuestLeaderBoards(i) or 0 do
				local text, objType, finished = GetQuestLogLeaderBoard(o, i)
				local have, need = text and text:match("(%d+)/(%d+)")
				r[o] = { text = text, type = objType, finished = finished, numFulfilled = tonumber(have) or 0, numRequired = tonumber(need) or 0 }
			end
			return r
		end,
		GetSelectedQuest = function() local i = GetQuestLogSelection() return idOf(i) end,
		SetSelectedQuest = function(id) local i = GetQuestLogIndexByID(id) if i > 0 then SelectQuestLogEntry(i) end end,
		GetMaxNumQuestsCanAccept = function() return MAX_QUESTLOG_QUESTS or 25 end,
		GetQuestsCompleted = function() local r = {} for k in pairs(completed) do r[#r + 1] = k end return r end,
	})
end

fill(ns("C_CurrencyInfo"), {
	GetCoinTextureString = function(m) return GetCoinTextureString(m) end,
	GetCoinText = function(m) return GetCoinText(m) end,
})
fill(ns("C_DeathInfo"), { GetSelfResurrectOptions = function() return {} end, GetCorpseMapPosition = function() return nil end })
fill(ns("C_SummonInfo"), {
	GetSummonConfirmSummoner = function() return GetSummonConfirmSummoner() end,
	GetSummonConfirmAreaName = function() return GetSummonConfirmAreaName() end,
	GetSummonConfirmTimeLeft = function() return GetSummonConfirmTimeLeft() end,
	ConfirmSummon = function() ConfirmSummon() end,
	CancelSummon = function() CancelSummon() end,
})
fill(ns("C_Sound"), {
	IsPlaying = function() return false end,
	PlayItemSound = function() end,
	GetSoundScaledVolume = function() return 1 end,
})
fill(ns("C_SkillInfo"), { GetSkillLineInfoByID = function() return nil end })
fill(ns("C_PaperDollInfo"), { GetMinItemLevel = function() return nil end, GetInspectItemLevel = function() return 0 end, OffhandHasWeapon = function() return OffhandHasWeapon() end })
fill(ns("C_LFGList"), { HasActiveEntryInfo = function() return false end, GetActiveEntryInfo = function() return nil end })
fill(ns("C_EventUtils"), { IsEventValid = function(e)
	local f = CreateFrame("Frame")
	local ok = pcall(f.RegisterEvent, f, e)
	f:UnregisterAllEvents()
	return ok
end })
fill(ns("C_VoiceChat"), { SpeakText = function() end, StopSpeakingText = function() end, GetTtsVoices = function() return {} end })
fill(ns("C_EditMode"), { SetActiveLayout = function() end, GetLayouts = function() return { layouts = {}, activeLayout = 1 } end })
fill(ns("C_TransmogCollection"), { GetItemInfo = function() return nil end, GetSourceInfo = function() return nil end, PlayerHasTransmog = function() return false end })
fill(ns("C_Traits"), { GetConfigInfo = function() return nil end, GetTreeNodes = function() return {} end, GetNodeInfo = function() return nil end, GetSubTreeInfo = function() return nil end })
fill(ns("C_ClassTalents"), { GetActiveConfigID = function() return nil end, GetActiveHeroTalentSpec = function() return nil end, GetHeroTalentSpecsForClassSpec = function() return nil end })
fill(ns("C_SpecializationInfo"), { GetSpecialization = function() return GetActiveTalentGroup and GetActiveTalentGroup() or 1 end, GetSpecializationInfo = function() return nil end })
fill(ns("C_Texture"), { GetAtlasInfo = function(atlas) return TemucraftCompat.atlases and TemucraftCompat.atlases[atlas] end })
fill(ns("C_MountJournal"), { GetMountIDs = function() return {} end, GetNumMounts = function() return GetNumCompanions("MOUNT") end })
fill(ns("C_NamePlate"), { GetNamePlates = function() return {} end, GetNamePlateForUnit = function() return nil end })
fill(ns("C_PlayerInfo"), { GUIDIsPlayer = function(g) return g and tonumber(g:sub(5, 5), 16) == 0 end })
fill(ns("C_DateAndTime"), { GetCurrentCalendarTime = function()
	local wd, m, d, y = CalendarGetDate()
	local h, mi = GetGameTime()
	return { weekday = wd, month = m, monthDay = d, year = y, hour = h, minute = mi }
end, GetServerTimeLocal = function() return time() end })

-- Enum: the values the ported addons read
Enum = Enum or {}
fill(Enum, {
	SeasonID = { NoSeason = 0, SeasonOfMastery = 1, SeasonOfDiscovery = 2, Hardcore = 3 },
	ItemQuality = { Poor = 0, Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Artifact = 6, Heirloom = 7, Standard = 1, Good = 2, Superior = 3 },
	ItemClass = { Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Projectile = 6, Tradegoods = 7, ItemEnhancement = 8, Recipe = 9, Quiver = 11, Questitem = 12, Key = 13, Miscellaneous = 15, Glyph = 16 },
	UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 },
	PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6 },
	ChatChannelType = { None = 0, Custom = 1, PrivateParty = 2, PublicParty = 3, Communities = 4 },
	TooltipDataType = { Item = 0, Spell = 1, Unit = 2 },
})
