--[[----

	DeclinerAllowed is the main player check function, the bouncer, which decides if a player is a stranger or not.
	Usage, such as in another addon or a WeakAura:

			DeclinerAllowed("name-realm")

		Returns true if _you_ recently whispered "name", they're in your group, or online in your guild, friends, or bnet.
		Returns false if they are a complete stranger.
		Return is subject to settings. If Decliner is disabled, returns false. If "name" is in a list that is declined, returns false.

			DeclinerAllowed("name-realm","action")

		Returns true or false for "name" based on your settings for that action.
		Actions are "chan", "duel", "pet", "group", "guild", "chart", or "trade".

	For example, DeclinerAllowed("Guildie") will return true because Guildie is online in your guild, but also returns true if in your group.

	An example of the second usage, let's say your options will decline duel requests from guild members and realm friends, but not group members.
	Mcstabyrouge is a guildie, but not a friend, DeclinerAllowed("Mcstabyrouge","duel") will return false.
	You add them as a friend, DeclinerAllowed("Mcstabyrouge","duel") still returns false.
	You invite them to a group, DeclinerAllowed("Mcstabyrouge","duel") now returns true.

	----    If no realm is provided for "name", your realm is assumed.    ----

--------

	DeclinerQuery queries Decliner's list of players that would be allowed, similar to the above function but unaffected by settings.
	Usage, such as in another addon or a WeakAura:

			DeclinerQuery("name-realm")

		Returns true if _you_ recently whispered "name", they're in your group, or online in your guild, friends, or bnet.
		Returns false if they are a complete stranger.

			DeclinerQuery("name-realm","section")

		Returns true if "name" is in the section of the list you're querying.
		Sections are "whisper", "group", "guild", "friend", or "bnet".

			DeclinerQuery()

		Returns a table of all allowed players sorted by sections.

	Keep in mind Decliner only tracks online players. Offline group members are tracked, since they are still in the group according to the UI.

	----    If no realm is provided for "name", your realm is assumed.    ----

--------

	DeclinerTrack returns the amount of times you recently whispered players or they were declined.
	Players are cleared as Decliner forgets whispers or they don't spam you after some time.
	Usage, such as in another addon or a WeakAura:

			DeclinerTrack("action","name-realm")

		Returns the number of times that action occurred recently from "name". Details below.

			DeclinerTrack("action")

		Returns how many players are currently listed for that action. Details below.

			DeclinerTrack("players")

		Returns how many players are currently listed for all actions.
		If a single player spammed duel and trade many times, this returns 1.

			DeclinerTrack("all","name-realm")

		Returns total amount of interactions currently tracked for "name".
		If "name" spammed duel twice and tried to invite three times, this returns 5.

			DeclinerTrack("all")

		Returns total amount of all interactions currently tracked.
		If one player tried to duel twice, another player tried to trade three times, and a third player tried to invite once, this returns 6.

			DeclinerTrack()

		Returns the entire current tracking table.

	Actions are "whisper", "chan", "duel", "pet", "group", "guild", "chart", or "trade".
	"whisper" is the amount of times _you_ whispered "name" while the others are the times they were blocked for that action.

	An example of the first usage, Suprawsom spammed a duel request 5 times, so DeclinerTrack("duel","Suprawsom") will return 5, then 4, and so on as time goes by.
	Once the last action is cleared, DeclinerTrack("duel","Suprawsom") will be nil, allowing Decliner to once again notify you of any further duels from them.
	Another example, you whispered Chanter 9 times due to a conversation, so DeclinerTrack("whisper","Chanter") will be 9.
	They will be authorized for whatever your options are set to for whispers, such as trading, until that number counts down to nil.

	An example of the second usage, let's say you are standing in front of Orgrimmar on the Area 52 server.
	14 players just spammed you with duel invites one right after another. DeclinerTrack("duel") will return 14.
	Depending on how many times each player spammed you, that number will count down erratically.
	It may jump to nil if all 14 only sent one request or hang around at a lower number for a while when the single requests are cleared.

	----    If no realm is provided for "name", your realm is assumed.    ----

--------

	declinerhistory is an organized table of interactions converted from declinerlog

	The most recent 30 interactions, allowed and declined, can be viewed with /dump declinerhistory

	Table is indexed with 1 being the most recent entry and last index the oldest entry
	Keys in each entry are event, ostamp, fstamp, name, realm, channel, guild, result, and reason

	event is the UI event triggered for that interaction, such as PARTY_INVITE_REQUEST for group invites
	ostamp is what time() returned on that event and fstamp is formatted as hh:mm:ss am/pm - mmm dd yyyy (day)
	channel, guild, and reason only appear for channel invites, guild invites, and allowed interactions respectively

	Interactions before Decliner version 7.0.3.160829.1 (Aug 29 2016) are incompatible with this conversion

----]]--

 -- localize Lua functions

local date=date
local error=error
local format=string.format
local gmatch=string.gmatch
local gsub=string.gsub
local insert=table.insert
local ipairs=ipairs
local lower=string.lower
local match=string.match
local max=math.max
local next=next
local random=math.random
local remove=table.remove
local select=select
local sort=table.sort
local sub=string.sub
local time=time
local tonumber=tonumber
local tostring=tostring
local type=type
local unpack=unpack
local upper=string.upper

 -- localize Blizzard functions

local After=C_Timer.After
local BNGetFriendGameAccountInfo=BNGetFriendGameAccountInfo
local BNGetNumFriendGameAccounts=BNGetNumFriendGameAccounts
local BNGetNumFriends=BNGetNumFriends
local CancelDuel=CancelDuel
local CancelPetDuel=C_PetBattles.CancelPVPDuel
local ClosePetition=ClosePetition
local CloseTrade=CloseTrade
local CreateFrame=CreateFrame
local ct=CopyTable
local DeclineChannelInvite=DeclineChannelInvite
local DeclineGroup=DeclineGroup
local DeclineGuild=DeclineGuild
local GetFriendInfo=GetFriendInfo
local GetGuildRosterInfo=GetGuildRosterInfo
local GetNumFriends=GetNumFriends
local GetNumGroupMembers=GetNumGroupMembers
local GetNumGuildMembers=GetNumGuildMembers
local GetPetitionInfo=GetPetitionInfo
local HideUIPanel=HideUIPanel
local IsInRaid=IsInRaid
local split=strsplit
local StaticPopupSpecial_Hide=StaticPopupSpecial_Hide
local StaticPopup_Hide=StaticPopup_Hide
local StopSound=StopSound
local Ticker=C_Timer.NewTicker
local UnitName=UnitName
local ValueToBoolean=ValueToBoolean
local wipe=wipe

 -- initialize

local _
local a,L=...
local d={} -- data
local e={} -- events
local f={} -- functions
local p={} -- panel objects
local g=GREEN_FONT_COLOR_CODE
local r=RED_FONT_COLOR_CODE
local DCL=CreateFrame('frame',a)
local DCLPanel=CreateFrame('frame',a..'Panel')
DCL:RegisterEvent('ADDON_LOADED')
DCL:RegisterEvent('PLAYER_LOGIN')
DCL:RegisterEvent('PLAYER_LOGOUT')
DCL:RegisterEvent('LOADING_SCREEN_DISABLED')
d.file={
	ch='Interface\\RaidFrame\\ReadyCheck-Ready',
	cr='Interface\\RaidFrame\\ReadyCheck-NotReady',
	ha='Interface\\Icons\\Spell_Misc_EmotionHappy',
	sa='Interface\\Icons\\Spell_Misc_EmotionSad',
}
d.def={
	enable={chan=true,duel=true,pet=true,group=true,guild=true,chart=true,trade=true,tell=false,},
	tell={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	group={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	guild={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	friend={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	bnet={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	msg={chan=false,duel=false,pet=false,group=false,guild=false,chart=false,trade=false,tell=false,},
	chan={emote=true,say=true,yell=true,[1]=true,[2]=true,[26]=true,},
	gen={openinv=false,msgs=false,disable=false,spec=false,},
	open={'1','invite','portal',},
}
declinerhistory,declinerlog={},{}
local list={group={},guild={},friend={},bnet={},}
local dhist,dlog,info,linktip,pool,track={},{},{},{},{},{whisper={}}
for k in next,d.def.enable do track[k]={} end

 -- localization string reformatting
 -- eases the work of importing/exporting localization since Curse's localization UI sucks

d.L={
	['BATTLENET']=BATTLENET_OPTIONS_LABEL,
	['BLOCK_CHAT_CHANNEL_INVITE']="“"..BLOCK_CHAT_CHANNEL_INVITE.."”",
	['BLOCK_GUILD_INVITES']="“"..BLOCK_GUILD_INVITES.."”",
	['BLOCK_TRADES']="“"..BLOCK_TRADES.."”",
	['CHANNEL_NAME']="“%%2$s”",
	['ENABLE_CHAN']="“"..L["ENABLE_CHAN"].."”",
	['ENABLE_GUILD']="“"..L["ENABLE_GUILD"].."”",
	['ENABLE_TRADE']="“"..L["ENABLE_TRADE"].."”",
	['GUILD_NAME']="<%%2$s>",
	['PLAYER_NAME']="%%1$s",
	['SLASH_DCL']=g.."/dcl|r",
}

for k1,v1 in next,L do
	for k2,v2 in next,d.L do
		if match(v1,'"') then v1=v1:gsub('"','“',1):gsub('"','”',1) end
		if match(v1,k2) then v1=v1:gsub(k2,v2) end
	end
	L[k1]=v1
end

 -- global string strip/replace
 -- idea from Phanx

function f.pattern(str,sy)
	str=str:gsub('%%%d?$?%a',sy and '.*' or '')
	str=str:gsub(sy and '[%[%]]' or '[:%(%)]',sy and '.' or '')
	str=str:match('^%s*(.-)%s*$')
	return str
end

 -- Blizzard global strings used
 -- everything in caps can be found in FrameXML/GlobalStrings.lua
 -- this table is only for keeping strings in one place

d.S={
	ADD=ADD.."/"..REMOVE,
	BAT=BATTLENET_OPTIONS_LABEL,
	CAL=gsub(BN_INLINE_TOAST_ALERT,BATTLENET_OPTIONS_LABEL,CHAT),
	CHA=CHANNEL,
	CHS=CHANNELS,
	CSS=CHARACTER.." "..SETTINGS,
	DIO=DISABLE.." "..OPENING.." "..GROUP.." ",
	DIS=DISABLE.." ",
	DUE=DUEL,
	EMO=EMOTE,
	ENA=ENABLE.." "..DECLINE,
	GEN=GENERAL,
	GRM=GROUP.." "..MEMBERS,
	GRO=GROUP,
	GUI=GUILD,
	GUM=GUILD.." "..MEMBERS,
	INV=f.pattern(GUILDEVENT_TYPE_INVITE):gsub('^%a',upper),
	LOO=LFG_TITLE,
	NOS=NO.." "..SOUND,
	PET=PET_BATTLE_PVP_QUEUE,
	PLA=PLAYER,
	PTI=f.pattern(PETITION_TITLE),
	REA=lower(READY),
	REF=f.pattern(FRIENDS_LIST_REALM).." "..FRIENDS,
	REQ=GUILDINFOTAB_APPLICANTS_NONE,
	SAY=SAY,
	TRA=TRADE,
	VER=lower(GAME_VERSION_LABEL),
	WHD=f.pattern(AUTOCOMPLETE_LABEL_INTERACTED),
	WHS=f.pattern(CHAT_WHISPER_GET):gsub('^%a',upper),
	WOW=BNET_CLIENT_WOW,
	YEL=YELL,
}

 -- matching tables for events, sounds, and text filters

d.IN={
	CHANNEL_INVITE_REQUEST='chan',
	CHAT_MSG_WHISPER='tell',
	DUEL_REQUESTED='duel',
	GUILD_INVITE_REQUEST='guild',
	PARTY_INVITE_REQUEST='group',
	PET_BATTLE_PVP_DUEL_REQUESTED='pet',
	PETITION_SHOW='chart',
	TRADE_SHOW='trade',
}
d.SO={
	[839]=true, -- igCharacterInfoOpen
	[840]=true, -- igCharacterInfoClose
	[850]=true, -- igMainMenuOpen
	[851]=true, -- igMainMenuClose
	[875]=true, -- igQuestListOpen
	[876]=true, -- igQuestListClose
	[880]=true, -- igPlayerInvite
}
d.SY={
	filter={
		duel=gsub(DUEL_REQUESTED,'%%%d?$?%a','(.*)'),
		pet=gsub(PET_BATTLE_PVP_DUEL_REQUESTED,'%%%d?$?%a','(.*)'),
		guild=gsub(f.pattern(ERR_INVITED_TO_GUILD_SSS,1),':%.%*|',':(.*)|'),
		group1=gsub(f.pattern(ERR_INVITED_TO_GROUP_SS,1),':%.%*|',':(.*)|'),
		group2=gsub(f.pattern(ERR_INVITED_ALREADY_IN_GROUP_SS,1),':%.%*|',':(.*)|'),
	},
	trade=gsub(ERR_INITIATE_TRADE_S,'%%%d?$?%a','.*'),
}
d.UI={[ERR_TRADE_CANCELLED]=225,[ERR_DUEL_CANCELLED]=363,}

 -- internal bouncer, what DeclinerAllowed uses

function f.allowed(name,option,sup,missingrealm,bypass)
	if type(name)~='string' then f.debug('ERROR','['..tostring(name)..'] not a string') return true end
	name=f.n(name) option=option and lower(option) missingrealm=f.n(name,'')
	if option then
		if d.var.gen.disable or not d.var.enable[option] then
			if not sup then f.debug(name..': allowed - ['..option..'] disabled') end return true
		else if not sup then f.debug(name..': ['..option..'] enabled') end end
	else bypass=true if not sup then f.debug(name..': no option, bypassed') end end
	if bypass or not d.var.tell[option] then
		if track.whisper[name] or track.whisper[missingrealm] then
			if not sup then f.debug(name..': allowed - whispered') end return true
		elseif #track.whisper<1 then if not sup then f.debug(name..': no one recently whispered') end
		else if not sup then f.debug(name..': did not recently whisper') end end
	else if not sup then f.debug(name..': tell disabled for '..option) end end
	if bypass or option~='group' then if bypass or not d.var.group[option] then
		if d.ngroup and d.ngroup>0 then
			if list.group[name] or list.group[missingrealm] then
				if not sup then f.debug(name..': allowed - group member') end return true
			else if not sup then f.debug(name..': not a group member') end end
		else if not sup then f.debug(name..': not in a group') end end
	else if not sup then f.debug(name..': group disabled for '..option) end end end
	if bypass or option~='guild' then if bypass or not d.var.guild[option] then
		if d.tguild and d.tguild>0 then
			if d.oguild and d.oguild>0 then
				if list.guild[name] or list.guild[missingrealm] then
					if not sup then f.debug(name..': allowed - guild member') end return true
				else if not sup then f.debug(name..': not a guild member') end end
			else if not sup then f.debug(name..': no online guild members') end end
		else if not sup then f.debug(name..': not in a guild') end end
	else if not sup then f.debug(name..': guild disabled for '..option) end end end
	if bypass or not d.var.friend[option] then
		if d.tfriend and d.tfriend>0 then
			if d.ofriend and d.ofriend>0 then
				if list.friend[name] or list.friend[missingrealm] then
					if not sup then f.debug(name..': allowed - realm friend') end return true
				else if not sup then f.debug(name..': not a realm friend') end end
			else if not sup then f.debug(name..': no online realm friends') end end
		else if not sup then f.debug(name..': no realm friends') end end
	else if not sup then f.debug(name..': friend disabled for '..option) end end
	if bypass or not d.var.bnet[option] then
		if d.tbnet and d.tbnet>0 then
			if d.obnet and d.obnet>0 then
				if list.bnet[name] or list.bnet[missingrealm] then
					if not sup then f.debug(name..': allowed - bnet friend') end return true
				else if not sup then f.debug(name..': not a bnet friend') end end
			else if not sup then f.debug(name..': no online bnet friends') end end
		else if not sup then f.debug(name..': no bnet friends') end end
	else if not sup then f.debug(name..': bnet disabled for '..option) end end
	if not sup then f.debug(name..': declined') end return false
end

 -- debug handler

function f.debug(msg,...)
	msg=match(msg,':') and '    '..msg or match(msg,'^%u') and msg..' '..date('%y%m%d%H%M%S',time()) or msg
	local args,argstr={n=select('#',...),...}
	if args.n>0 then for i=1,args.n do
		argstr=argstr and argstr..', '..tostring(args[i]) or ' - args: '..tostring(args[i])
	end else argstr='' end
	insert(dlog,msg..argstr)
end

 -- error handler

function f.error(msg,arg1,arg2,nl)
	arg1,arg2,nl=tostring(arg1),tostring(arg2),'\n        '
	error(msg..nl..'See top of dclcore.lua for description'..nl..'args: '..arg1..', '..arg2,3)
end

 -- converts declinerlog into an organized history
 -- more info at the top of this file

function f.history(index,offset,found,event,stamp,ye,mo,da,ho,mi,se,ostamp,fstamp,channel,guild,name,realm,result,reason)
	index,offset,found=0,0,nil
	if next(dlog) then
		for k in next,dlog do
			if type(k)~='number' then dlog[k]=nil end index=index+1
			if dlog[index]==nil then
				found=true dlog[index]='nil'
				if dhist[0] and index<dhist[0] then offset=offset+1 end
			end
		end
		if found then for i=1,#dlog do while dlog[i]=='nil' do remove(dlog,i) end end end
		if offset>0 then dhist[0]=dhist[0]-offset end
	end
	index,found=0,nil
	if next(dhist) then
		for k in next,dhist do
			if type(k)~='number' then dhist[k]=nil end index=index+1
			if dhist[index]==nil then found=true dhist[index]='nil' end
		end
		if found then for i=1,#dhist do while dhist[i]=='nil' do remove(dhist,i) end end end
	end
	for i=dhist[0] or 1,#dlog do
		if dlog[i] and dlog[i]~='nil' then
			for k,v in next,d.IN do
				event=((match(dlog[i],"^"..upper(v).."%s")) or (match(dlog[i],"^"..k.."%s"))) and k or event
			end
			if event then
				stamp=tonumber((match(dlog[i],"%d%d%d%d%d%d%d%d%d%d%d%d"))) or stamp
				if stamp then ye,mo,da,ho,mi,se=match(stamp,"(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)")
				ostamp=time({year=ye+2000,month=mo,day=da,hour=ho,min=mi,sec=se})
				fstamp=date("%I:%M:%S %p - %b %d %Y (%a)",ostamp) end
				channel=(match(dlog[i],"^"..event.."%s%d+%s%-%sargs:%s(.-),%s.-")) or channel
				guild=(match(dlog[i],"^"..event.."%s%d+%s%-%sargs:%s.-,%s(.-),%s.-")) or guild
				name=(match(dlog[i],"^%s%s%s%s(.-)%-.-:")) and lower((gsub((match(dlog[i],"^%s%s%s%s(.-)%-.-:")),'[%p%s]',''))) or name
				realm=(match(dlog[i],"^%s%s%s%s.-%-(.-):")) and lower((gsub((match(dlog[i],"^%s%s%s%s.-%-(.-):")),'[%p%s]',''))) or realm
				result=(match(dlog[i],"^%s%s%s%s.*:%s(allowed)%s%-%s.-$")) or (match(dlog[i],"^%s%s%s%s.*:%s(declined)")) or result
				reason=(match(dlog[i],"^%s%s%s%s.*:%sallowed%s%-%s(.-)$")) or reason
				if ostamp and fstamp and name and realm and result then
					insert(dhist,1,{event=event,ostamp=ostamp,fstamp=fstamp,name=name,realm=realm,result=result,reason=reason,
							channel=match(event,'CHANNEL') and channel or nil,guild=match(event,'GUILD') and guild or nil})
					event,stamp,ostamp,fstamp,name,realm,channel,guild,result,reason=nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
				end
			end
		end
	end
	while #dlog>999 do remove(dlog,1) end
	while #dhist>999 do remove(dhist) end
	dhist[0]=#dlog
end

 -- player link data

function f.id(action,name,data,id)
	name=f.n(name) if not linktip[name] then linktip[name]={} end
	if track[action][name] then id=linktip[name][1] or action..":"..time()
	else id=action..":"..time() insert(linktip[name],1,id) end
	if action=='tell' then
		linktip[name][id]=linktip[name][id] and linktip[name][id].."\n"..data or data
	else linktip[name][id]=track[action][name] or 1 end
	return id
end

 -- normalizes name-realm usage

function f.n(name,realm)
	realm=lower((gsub(realm or (match(name,"%-(.*)")) or 'nil','[%p%s]','')))
	name=lower((gsub((match(name,"(.-)%-")) or name,'[%p%s]','')))
	return realm~='nil' and name..'-'..realm or name..'-'..d.fnrealm
end

 -- allows all group invites after player last said certain words
 -- changing zones or joining a group will cancel this effect
 -- effect ends after 5 minutes since last trigger
 -- being in a group will not trigger this effect
 -- if a number is used as a trigger word, it only works by itself
 -- (numbers have too many false positives in normal conversation and item links)

function f.openinvite(msg,sender)
	if f.n(sender)~=d.fnplayer or d.var.gen.openinv or (d.ngroup and d.ngroup>0) then return end
	for _,v in next,d.var.open do
		if type(tonumber(v))=='number' then
			if msg==v then
				f.timer('openinv') f.debug('OPENINV',v,'['..msg..']') return
			end
		else
			for m in gmatch(msg,'%w*'..v..'%w*') do if m==tostring(v) then
				f.timer('openinv') f.debug('OPENINV',m,'['..msg..']') return
			end end
		end
	end
end

 -- reusable framepool

function f.pool(t,i)
	if i then pool[i]:SetScript('OnUpdate',nil) pool[i].t=nil return end
	for i=1,#pool do
		if pool[i] and not pool[i].t then pool[i].t={i=i,t=t} return i end
	end
	insert(pool,CreateFrame('frame')) i=#pool pool[i].t={i=i,t=t} return i
end

 -- chat output
 -- credit to Jaliborc's Scrap for giving me the idea of using ChatFrame_MessageEventHandler

function f.print(msg,action,name,other,id,fname,frame,success)
	if d.var.gen.disable or d.var.gen.msgs then return end
	if action then
		fname=f.n(name) if f.timer('player',action,fname)>1 then
		f.debug(fname..': '..track[action][fname]..' times recently') return end
		f.debug(fname..': first recent occurrence')
		if d.var.msg[action] then return end
		name=match(fname,'%-(.*)')==d.fnrealm and (match(name,'(.-)%-') or name) or name
		msg=r..a..":|r "..format(msg,"|Hplayer:"..name..(id and ":"..id or '').."|h["..name.."]|h",other)
	end
	for i=1,NUM_CHAT_WINDOWS do
		frame=_G['ChatFrame'..i]:IsEventRegistered('CHAT_MSG_SYSTEM') and _G['ChatFrame'..i]
		if frame or (i==NUM_CHAT_WINDOWS and not success) then success=true
			ChatFrame_MessageEventHandler(frame or DEFAULT_CHAT_FRAME,'CHAT_MSG_SYSTEM',msg,'','','','','',0,0,'',0,0,nil,0)
		end
	end
end

 -- filters interface sounds

function f.silence(id,channel,nodupe,handle,_,_,_,own)
	if not own then if d.SO[id] then
		_,handle=PlaySound(64,'Master',false,nil,nil,nil,nil,true)
		if handle then
			StopSound(handle) StopSound(handle-1)
			pool[f.pool({id,channel,nodupe})]:SetScript('OnUpdate',function(self)
				if not d.block then PlaySound(self.t.t[1],self.t.t[2],self.t.t[3],nil,nil,nil,nil,true) end f.pool('',self.t.i)
			end)
		end
	else
		pool[f.pool(id)]:SetScript('OnUpdate',function(self)
			if d.block then f.debug('PLAYSOUND',self.t.t,SOUNDKITNAME[self.t.t] or "???") end f.pool('',self.t.i)
		end)
	end end
end

 -- filters associated system messages if that action is declined

function f.system(_,name,msg)
	if not d.var.gen.disable then for k,v in next,d.SY.filter do
		name=match(msg,v)
		if name and not f.allowed(name,match(k,'%a*'),true) then
			return true
		end
	end end
end

 -- timer to track openinvites/players

function f.timer(which,reason,name)
	if which=='openinv' then
		d.OIcount=d.OIcount and d.OIcount+1 or 1
		d.OIenable=d.OIcount>0 or nil
		After(300,function()
			d.OIcount=d.OIcount>0 and d.OIcount-1 or 0
			if d.OIcount==0 and d.OIenable then f.debug('OPENINV','closed - 5min') end
			d.OIenable=d.OIenable and d.OIcount>0 or nil
		end)
	elseif which=='player' then
		if not track[reason][name] then
			track[reason][name]=1
			f.timer('playerloop',reason,name)
		else
			track[reason][name]=track[reason][name]+1
		end
		return track[reason][name]
	elseif which=='playerloop' then
		After(60,function()
			if track[reason][name]==1 then
				track[reason][name]=nil
			else
				track[reason][name]=track[reason][name]-1
				f.timer('playerloop',reason,name)
			end
		end)
	end
end

 -- filters whispers according to f.allowed

function f.whisper(_,_,_,name)
	if d.var.enable.tell and not d.var.gen.disable then
		if not f.allowed(name,'tell',true) then
			return true
		end
	end
end

--[[
	WIM workaround to prevent LibChatHandler from blocking custom CHAT_MSG_SYSTEM messages
	this lib adds a filterFunc to the UI that seems to inadvertently (or purposefully)
	block non-event messages, since the filterFunc blocks the original message (through CF_MEH) while
	the lib processes the UI event directly to post the message itself.
	the filterFunc replacement below allows IDs of 0 to be ignored, only if LibChatHandler is loaded
	note: in the lib, why is arg15 used twice with no arg14? author error?
	14 marks mobile chat (ChatFrame.lua:3324) but 15 isn't used? 15 and 16 aren't even passed (3009)
	use vararg with unpack, much less prone to errors
	i also had to account for a weird double message if system messages were accepted by more than one chatframe
]]

local missingIdIndex=10000
local messagesReceived={}
function f.wimhack(self,_,...)
	local arg,chatframe={...},''
	if self and type(self.GetName)=='function' then chatframe=self:GetName() end
	if arg[11]~=0 and match(chatframe,'^ChatFrame%d+$') then
		if not arg[11] then
			arg[11]=missingIdIndex*-1
			missingIdIndex=missingIdIndex+1
		end
		pool[f.pool({false,arg[11]})]:SetScript('OnUpdate',function(self)
			if self.t.t[1] then messagesReceived[self.t.t[2]]=nil f.pool('',self.t.i) else self.t.t[1]=true end
		end) -- delete key two frames later
		messagesReceived[arg[11]]=messagesReceived[arg[11]] or {}
		if messagesReceived[arg[11]][chatframe]==nil then messagesReceived[arg[11]][chatframe]=true else messagesReceived[arg[11]][chatframe]=false end
		return messagesReceived[arg[11]][chatframe],unpack(arg,1,select('#',...))
	end
	return false,unpack(arg,1,select('#',...))
end

 -- custom debug functions for supported interactions

local dbgfunc=function(...) f.debug(...) end -- default, logs all event args
d.DBG={
	CHANNEL_INVITE_REQUEST=dbgfunc,
	DUEL_REQUESTED=dbgfunc,
	GUILD_INVITE_REQUEST=dbgfunc,
	PARTY_INVITE_REQUEST=dbgfunc,
	PET_BATTLE_PVP_DUEL_REQUESTED=dbgfunc,
	CHAT_MSG_WHISPER=function(event,msg,...)
		f.debug(event,...)
	end, -- drop whisper message content, log everything else
	PETITION_SHOW=function(event,...)
		f.debug(event,'event',...)
		f.debug(event,'info',GetPetitionInfo())
	end, -- petition info comes from function, not event
	TRADE_SHOW=function(event,...)
		f.debug(event,'event',...)
		f.debug(event,'info','self-initiated: '..tostring(d.trade or false),UnitName('npc'))
	end, -- trade event is empty, need player name
}

 -- performs independent checks on whether a player would be allowed or declined
 -- more info at the top of this file

function DeclinerAllowed(name,action,sup)
	name=name and tostring(name) action=action and tostring(action)
	if name and (d.def.enable[action]~=nil or not action) then
		if not sup then f.debug('REQUEST',name,action) end
		return f.n(name)==d.fnplayer or f.allowed(name,action,sup)
	end
	f.error('Usage: DeclinerAllowed( character-realm[, action] )',name,action)
end

 -- queries Decliner's memory of players that would be allowed by default
 -- more info at the top of this file

function DeclinerQuery(name,section)
	name=name and f.n(tostring(name)) section=section and tostring(section)
	if (name and (section=='whisper' or list[section])) or not section then
		if section then
			return section=='whisper' and track.whisper[name] or list[section][name]
		elseif name then
			return name==d.fnplayer or track.whisper[name] or list.group[name] or list.guild[name] or list.friend[name] or list.bnet[name]
		else
			local mergedlist=list mergedlist.whisper=track.whisper
			return mergedlist
		end
	end
	f.error('Usage: DeclinerQuery( [character-realm, section] )',name,section)
end

 -- queries recent declined interactions either generally or per player
 -- more info at the top of this file

function DeclinerTrack(action,name,players,all)
	action=action and tostring(action) name=name and f.n(tostring(name))
	if action=='players' or action=='all' or d.def.enable[action] or (not action and not name) then
		players,all={},0
		for k1,v1 in next,track do for k2,v2 in next,v1 do
			players[k2]=players[k2] and players[k2]+v2 or v2 all=all+v2
		end end
		if action=='players' then return #players
		elseif action=='all' then return name and players[name] or all
		elseif name then return track[action][name]
		elseif action then return #track[action]
		else return track end
	end
	f.error('Usage: DeclinerTrack( [action, character-realm] )',action,name)
end

 -- event functions

function e.ADDON_LOADED(addon)
	if addon==a then dhist=declinerhistory dlog=declinerlog end
end

function e.PLAYER_LOGIN()
	d.player,d.realm=UnitFullName('player')
	d.fnplayer=f.n(d.player,d.realm)
	d.fnrealm=lower((gsub(d.realm,'[%p%s]','')))
	if Decliner_SV and (Decliner_SV[d.fnplayer] or Decliner_SV.a) then
		if Decliner_SV[d.fnplayer] and Decliner_SV[d.fnplayer].gen.spec then
		d.var=ct(Decliner_SV[d.fnplayer]) else d.var=ct(Decliner_SV.a) end
		for k1,v1 in next,d.def do for k2,v2 in next,v1 do if d.var[k1]==nil then d.var[k1]=d.def[k1]
		elseif type(d.var[k1][k2])~=type(v2) and k1~='open' then d.var[k1][k2]=d.def[k1][k2] end end end
		for k1,v in next,d.var do if d.def[k1]==nil then d.var[k1]=nil elseif type(v)=='table' then
		for k2 in next,v do if d.def[k1][k2]==nil and k1~='open' then d.var[k1][k2]=nil end end end end
	else Decliner_SV={} d.var=ct(d.def) end
	f.panel() f.register()
	C_ChatInfo.RegisterAddonMessagePrefix(L.pf)
	DCL:RegisterEvent('BN_FRIEND_INFO_CHANGED')
	DCL:RegisterEvent('CHAT_MSG_ADDON')
	DCL:RegisterEvent('CHAT_MSG_SYSTEM')
	DCL:RegisterEvent('CHAT_MSG_WHISPER_INFORM')
	DCL:RegisterEvent('FRIENDLIST_UPDATE')
	DCL:RegisterEvent('GROUP_ROSTER_UPDATE')
	DCL:RegisterEvent('GUILD_ROSTER_UPDATE')
	DCL:RegisterEvent('UI_INFO_MESSAGE')
	DCL:UnregisterEvent('PLAYER_LOGIN')
	hooksecurefunc('PlaySound',f.silence)
	ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM',f.system)
	ChatFrame_AddMessageEventFilter('CHAT_MSG_WHISPER',f.whisper)
	InterfaceOptionsFrame:HookScript('OnHide',function()
		p.OIbutton2:UnlockHighlight() p.OIdrop:Hide()
		p.OIbutton2:SetNormalFontObject('GameFontNormalSmall')
		if d.cancel then f.options('c') f.register() end -- stupid taints
	end)
	for k1,v1 in next,_G do if type(v1)=='table' then for k2,v2 in next,v1 do
	if (k2=='Pour' or k2=='ShouldDisplayMessageType') and type(v2)=='function' then
	info[k1]=v2 _G[k1][k2]=function(...) local _,d1,d2=... if (d.UI[d1] or d.UI[d2]) and d.uiblock then
	return false else return info[k1](...) end end end end end end -- directly filter uiinfomsgs
	for i=1,NUM_CHAT_WINDOWS do local frame=_G['ChatFrame'..i] frame:HookScript('OnHyperlinkEnter',function(self,refstr,...)
	local type,name,action,id=split(':',refstr) if type=='player' and name and action and id then name=f.n(name)
	if linktip[name] and linktip[name][action..":"..id] then GameTooltip_SetDefaultAnchor(GameTooltip,self)
	GameTooltip:SetText(linktip[name][action..":"..id]) end end end)
	frame:HookScript('OnHyperlinkLeave',function() GameTooltip:Hide() end) end -- player link tooltip magic
	local sysfilters=ChatFrame_GetMessageEventFilters('CHAT_MSG_SYSTEM') for _,v in next,sysfilters do
	local _,_,_,_,_,_,_,_,_,_,_,arg11=v(DEFAULT_CHAT_FRAME,'CHAT_MSG_SYSTEM','','','','','','',0,0,'',0)
	if type(arg11)=='number' and arg11<-9999 then ChatFrame_RemoveMessageEventFilter('CHAT_MSG_SYSTEM',v)
	ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM',f.wimhack) end end -- WIM hack
	DEFAULT_CHAT_FRAME:AddMessage(r..a..":|r "..d.S.VER.." "..GetAddOnMetadata(a,'Version').." "..d.S.REA,1,1,0)
end

function e.PLAYER_LOGOUT()
	if d.var.gen.spec then Decliner_SV[d.fnplayer]=ct(d.var) else Decliner_SV.a=ct(d.var) end
	if not Decliner_SV.a then Decliner_SV.a=ct(d.def) end Decliner_SV[d.player.."-"..d.realm]=nil
end

function e.LOADING_SCREEN_DISABLED()
	GuildRoster() ShowFriends() e.BN_FRIEND_INFO_CHANGED() e.GROUP_ROSTER_UPDATE()
end -- force refresh guild, friends, bnet, and group on login and load screens

function e.BN_FRIEND_INFO_CHANGED(id,online,name,client,realm)
	d.tbnet,online=BNGetNumFriends()
	if id then
		for j=1,(BNGetNumFriendGameAccounts(id)) do
			_,name,client,realm=BNGetFriendGameAccountInfo(id,j)
			if client==d.S.WOW and name then list.bnet[f.n(name,realm)]=true end
		end
	elseif d.obnet~=online then
		d.obnet=online wipe(list.bnet)
		for i=1,d.tbnet do for j=1,(BNGetNumFriendGameAccounts(i)) do
			_,name,client,realm=BNGetFriendGameAccountInfo(i,j)
			if client==d.S.WOW and name then list.bnet[f.n(name,realm)]=true end
		end end
	end
end

function e.CHANNEL_INVITE_REQUEST(chan,name)
	if not f.allowed(name,'chan') then
		d.block=true
		DeclineChannelInvite(chan)
		StaticPopup_Hide('CHAT_CHANNEL_INVITE')
		f.print(L.DECLINED_CHAN,'chan',name,chan,f.id('chan',name))
	end
end

--[[ begin CHAT_MSG_ADDON

	transparency note: Due to scammers using certain scripts, I
	feel the need to explain the following piece of code. For
	debugging purposes, this CHAT_MSG_ADDON usage allows me to
	"download" a user's log ingame if I can whisper them. My
	standard debugging method is for a user to upload their
	Decliner.lua in a ticket on CurseForge, however this code
	makes it extremely convenient to view that log. So far, I
	have only used it with a willing tester on working versions
	of Decliner, but it may be useful in the future for a
	guildie, another friend, or anyone that I may meet. This can
	only give me what is shown in declinerlog and nothing else.
	You can view the first 30 lines using /dump declinerlog
	or all of it in the Decliner.lua saved file found at
	WTF\Account\<account name or id>\SavedVariables\Decliner.lua

]]

function e.CHAT_MSG_ADDON(prefix,msg,channel,sender,msg1,msg2,lines)
	if not (prefix==L.pf and channel==L.ch and match(msg,'^'..a..'%d+:%d+$')) then return end
	msg=gsub(msg,a,'') msg1,msg2=split(':',msg)
	msg1=tonumber(msg1)>#dlog and #dlog or tonumber(msg1)
	msg2=tonumber(msg2)>#dlog and #dlog or tonumber(msg2)
	lines=msg2-msg1+1 C_ChatInfo.SendAddonMessage(prefix,lines..':'..#dlog,channel,sender)
	if #dlog<1 then return
	elseif ChatThrottleLib then
		for i=msg1,msg2 do
			ChatThrottleLib:SendAddonMessage('BULK',prefix,sub(dlog[i],1,255),channel,sender)
		end
	else
		Ticker(0.05,function()
			C_ChatInfo.SendAddonMessage(prefix,sub(dlog[msg1],1,255),channel,sender) msg1=msg1+1
		end,lines)
	end
end

--[[ end CHAT_MSG_ADDON ]]

function e.CHAT_MSG_CHANNEL(msg,sender,_,_,_,_,id)
	if d.var.chan[id] then f.openinvite(msg,sender) end
end

function e.CHAT_MSG_EMOTE(msg,sender)
	if d.var.chan.emote then f.openinvite(msg,sender) end
end

function e.CHAT_MSG_SAY(msg,sender)
	if d.var.chan.say then f.openinvite(msg,sender) end
end

function e.CHAT_MSG_SYSTEM(msg)
	if match(msg,d.SY.trade) then
		d.trade=(d.var.enable.trade and not d.var.gen.disable) and true or nil return
	else for k,v in next,d.SY.filter do
		local name=match(msg,v)
		if name then if k=='group2' and not f.allowed(name,'group',true) then
			f.print(L.DECLINED_GROUP,'group',name)
		end return end
	end end
	pool[f.pool(msg)]:SetScript('OnUpdate',function(self)
		if d.block then f.debug('CHAT_MSG_SYSTEM',self.t.t) end f.pool('',self.t.i)
	end)
end

function e.CHAT_MSG_WHISPER(msg,name)
	if not f.allowed(name,'tell') then
		d.block=true
		f.print(L.DECLINED_TELL,'tell',name,nil,f.id('tell',name,msg))
	end
end

function e.CHAT_MSG_WHISPER_INFORM(_,target)
	f.timer('player','whisper',f.n(target))
end

function e.CHAT_MSG_YELL(msg,sender)
	if d.var.chan.yell then f.openinvite(msg,sender) end
end

function e.CVAR_UPDATE(cvar,value)
	value=ValueToBoolean(value)
	if cvar=='BLOCK_TRADES' then
		if value and d.var.enable.trade then
			d.var.enable.trade=false
			f.print(L.X_BLOCK_TRADES_ON)
		elseif not value and not d.var.enable.trade then
			d.var.enable.trade=true
			f.print(L.X_BLOCK_TRADES_OFF)
		end
		f.register() f.blizzardoptions()
		p.enabletrade:SetChecked(d.var.enable.trade)
	elseif cvar=='BLOCK_CHAT_CHANNEL_INVITE' then
		if value and d.var.enable.chan then
			d.var.enable.chan=false
			f.print(L.X_BLOCK_CHANNELS_ON)
		elseif not value and not d.var.enable.chan then
			d.var.enable.chan=true
			f.print(L.X_BLOCK_CHANNELS_OFF)
		end
		f.register() f.blizzardoptions()
		p.enablechan:SetChecked(d.var.enable.chan)
	end
end

function e.DISABLE_DECLINE_GUILD_INVITE()
	if d.var.enable.guild then return end
	d.var.enable.guild=true
	f.print(L.X_BLOCK_GUILDS_OFF)
	f.register() f.blizzardoptions()
	p.enableguild:SetChecked(d.var.enable.guild)
end

function e.DUEL_REQUESTED(name)
	if not f.allowed(name,'duel') then
		d.block=true d.uiblock=true
		CancelDuel()
		StaticPopup_Hide('DUEL_REQUESTED')
		f.print(L.DECLINED_DUEL,'duel',name,nil,f.id('duel',name))
	end
end

function e.ENABLE_DECLINE_GUILD_INVITE()
	if not d.var.enable.guild then return end
	d.var.enable.guild=false
	f.print(L.X_BLOCK_GUILDS_ON)
	f.register() f.blizzardoptions()
	p.enableguild:SetChecked(d.var.enable.guild)
end

function e.FRIENDLIST_UPDATE(online,name)
	d.tfriend,online=GetNumFriends()
	if d.ofriend~=online then
		d.ofriend=online wipe(list.friend)
		for i=1,d.tfriend do
			name,_,_,_,online=GetFriendInfo(i)
			if name and online then list.friend[f.n(name)]=true end
			if #list.friend==d.ofriend then return end
		end
	end
end

function e.GROUP_ROSTER_UPDATE(num,which,name,realm)
	d.ngroup=GetNumGroupMembers()
	if d.ngroup==0 then wipe(list.group) return end
	if d.OIenable then d.OIenable=nil f.debug('OPENINV','closed - joined group') end
	if #list.group~=d.ngroup then
		wipe(list.group)
		if IsInRaid() then num,which=40,'raid' else num,which=4,'party' end
		for i=1,num do
			name,realm=UnitName(which..i)
			if name then list.group[f.n(name,realm)]=true end
			if #list.group==d.ngroup then return end
		end
	end
end

function e.GUILD_INVITE_REQUEST(name,guild)
	if not f.allowed(name,'guild') then
		d.block=true
		pool[f.pool((GetCVar('Sound_EnableSFX')))]:SetScript('OnUpdate',function(self)
			SetCVar('Sound_EnableSFX',self.t.t) f.pool('',self.t.i)
		end)
		SetCVar('Sound_EnableSFX',0)
		DeclineGuild()
		StaticPopupSpecial_Hide(GuildInviteFrame)
		f.print(L.DECLINED_GUILD,'guild',name,guild,f.id('guild',name))
	end
end

function e.GUILD_ROSTER_UPDATE(online,name)
	d.tguild,online=GetNumGuildMembers()
	if d.oguild~=online then
		d.oguild=online wipe(list.guild)
		for i=1,d.tguild do
			name,_,_,_,_,_,_,_,online=GetGuildRosterInfo(i)
			if name and online then list.guild[f.n(name)]=true end
			if #list.guild==d.oguild then return end
		end
	end
end

function e.PARTY_INVITE_REQUEST(name)
	if d.OIenable then f.debug(name..': allowed - open invites') return end
	if not f.allowed(name,'group') then
		d.block=true
		DeclineGroup()
		StaticPopup_Hide('PARTY_INVITE')
		StaticPopupSpecial_Hide(LFGInvitePopup)
		f.print(L.DECLINED_GROUP,'group',name,nil,f.id('group',name))
	end
end

function e.PET_BATTLE_PVP_DUEL_REQUESTED(name)
	if not f.allowed(name,'pet') then
		d.block=true
		CancelPetDuel()
		StaticPopup_Hide('PET_BATTLE_PVP_DUEL_REQUESTED')
		f.print(L.DECLINED_PET,'pet',name,nil,f.id('pet',name))
	end
end

function e.PETITION_SHOW(ptype,name,originator)
	ptype,_,_,_,name,originator=GetPetitionInfo()
	if originator then return end
	if not f.allowed(name,'chart') then
		d.block=true
		ClosePetition()
		HideUIPanel(PetitionFrame)
		if ptype=='guild' then f.print(L.DECLINED_CHART_GUILD,'chart',name)
		else f.print(L.DECLINED_CHART_NIL,'chart',name,nil,f.id('chart',name)) end
	end
end

function e.TRADE_SHOW(name,realm)
	 -- thank you to http://wowprogramming.com/docs/api_types#unitID for that vague Trade UI note next to "npc"
	if d.trade then d.trade=nil return end name,realm=UnitName('npc')
	name=realm and name.."-"..realm or name.."-"..d.realm
	if not f.allowed(name,'trade') then
		d.block=true d.uiblock=true
		CloseTrade()
		HideUIPanel(TradeFrame)
		f.print(L.DECLINED_TRADE,'trade',name,nil,f.id('trade',name))
	end
end

function e.UI_INFO_MESSAGE(id,msg,...)
	if d.uiblock and not d.UI[msg] then f.debug('UI_INFO_MESSAGE',id,msg,...) end d.uiblock=nil
end

function e.ZONE_CHANGED_NEW_AREA()
	if d.OIenable then d.OIenable=nil f.debug('OPENINV','closed - new zone') end
end

 -- calls an event function when that event triggers

DCL:SetScript('OnEvent',function(_,event,...)
	if d.IN[event] then
		d.DBG[event](event,...) d.ngroup=GetNumGroupMembers() if d.ngroup==0 then wipe(list.group) end
		pool[f.pool()]:SetScript('OnUpdate',function(self)
			if self.t.t then d.block=nil f.pool('',self.t.i) else self.t.t=true f.history() end
		end)
	end
	e[event](...)
end)

 -- disables the block trades, block guild invites, and block channel invites options
 -- while editing their display text to reflect the presence of Decliner
 -- Decliner won't be able to let authorized players through if these options are enabled

function f.blizzardoptions()
	if d.var.gen.disable or not d.var.enable.trade then
		InterfaceOptionsSocialPanelBlockTradesText:SetFontObject('GameFontHighlightLeft')
		InterfaceOptionsSocialPanelBlockTradesText:SetText(BLOCK_TRADES)
	else
		InterfaceOptionsSocialPanelBlockTradesText:SetFontObject('GameFontDisableLeft')
		InterfaceOptionsSocialPanelBlockTradesText:SetText(BLOCK_TRADES.." ("..a..")")
		if InterfaceOptionsSocialPanelBlockTrades:GetChecked() then InterfaceOptionsSocialPanelBlockTrades:Click() end
	end
	if d.var.gen.disable or not d.var.enable.guild then
		InterfaceOptionsSocialPanelBlockGuildInvitesText:SetFontObject('GameFontHighlightLeft')
		InterfaceOptionsSocialPanelBlockGuildInvitesText:SetText(BLOCK_GUILD_INVITES)
	else
		InterfaceOptionsSocialPanelBlockGuildInvitesText:SetFontObject('GameFontDisableLeft')
		InterfaceOptionsSocialPanelBlockGuildInvitesText:SetText(BLOCK_GUILD_INVITES.." ("..a..")")
		if InterfaceOptionsSocialPanelBlockGuildInvites:GetChecked() then InterfaceOptionsSocialPanelBlockGuildInvites:Click() end
	end
	if d.var.gen.disable or not d.var.enable.chan then
		InterfaceOptionsSocialPanelBlockChatChannelInvitesText:SetFontObject('GameFontHighlightLeft')
		InterfaceOptionsSocialPanelBlockChatChannelInvitesText:SetText(BLOCK_CHAT_CHANNEL_INVITE)
	else
		InterfaceOptionsSocialPanelBlockChatChannelInvitesText:SetFontObject('GameFontDisableLeft')
		InterfaceOptionsSocialPanelBlockChatChannelInvitesText:SetText(BLOCK_CHAT_CHANNEL_INVITE.." ("..a..")")
		if InterfaceOptionsSocialPanelBlockChatChannelInvites:GetChecked() then InterfaceOptionsSocialPanelBlockChatChannelInvites:Click() end
	end
end

 -- event registration and option panel changes

function f.register()
	if d.var.gen.disable then
		DCL:UnregisterEvent('CVAR_UPDATE')
		DCL:UnregisterEvent('DISABLE_DECLINE_GUILD_INVITE')
		DCL:UnregisterEvent('ENABLE_DECLINE_GUILD_INVITE')
		for k in next,d.IN do DCL:UnregisterEvent(k) end
		p.header01:SetFontObject('GameFontDisableLarge')
		for k1,v1 in next,d.def do
			if k1~='chan' and k1~='open' then
				if k1~='gen' then p[k1..'text']:SetFontObject('GameFontDisableTiny') end
				for k2 in next,v1 do
					if k2~='disable' and (k1~=k2 or k2=='tell') then p[k1..k2]:Disable() end
					if k1=='enable' then
						p[k2..'text01']:SetFontObject('GameFontDisableTiny')
						p[k2..'text02']:SetFontObject('GameFontDisableTiny')
					end
				end
			end
		end
		_G[p.genspec.text]:SetFontObject('GameFontDisableSmall')
		_G[p.genopeninv.text]:SetFontObject('GameFontDisableSmall')
		_G[p.genmsgs.text]:SetFontObject('GameFontDisableSmall')
		_G[p.gendisable.text]:SetFontObject('GameFontNormalLarge')
	else
		DCL:RegisterEvent('CVAR_UPDATE')
		DCL:RegisterEvent('DISABLE_DECLINE_GUILD_INVITE')
		DCL:RegisterEvent('ENABLE_DECLINE_GUILD_INVITE')
		for k,v in next,d.IN do if d.var.enable[v] then DCL:RegisterEvent(k) else DCL:UnregisterEvent(k) end end
		p.header01:SetFontObject('GameFontNormalLarge')
		for k1,v1 in next,d.def do
			if k1~='chan' and k1~='open' then
				if k1~='gen' then
					p[k1..'text']:SetFontObject((k1=='msg' and d.var.gen.msgs) and 'GameFontDisableTiny' or 'GameFontWhiteTiny')
				end
				for k2 in next,v1 do
					if ((k1~='enable' and d.var.enable[k2]==false) or (k1=='msg' and d.var.gen.msgs)) and (k1~=k2 or k2=='tell') then
					p[k1..k2]:Disable() else p[k1..k2]:Enable() end
					if k1=='enable' then
						p[k2..'text01']:SetFontObject(d.var[k1][k2] and 'GameFontWhiteTiny' or 'GameFontDisableTiny')
						p[k2..'text02']:SetFontObject(d.var[k1][k2] and 'GameFontWhiteTiny' or 'GameFontDisableTiny')
					end
				end
			end
		end
		_G[p.genspec.text]:SetFontObject('GameFontHighlightSmall')
		_G[p.genopeninv.text]:SetFontObject('GameFontHighlightSmall')
		_G[p.genmsgs.text]:SetFontObject('GameFontHighlightSmall')
		_G[p.gendisable.text]:SetFontObject('GameFontHighlightSmall')
	end
	if d.var.gen.disable or d.var.gen.openinv then
		d.OIenable=nil
		p.OIdrop:Hide()
		p.OIlist:Disable()
		p.OIinput:Disable()
		p.OIbutton1:Disable()
		p.OIbutton2:Disable()
		p.OIbutton2:UnlockHighlight()
		DCL:UnregisterEvent('CHAT_MSG_CHANNEL')
		DCL:UnregisterEvent('CHAT_MSG_EMOTE')
		DCL:UnregisterEvent('CHAT_MSG_SAY')
		DCL:UnregisterEvent('CHAT_MSG_YELL')
		DCL:UnregisterEvent('ZONE_CHANGED_NEW_AREA')
		p.OIlist:SetFontObject('GameFontDisableSmall')
		p.OIinput:SetFontObject('GameFontDisableSmall')
		p.OIbutton2:SetNormalFontObject('GameFontNormalSmall')
	else
		d.OIenable=d.OIcount and d.OIcount>0 or nil
		p.OIlist:Enable()
		p.OIinput:Enable()
		p.OIbutton1:Enable()
		p.OIbutton2:Enable()
		DCL:RegisterEvent('CHAT_MSG_CHANNEL')
		DCL:RegisterEvent('CHAT_MSG_EMOTE')
		DCL:RegisterEvent('CHAT_MSG_SAY')
		DCL:RegisterEvent('CHAT_MSG_YELL')
		DCL:RegisterEvent('ZONE_CHANGED_NEW_AREA')
		p.OIlist:SetFontObject('GameFontHighlightSmall')
		p.OIinput:SetFontObject('GameFontHighlightSmall')
	end
end

 -- Interface Options panel
 -- I would like to thank FlexYourHead of the addon Work_Complete for a ton of comments in their code
 -- It made understanding buttons, text, and the options frame a whole lot easier

function f.create(obj,arg1,arg2,arg3,arg4,arg5,arg6,arg7,n,supported)
	if obj=='button' then
		d.btn=d.btn and d.btn+1 or 1
		n=a..'Button'..format('%02i',d.btn)
		if arg7 then
			obj=CreateFrame('CheckButton',n,p.OIdrop,'UIRadioButtonTemplate')
			obj:SetPoint('TOPLEFT',p.OIdrop,'TOPLEFT',arg1,arg2)
		else
			obj=CreateFrame('CheckButton',n,DCLPanel,'OptionsCheckButtonTemplate')
			obj.tooltipText=arg3 arg7=arg6 and -2 or -8
			obj:SetCheckedTexture(d.file[arg4])
			obj:SetDisabledCheckedTexture(d.file[arg4])
			obj:GetCheckedTexture():SetVertexColor(0.8,0.8,0.8)
			obj:SetPoint('CENTER',DCLPanel,'TOPRIGHT',arg1,arg2)
			obj:GetDisabledCheckedTexture():SetVertexColor(0.4,0.4,0.4)
			supported=obj:GetDisabledCheckedTexture():SetDesaturated(true)
			if not supported then obj:GetDisabledCheckedTexture():SetAlpha(0.4) end
		end
		obj.GetValue=function()end obj.SetValue=function()end -- weird BfA error (why don't these templates have these methods anymore?)
		obj.text=n..'Text' _G[obj.text]:SetText(arg5) obj.width=_G[obj.text]:GetWidth()
		obj:SetHitRectInsets(arg7,arg6 and (-1*obj.width)-8 or arg7,arg7,arg7)
	else
		d.obj=d.obj and d.obj+1 or 1
		n=a..'Object'..format('%02i',d.obj)
		if obj=='line' then
			obj=DCLPanel:CreateTexture(n)
			obj:SetSize(600,1)
			obj:SetColorTexture(arg3,arg3,arg3)
			obj:SetPoint('LEFT',DCLPanel,'TOPLEFT',arg1,arg2)
		elseif obj=='text' then
			obj=DCLPanel:CreateFontString(n,'ARTWORK','GameFontNormal')
			obj:SetPoint(arg4,DCLPanel,arg5 and 'TOPLEFT' or 'TOPRIGHT',arg1,arg2)
			obj:SetText(arg3)
		end
	end
	return obj
end

function f.options(a)
	if a=='c' then d.var=ct(d.tmp) elseif a=='d' then d.var=ct(d.def) end
	if a=='r' then
		for k1,v in next,d.def do for k2 in next,v do
			if k1~='open' then p[k1..k2]:SetChecked(d.var[k1][k2]) end
		end end
		p.groupgroup.soundname=nil p.guildguild.soundname=nil
		f.setOIlist() f.blizzardoptions() if not d.tmp then d.tmp=ct(d.var) end
	elseif a~='d' then d.tmp=nil end
end

function f.randomsound(self,k,x)
	if self[k..'s'] then StopSound(self[k..'s']) end
	x=random(1,999999)
	self[k..'p'],self[k..'s']=PlaySound(x,'Master',false,nil,nil,nil,nil,true)
	if self[k..'p'] then
		self:SetCheckedTexture(d.file.ha)
		self.soundname=SOUNDKITNAME[x] or "???"
		self.soundid="  ID: "..x
		GameTooltip:SetText(self.soundname,nil,nil,nil,nil,false)
		GameTooltip:AddLine(self.soundid,nil,nil,nil,false)
		GameTooltip:Show()
	elseif self[k..'l']<999 then
		self[k..'l']=self[k..'l']+1
		f.randomsound(self,k)
	else
		self:SetCheckedTexture(d.file.sa)
		self.soundname=d.S.NOS
		self.soundid=nil
		GameTooltip:SetText(self.soundname,nil,nil,nil,nil,false)
	end
end

function f.setOIlist(text)
	sort(d.var.open)
	if d.var.open[1] then for _,v in next,d.var.open do
		text=text and text.."\n"..tostring(v) or tostring(v)
	end end
	p.OIlist:SetText(text or '')
end

function f.panel()
	DCLPanel.name=a
	InterfaceOptions_AddCategory(DCLPanel,a)
	p.header01=f.create('text',16,-16,a,'TOPLEFT',1)
	p.genspec=f.create('button',-265,-22,format(L.X_CHAR_SETTINGS,d.player.."-"..d.realm),'ch',d.S.CSS,1)
	p.line01=f.create('line',10,-40,.25)
	p.chantext01=f.create('text',-482,-64,d.S.CHA,'CENTER')
	p.chantext02=f.create('text',-482,-80,d.S.INV,'CENTER')
	p.dueltext01=f.create('text',-420,-64,d.S.DUE,'CENTER')
	p.dueltext02=f.create('text',-420,-80,d.S.REQ,'CENTER')
	p.pettext01=f.create('text',-358,-64,d.S.PET,'CENTER')
	p.pettext02=f.create('text',-358,-80,d.S.REQ,'CENTER')
	p.grouptext01=f.create('text',-296,-64,d.S.GRO,'CENTER')
	p.grouptext02=f.create('text',-296,-80,d.S.INV,'CENTER')
	p.guildtext01=f.create('text',-234,-64,d.S.GUI,'CENTER')
	p.guildtext02=f.create('text',-234,-80,d.S.INV,'CENTER')
	p.charttext01=f.create('text',-172,-64,d.S.GUI,'CENTER')
	p.charttext02=f.create('text',-172,-80,d.S.PTI,'CENTER')
	p.telltext01=f.create('text',-110,-64,d.S.PLA,'CENTER')
	p.telltext02=f.create('text',-110,-80,d.S.WHS,'CENTER')
	p.tradetext01=f.create('text',-48,-64,d.S.TRA,'CENTER')
	p.tradetext02=f.create('text',-48,-80,d.S.REQ,'CENTER')
	p.enabletext=f.create('text',-512,-112,d.S.ENA,'RIGHT')
	p.telltext=f.create('text',-512,-160,d.S.WHD,'RIGHT')
	p.grouptext=f.create('text',-512,-208,d.S.GRM,'RIGHT')
	p.guildtext=f.create('text',-512,-256,d.S.GUM,'RIGHT')
	p.friendtext=f.create('text',-512,-304,d.S.REF,'RIGHT')
	p.bnettext=f.create('text',-512,-352,d.S.BAT,'RIGHT')
	p.msgtext=f.create('text',-512,-400,d.S.CAL,'RIGHT')
	p.enablechan=f.create('button',-482,-112,g..L.ENABLE_CHAN.."|r",'ch')
	p.enableduel=f.create('button',-420,-112,g..L.ENABLE_DUEL.."|r",'ch')
	p.enablepet=f.create('button',-358,-112,g..L.ENABLE_PET.."|r",'ch')
	p.enablegroup=f.create('button',-296,-112,g..L.ENABLE_GROUP.."|r",'ch')
	p.enableguild=f.create('button',-234,-112,g..L.ENABLE_GUILD.."|r",'ch')
	p.enablechart=f.create('button',-172,-112,g..L.ENABLE_CHART.."|r",'ch')
	p.enabletell=f.create('button',-110,-112,g..L.ENABLE_TELL.."|r",'ch')
	p.enabletrade=f.create('button',-48,-112,g..L.ENABLE_TRADE.."|r",'ch')
	p.tellchan=f.create('button',-482,-160,r..L.TELL_CHAN.."|r",'cr')
	p.tellduel=f.create('button',-420,-160,r..L.TELL_DUEL.."|r",'cr')
	p.tellpet=f.create('button',-358,-160,r..L.TELL_PET.."|r",'cr')
	p.tellgroup=f.create('button',-296,-160,r..L.TELL_GROUP.."|r",'cr')
	p.tellguild=f.create('button',-234,-160,r..L.TELL_GUILD.."|r",'cr')
	p.tellchart=f.create('button',-172,-160,r..L.TELL_CHART.."|r",'cr')
	p.telltell=f.create('button',-110,-160,r..L.TELL_TELL.."|r",'cr')
	p.telltrade=f.create('button',-48,-160,r..L.TELL_TRADE.."|r",'cr')
	p.groupchan=f.create('button',-482,-208,r..L.GROUP_CHAN.."|r",'cr')
	p.groupduel=f.create('button',-420,-208,r..L.GROUP_DUEL.."|r",'cr')
	p.grouppet=f.create('button',-358,-208,r..L.GROUP_PET.."|r",'cr')
	p.groupgroup=f.create('button',-296,-208,r..L.GROUP_GROUP.."|r",'cr')
	p.groupguild=f.create('button',-234,-208,r..L.GROUP_GUILD.."|r",'cr')
	p.groupchart=f.create('button',-172,-208,r..L.GROUP_CHART.."|r",'cr')
	p.grouptell=f.create('button',-110,-208,r..L.GROUP_TELL.."|r",'cr')
	p.grouptrade=f.create('button',-48,-208,r..L.GROUP_TRADE.."|r",'cr')
	p.guildchan=f.create('button',-482,-256,r..L.GUILD_CHAN.."|r",'cr')
	p.guildduel=f.create('button',-420,-256,r..L.GUILD_DUEL.."|r",'cr')
	p.guildpet=f.create('button',-358,-256,r..L.GUILD_PET.."|r",'cr')
	p.guildgroup=f.create('button',-296,-256,r..L.GUILD_GROUP.."|r",'cr')
	p.guildguild=f.create('button',-234,-256,r..L.GUILD_GUILD.."|r",'cr')
	p.guildchart=f.create('button',-172,-256,r..L.GUILD_CHART.."|r",'cr')
	p.guildtell=f.create('button',-110,-256,r..L.GUILD_TELL.."|r",'cr')
	p.guildtrade=f.create('button',-48,-256,r..L.GUILD_TRADE.."|r",'cr')
	p.friendchan=f.create('button',-482,-304,r..L.FRIEND_CHAN.."|r",'cr')
	p.friendduel=f.create('button',-420,-304,r..L.FRIEND_DUEL.."|r",'cr')
	p.friendpet=f.create('button',-358,-304,r..L.FRIEND_PET.."|r",'cr')
	p.friendgroup=f.create('button',-296,-304,r..L.FRIEND_GROUP.."|r",'cr')
	p.friendguild=f.create('button',-234,-304,r..L.FRIEND_GUILD.."|r",'cr')
	p.friendchart=f.create('button',-172,-304,r..L.FRIEND_CHART.."|r",'cr')
	p.friendtell=f.create('button',-110,-304,r..L.FRIEND_TELL.."|r",'cr')
	p.friendtrade=f.create('button',-48,-304,r..L.FRIEND_TRADE.."|r",'cr')
	p.bnetchan=f.create('button',-482,-352,r..L.BNET_CHAN.."|r",'cr')
	p.bnetduel=f.create('button',-420,-352,r..L.BNET_DUEL.."|r",'cr')
	p.bnetpet=f.create('button',-358,-352,r..L.BNET_PET.."|r",'cr')
	p.bnetgroup=f.create('button',-296,-352,r..L.BNET_GROUP.."|r",'cr')
	p.bnetguild=f.create('button',-234,-352,r..L.BNET_GUILD.."|r",'cr')
	p.bnetchart=f.create('button',-172,-352,r..L.BNET_CHART.."|r",'cr')
	p.bnettell=f.create('button',-110,-352,r..L.BNET_TELL.."|r",'cr')
	p.bnettrade=f.create('button',-48,-352,r..L.BNET_TRADE.."|r",'cr')
	p.msgchan=f.create('button',-482,-400,r..L.MSG_CHAN.."|r",'cr')
	p.msgduel=f.create('button',-420,-400,r..L.MSG_DUEL.."|r",'cr')
	p.msgpet=f.create('button',-358,-400,r..L.MSG_PET.."|r",'cr')
	p.msggroup=f.create('button',-296,-400,r..L.MSG_GROUP.."|r",'cr')
	p.msgguild=f.create('button',-234,-400,r..L.MSG_GUILD.."|r",'cr')
	p.msgchart=f.create('button',-172,-400,r..L.MSG_CHART.."|r",'cr')
	p.msgtell=f.create('button',-110,-400,r..L.MSG_TELL.."|r",'cr')
	p.msgtrade=f.create('button',-48,-400,r..L.MSG_TRADE.."|r",'cr')
	p.line02=f.create('line',10,-428,.25)
	p.genopeninv=f.create('button',-265,-464,r..L.X_DISABLE_OPENINV.."|r",'cr',d.S.DIO..d.S.INV,1)
	p.genmsgs=f.create('button',-265,-496,r..L.X_DISABLE_MESSAGES.."|r",'cr',d.S.DIS..d.S.CAL,1)
	p.gendisable=f.create('button',-265,-528,r..L.X_DISABLE_DECLINER.."|r",'cr',d.S.DIS..a,1)

	for k1,v1 in next,d.def do for k2 in next,v1 do
		if k1==k2 and k2~='tell' then
			p[k1..k2]:SetScript('OnEnter',function(self)
				GameTooltip:SetOwner(self,self.tooltipOwnerPoint or 'ANCHOR_RIGHT')
				if self.soundname then
					GameTooltip:SetText(self.soundname,nil,nil,nil,nil,false)
					if self.soundid then
						GameTooltip:AddLine(self.soundid,nil,nil,nil,false)
						GameTooltip:Show()
					end
				else
					GameTooltip:SetText(self.tooltipText or '',nil,nil,nil,nil,true)
				end
			end)
			p[k1..k2]:SetScript('PostClick',function(self)
				self:SetChecked(true) d.var[k1][k2]=false
				self[k1..'l']=0 f.randomsound(self,k1)
			end)
		elseif k1~='chan' and k1~='open' then
			p[k1..k2]:SetScript('PostClick',function(self)
				d.var[k1][k2]=self:GetChecked()
				f.register() f.blizzardoptions()
			end)
		end
	end end

	-- the following inputbox, button, and scrolling list inspired by funkydude's BadBoy_CCleaner chat filter options

	p.OIinput=CreateFrame('EditBox',a..'OpenInvInput',DCLPanel,'InputBoxTemplate')
	p.OIinput:SetPoint('TOPRIGHT',-325,-464)
	p.OIinput:SetAutoFocus(false)
	p.OIinput:EnableMouse(true)
	p.OIinput:SetSize(112,20)
	p.OIinput:SetScript('OnEnterPressed',function() p.OIbutton1:Click() end)
	p.OIinput:SetScript('OnEscapePressed',function(frame) frame:ClearFocus() end)
	p.OIinput:SetScript('OnEnter',function(self)
		if d.var.gen.disable or d.var.gen.openinv then
			GameTooltip:Hide()
		else
			GameTooltip:SetOwner(self,self.tooltipOwnerPoint or 'ANCHOR_RIGHT')
			GameTooltip:SetText(L.X_OPENINV_INPUT,nil,nil,nil,nil,true)
		end
	end)
	p.OIinput:SetScript('OnLeave',function()
		GameTooltip:Hide()
	end)

	p.OIbutton1=CreateFrame('Button',a..'OpenInvButton',DCLPanel,'UIPanelButtonTemplate')
	p.OIbutton1:SetPoint('TOPRIGHT',p.OIinput,'BOTTOMRIGHT',1,0)
	p.OIbutton1:SetPoint('TOPLEFT',p.OIinput,'BOTTOMLEFT',-6,0)
	p.OIbutton1:SetNormalFontObject('GameFontNormalSmall')
	p.OIbutton1:SetHighlightFontObject('GameFontHighlightSmall')
	p.OIbutton1:SetDisabledFontObject('GameFontDisableSmall')
	p.OIbutton1:SetText(d.S.ADD)
	p.OIbutton1:SetScript('OnClick',function(text,found)
		p.OIinput:ClearFocus() text=p.OIinput:GetText() found=nil
		if text:find('^%s*$') then p.OIinput:SetText('') return end
		for k,v in next,d.var.open do if text==v then found=k end end
		if found then remove(d.var.open,found) else insert(d.var.open,text) end
		f.setOIlist() p.OIinput:SetText('')
	end)
	p.OIbutton1:SetScript('OnEnter',function(self)
		if d.var.gen.disable or d.var.gen.openinv then
			GameTooltip:Hide()
		else
			GameTooltip:SetOwner(self,self.tooltipOwnerPoint or 'ANCHOR_RIGHT',-1)
			GameTooltip:SetText(L.X_OPENINV_BUTTON,nil,nil,nil,nil,true)
		end
	end)
	p.OIbutton1:SetScript('OnLeave',function()
		GameTooltip:Hide()
	end)

	p.OIbutton2=CreateFrame('Button',a..'OpenInvButton2',DCLPanel,'UIPanelButtonTemplate')
	p.OIbutton2:SetPoint('TOPRIGHT',p.OIbutton1,'BOTTOMRIGHT')
	p.OIbutton2:SetPoint('TOPLEFT',p.OIbutton1,'BOTTOMLEFT')
	p.OIbutton2:SetNormalFontObject('GameFontNormalSmall')
	p.OIbutton2:SetHighlightFontObject('GameFontHighlightSmall')
	p.OIbutton2:SetDisabledFontObject('GameFontDisableSmall')
	p.OIbutton2:SetText(d.S.CHS)
	p.OIbutton2:SetScript('OnClick',function()
		if p.OIdrop:IsVisible() then
			p.OIbutton2:UnlockHighlight() p.OIdrop:Hide()
			p.OIbutton2:SetNormalFontObject('GameFontNormalSmall')
		else
			p.OIbutton2:LockHighlight() p.OIdrop:Show()
			p.OIdrop:EnableMouse(true) p.OIdrop:SetFrameStrata('DIALOG')
			p.OIbutton2:SetNormalFontObject('GameFontHighlightSmall')
		end
	end)
	p.OIbutton2:SetScript('OnEnter',function(self)
		if d.var.gen.disable or d.var.gen.openinv then
			GameTooltip:Hide()
		else
			GameTooltip:SetOwner(self,self.tooltipOwnerPoint or 'ANCHOR_RIGHT',-1)
			GameTooltip:SetText(L.X_OPENINV_MENU,nil,nil,nil,nil,true)
		end
	end)
	p.OIbutton2:SetScript('OnLeave',function()
		GameTooltip:Hide()
	end)

	p.OIdrop=CreateFrame('Frame',a..'OpenInvDropDown',DCLPanel)
	p.OIdrop:SetBackdrop({
		bgFile='Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',
		insets={left=2,right=2,top=2,bottom=2},
		tile=true,tileSize=8,edgeSize=8,})
	p.OIdrop:SetBackdropColor(0,0,0,1)
	p.OIdrop:SetBackdropBorderColor(.25,.25,.25)
	p.OIdrop:SetPoint('LEFT',p.OIbutton1,'RIGHT')
	p.chanemote=f.create('button',4,-4,nil,nil,d.S.EMO,1,1)
	p.chansay=f.create('button',4,-20,nil,nil,d.S.SAY,1,1)
	p.chanyell=f.create('button',4,-36,nil,nil,d.S.YEL,1,1)
	p.chan1=f.create('button',4,-52,nil,nil,d.S.GEN,1,1)
	p.chan2=f.create('button',4,-68,nil,nil,d.S.TRA,1,1)
	p.chan26=f.create('button',4,-84,nil,nil,d.S.LOO,1,1)
	for k in next,d.def.chan do
		d.mcw=d.mcw and max(d.mcw,p['chan'..k].width) or p['chan'..k].width
		p['chan'..k]:SetScript('PostClick',function(self) d.var.chan[k]=self:GetChecked() end)
	end
	p.OIdrop:SetSize(d.mcw+40,104) p.OIdrop:Hide()

	p.OIback=CreateFrame('Frame',a..'OpenInvBackdrop',DCLPanel)
	p.OIback:SetPoint('TOPRIGHT',p.OIinput,'TOPLEFT',-24,0)
	p.OIback:SetPoint('BOTTOMLEFT',p.OIbutton2,'BOTTOMLEFT',-119,0)
	p.OIback:SetBackdrop({
		bgFile='Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',
		insets={left=2,right=2,top=2,bottom=2},
		tile=true,tileSize=8,edgeSize=8,})
	p.OIback:SetBackdropColor(0,0,0,.75)
	p.OIback:SetBackdropBorderColor(.25,.25,.25)
	p.OIback:SetScript('OnEnter',function(self)
		if d.var.gen.disable or d.var.gen.openinv then
			GameTooltip:Hide()
		else
			GameTooltip:SetOwner(self,self.tooltipOwnerPoint or 'ANCHOR_RIGHT')
			GameTooltip:SetText(L.X_OPENINV_LIST,nil,nil,nil,nil,true)
		end
	end)
	p.OIback:SetScript('OnLeave',function()
		GameTooltip:Hide()
	end)

	p.OIscroll=CreateFrame('ScrollFrame',a..'OpenInvScroll',DCLPanel,'UIPanelScrollFrameTemplate')
	p.OIscroll:SetPoint('LEFT',p.OIback,'LEFT',4.5,0)
	p.OIscroll:SetPoint('RIGHT',p.OIback,'RIGHT',-4.5,0)
	p.OIscroll:SetPoint('TOP',p.OIback,'TOP',0,-4)
	p.OIscroll:SetPoint('BOTTOM',p.OIback,'BOTTOM',0,4)

	p.OIlist=CreateFrame('EditBox',a..'OpenInvList',DCLPanel)
	p.OIlist:SetAutoFocus(false)
	p.OIlist:EnableMouse(false)
	p.OIlist:SetMultiLine(true)
	p.OIlist:SetMaxLetters(0)
	p.OIlist:SetWidth(120)
	p.OIlist:Show()

	p.OIscroll:SetScrollChild(p.OIlist)

	DCLPanel.okay=function() f.options() d.cancel=nil end
 --	DCLPanel.cancel=function() f.options('c') f.register() end -- stupid taints
	DCLPanel.default=function() f.options('d') f.register() end
	DCLPanel.refresh=function() f.options('r') d.cancel=true end
	SLASH_DECLINER1='/decliner'
	SLASH_DECLINER2='/decline'
	SLASH_DECLINER3='/dcl'
	SlashCmdList.DECLINER=function() InterfaceOptionsFrame_OpenToCategory(a) end
end
