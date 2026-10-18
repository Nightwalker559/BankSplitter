-- ============================================================
-- BankSplitter - ElvUI Skin
-- WoW Midnight 12.1.5
--
-- This file is optional. It is only loaded when ElvUI is active
-- and skins all frames and buttons in the ElvUI style.
-- Without ElvUI, this file has no effect.
-- ============================================================

local _, ns = ...

-- Called from Core/Init.lua when the player enters the world
ns.ApplyElvUISkin = function()
    if not ElvUI then return end
    local E = unpack(ElvUI)
    if not E then return end
    local S = E:GetModule("Skins")
    if not S then return end

    -- Get UI elements from the main file
    local UI = ns.UI
    if not UI then
        print("|cff00ccff[BankSplitter]|r |cffff8800ElvUI skin: ns.UI not found.|r")
        return
    end

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
            local orig_enter = btn:GetScript("OnEnter")
            local orig_leave = btn:GetScript("OnLeave")
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(hr, hg, hb, 1)
                if orig_enter then orig_enter(self) end
            end)
            btn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(r, g, b, 1)
                if orig_leave then orig_leave(self) end
            end)
        end

        -- Action button and +/- buttons
        SkinBtn(UI.actionBtn)
        SkinBtn(UI.countMinusBtn)
        SkinBtn(UI.countPlusBtn)
        SkinBtn(UI.stackMinusBtn)
        SkinBtn(UI.stackPlusBtn)

        -- Bank / source dropdowns
        S:HandleDropDownBox(UI.modeDropdown, 144)
        S:HandleDropDownBox(UI.sourceDropdown, 144)

        -- Tabs below the window (Blizzard's TabSystem)
        if UI.frame.TabSystem then
            for _, tab in next, { UI.frame.TabSystem:GetChildren() } do S:HandleTab(tab) end
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
