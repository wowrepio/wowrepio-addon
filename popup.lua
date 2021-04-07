local _, ns = ...

local popup = ns:AddModule("popup")
local payload = ns:GetModule("payload")
local channel = ns:GetModule("channel")

local POPUP_NAME = "WOWREPIO_WANNA_REVIEW_POPUP"

StaticPopupDialogs[POPUP_NAME] = {
   text = "Would you like to review your group?",
   button1 = "Yes",
   button2 = "No",
   OnAccept = function()
      payload:Show()
   end,
   whileDead = true,
   hideOnEscape = true,
}

local function showDialog()
     StaticPopup_Show(POPUP_NAME)
end     

function popup:OnReady()
    channel:RegisterEvent("CHALLENGE_MODE_COMPLETED", showDialog)
end