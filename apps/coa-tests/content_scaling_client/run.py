from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[3]


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(r'''
        seed = {
            [-1] = {"Classic", 1, 1, 60, 60, 1, 60, 0, 0},
            [-2] = {"TBC", 1, 58, 70, 70, 58, 70, 1, 0},
            [-3] = {"WotLK", 1, 68, 80, 80, 68, 80, 2, 0},
            [12] = {"Classic dungeon", 1, 15, 60, 60, 15, 60, 0, -1},
            [13] = {"TBC dungeon", 1, 58, 70, 70, 58, 70, 1, -2},
            [14] = {"WotLK dungeon", 1, 70, 80, 80, 70, 80, 2, -3},
            [15] = {"Heroic", 5, 80, 80, 80, 80, 80, 2, -3},
            [16] = {"Random WotLK", 6, 80, 80, 80, 80, 80, 2, 0}
        }
        function GetLFGDungeonInfo(id) if seed[id] then return unpack(seed[id]) end end
        nativeOrder = {-1,12}
        function GetLFDChoiceInfo() return seed end
        function GetLFDChoiceOrder() return nativeOrder end
        function GetNumRandomDungeons() return 0 end
        function GetLFGRandomDungeonInfo() end
        function IsLFGDungeonJoinable() return false end
        function UnitName() return "Tester" end
        function UnitLevel() return 55 end
        function SendAddonMessage(prefix, msg, channel, recipient)
            assert(prefix=="COASCALE" and channel=="WHISPER" and recipient=="Tester")
            lastMessage = msg
            requested = true
        end
        EXPANSION_LEVEL=2
        LFGLockList = {[15]=34}
        function LFDList_DefaultFilterFunction() return false end
        LFD_CURRENT_FILTER=LFDList_DefaultFilterFunction
        function LFGDungeonList_Setup()
            LFGDungeonInfo=GetLFDChoiceInfo()
            LFDDungeonList=GetLFDChoiceOrder()
        end
        buttons = {}
        LFDQueueFrameFindGroupButton = {GetParent=function() return {} end, IsEnabled=function() return true end, Click=function() clicked=(clicked or 0)+1 end}
        function CreateFrame(kind)
            local frame={}
            if kind=="Button" then buttons[#buttons+1]=frame end
            function frame:SetSize() end
            function frame:SetPoint() end
            function frame:SetText(text) self.text=text end
            function frame:Show() self.shown=true end
            function frame:Hide() self.shown=false end
            function frame:Enable() self.enabled=true end
            function frame:Disable() self.enabled=false end
            function frame:RegisterEvent() end
            function frame:SetScript(event, callback) if event=="OnEvent" then handler=callback else self.click=callback end end
            return frame
        end
        function message(body, sender) handler(nil,"CHAT_MSG_ADDON","COASCALE",body,"WHISPER",sender or "Tester") end
    ''')
    source = ROOT / 'modules/mod-coa-content-scaling/addon/CoAContentScaling.lua'
    lua.execute(source.read_text(encoding='utf-8-sig'))
    lua.execute(r'''
        handler(nil,"PLAYER_ENTERING_WORLD")
        assert(requested)
        message("BEGIN:60", "OtherPlayer")
        message("D:14:1:60:1", "OtherPlayer")
        message("END", "OtherPlayer")
        assert(select(3,GetLFGDungeonInfo(14))==70)
        message("BEGIN:60")
        message("D:12:12:60:1")
        message("D:13:45:60:1")
        message("D:14:55:60:1")
        message("D:15:60:60:5")
        message("D:16:55:60:6")
        message("END")
        assert(#buttons==2 and buttons[1].shown and buttons[2].shown)
        buttons[1].click()
        assert(lastMessage=="MODE:BOTS" and clicked==1)
        buttons[2].click()
        assert(lastMessage=="MODE:SOLO" and clicked==2)
        assert(select(3,GetLFGDungeonInfo(14))==55)
        assert(select(4,GetLFGDungeonInfo(14))==60)
        assert(LFGDungeonInfo[13][3]==45 and LFGDungeonInfo[13][4]==60)
        local seen={}
        for _,id in ipairs(LFDDungeonList) do seen[id]=true end
        assert(seen[12] and seen[13] and seen[14] and seen[15])
        assert(LFD_CURRENT_FILTER(12) and LFD_CURRENT_FILTER(13) and LFD_CURRENT_FILTER(14))
        assert(IsLFGDungeonJoinable(14))
        assert(not IsLFGDungeonJoinable(15))
        LFGLockList[14]=1024
        assert(not IsLFGDungeonJoinable(14))
        assert(GetNumRandomDungeons()==1)
        assert(GetLFGRandomDungeonInfo(1)==16)
        message("OFF")
        assert(select(3,GetLFGDungeonInfo(14))==70)
        assert(not buttons[1].shown and not buttons[2].shown)
        assert(GetNumRandomDungeons()==0)
        assert(#nativeOrder==2 and #LFDDungeonList==2)
        assert(seed[14][3]==70)
        assert(LFGDungeonInfo[14][3]==70)
    ''')
    print('PASS: Lua 5.1 scaling profiles, all expansion lists, level gates, server locks, sender validation and stock reset')


if __name__ == '__main__':
    main()
