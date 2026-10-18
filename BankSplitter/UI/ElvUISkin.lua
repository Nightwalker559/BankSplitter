-- ============================================================
-- BankSplitter - ElvUI skin
-- Skins the window, buttons, dropdowns, tabs and the list in the ElvUI style.
-- Without ElvUI nothing is skinned (ApplyElvUISkin returns right away).
-- ============================================================

local _, ns = ...

local UI = ns.UI

-- ElvUI's S:HandleTab pulls the visible backdrop inwards by a fixed inset instead of
-- anchoring it to the frame edges, so the tab strip needs negative spacing to leave
-- ~1 px between the tabs and has to move left a bit. Same values as ElvUI's own
-- TabSystem skins (Player Spells, Friends).
local TAB_SPACING = -5
local TAB_START_X = -3

-- Called from Core/Init.lua when the player enters the world
ns.ApplyElvUISkin = function()
    if not ElvUI then return end
    local E = unpack(ElvUI)
    if not E then return end
    local S = E:GetModule("Skins")
    if not S then return end

    local ok, err = pcall(function()
        -- Window
        UI.frame:StripTextures()
        UI.frame:SetTemplate("Default", true)

        -- ElvUI border color + brightened version for hover
        -- (ElvUI color tables are RGBA; the numeric indices are only legacy)
        local bc  = (E.media and E.media.bordercolor) or { r = 0.4, g = 0.4, b = 0.4 }
        local r, g, b = bc.r or 0.4, bc.g or 0.4, bc.b or 0.4
        local hr = math.min(r + 0.3, 1)
        local hg = math.min(g + 0.3, 1)
        local hb = math.min(b + 0.3, 1)

        -- Item slot border in ElvUI style
        UI.itemSlotBorderFrame:SetTemplate("Default", true)
        local fade = E.media.backdropfadecolor
        UI.itemSlotBorderFrame:SetBackdropColor(fade.r, fade.g, fade.b, fade.a or 0.9)
        UI.itemSlotBorderFrame:SetBackdropBorderColor(r, g, b, 1)

        -- Helper: skin button + border + hover effect
        local function SkinBtn(btn)
            S:HandleButton(btn)
            btn:SetBackdropBorderColor(r, g, b, 1)
            local origEnter = btn:GetScript("OnEnter")
            local origLeave = btn:GetScript("OnLeave")
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(hr, hg, hb, 1)
                if origEnter then origEnter(self) end
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(r, g, b, 1)
                if origLeave then origLeave(self) end
            end)
        end

        -- Action button, Options link in the title bar and +/- buttons
        SkinBtn(UI.actionBtn)
        SkinBtn(UI.configBtn)
        SkinBtn(UI.countMinusBtn)
        SkinBtn(UI.countPlusBtn)
        SkinBtn(UI.stackMinusBtn)
        SkinBtn(UI.stackPlusBtn)

        -- Bank / source dropdowns
        S:HandleDropDownBox(UI.modeDropdown, 144)
        S:HandleDropDownBox(UI.sourceDropdown, 144)

        -- Tabs below the window (Blizzard's TabSystem)
        local tabSystem = UI.frame.TabSystem
        if tabSystem then
            for _, tab in next, { tabSystem:GetChildren() } do S:HandleTab(tab) end
            tabSystem.spacing = TAB_SPACING
            tabSystem:MarkDirty()
            tabSystem:ClearAllPoints()
            tabSystem:SetPoint("TOPLEFT", UI.frame, "BOTTOMLEFT", TAB_START_X, 0)
        end

        -- EditBoxes
        S:HandleEditBox(UI.countEdit)
        S:HandleEditBox(UI.stackEdit)

        -- Close button
        if UI.frame.CloseButton then
            S:HandleCloseButton(UI.frame.CloseButton)
        end

        -- Transfer list: ScrollFrameTemplate has Blizzard's modern scroll bar (Back/Forward/Track)
        local scrollBar = UI.transferScroll and UI.transferScroll.ScrollBar
        if scrollBar then
            if scrollBar.Track and S.HandleTrimScrollBar then
                S:HandleTrimScrollBar(scrollBar)
            else
                S:HandleScrollBar(scrollBar)
            end
        end
        -- (the tab chips and the drop target are flat 1 px bordered buttons already)

        -- Rows are created lazily, so they are skinned as they appear
        UI.SkinRow = function(row) S:HandleButton(row.remove) end
        for _, row in ipairs(UI.transferRows) do UI.SkinRow(row) end
    end)

    if not ok then
        print("|cff00ccff[BankSplitter]|r |cffff8800ElvUI skin error: " .. tostring(err) .. "|r")
    end
end
