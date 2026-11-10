local function Report(message)
    local text = "|cffffcc33Catchy:|r " .. message
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

CATCHY_LOAD_STAGE = "bootstrap"

if geterrorhandler and seterrorhandler then
    local previousErrorHandler = geterrorhandler()
    seterrorhandler(function(message)
        local trace = debugstack and debugstack(2, 20, 20) or ""
        CATCHY_LAST_ERROR = tostring(message) .. (trace ~= "" and ("\n" .. trace) or "")
        if previousErrorHandler then
            previousErrorHandler(message)
        end
    end)
end

local function RunDiagnostic()
        local main = _G.CatchyFrame
        local options = _G.FishingOptionsFrame
        local mainChildren = main and main.GetNumChildren and main:GetNumChildren() or 0
        local optionChildren = options and options.GetNumChildren and options:GetNumChildren() or 0
        local selected = main and main.GetSelected and main:GetSelected() or "none"
        Report(string.format(
            "diag main=%s children=%d options=%s optionChildren=%d selected=%s",
            tostring(main ~= nil),
            mainChildren,
            tostring(options ~= nil),
            optionChildren,
            tostring(selected)
        ))
        if CATCHY_LAST_ERROR then
            Report("last error: " .. CATCHY_LAST_ERROR)
        else
            Report("last error: none captured")
        end
end

SLASH_CATCHYDIAG1 = "/cadiag"
SlashCmdList.CATCHYDIAG = RunDiagnostic

SLASH_CATCHY1 = "/catchy"
SLASH_CATCHY2 = "/ca"
SlashCmdList.CATCHY = function(message)

    if FBEnvironment and type(FBEnvironment.Command) == "function" then
        return FBEnvironment.Command(message)
    end

    local library = CATCHY_LIB_STAGE and ("; LibFishing: " .. tostring(CATCHY_LIB_STAGE)) or ""
    local detail = CATCHY_LOAD_ERROR and (" (" .. tostring(CATCHY_LOAD_ERROR) .. ")") or ""
    Report("core initialization stopped at: " .. tostring(CATCHY_LOAD_STAGE) .. library .. detail)
end
