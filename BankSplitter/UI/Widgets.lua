-- ============================================================
-- BankSplitter - UI widgets
-- Layout constants and the small widget helpers the window is built from.
-- ============================================================

local _, ns = ...

local W  = 360
local H  = 372
local INSET_BOTTOM = 50   -- footer bar (status + action button) below the content inset
local PL = 12
local PR = -12
local PAGE_TOP = -120     -- where the tab pages start (below title, selectors and tab chips)
local WHITE = "Interface\\Buttons\\WHITE8x8"


--- Window in the current Blizzard panel style: DefaultPanelTemplate (nine-slice
--- metal border, rock background, title) with an inset content area, like the
--- bank and other Midnight windows. The inset frame only contributes its
--- border; the marble is a texture of the panel itself, because a child frame
--- would be drawn over the panel's labels and dividers.
local function CreatePanel(name, parent, title)
    local panel = CreateFrame("Frame", name, parent, "DefaultPanelTemplate, TabSystemOwnerTemplate")
    panel:SetTitle(title)
    panel.CloseButton = CreateFrame("Button", nil, panel, "UIPanelCloseButtonDefaultAnchors")

    local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
    inset:SetPoint("TOPLEFT",     panel, "TOPLEFT",      6, -24)
    inset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, INSET_BOTTOM)
    inset.Bg:Hide()
    panel.Inset = inset

    local marble = panel:CreateTexture(nil, "BACKGROUND", nil, -4)
    marble:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
    marble:SetHorizTile(true)
    marble:SetVertTile(true)
    marble:SetAllPoints(inset)
    return panel
end

--- Makes a window draggable and stores where it was dropped (BankSplitterDB.pos[key]).
local function MakeMovable(f, key)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        BankSplitterDB = BankSplitterDB or {}
        BankSplitterDB.pos = BankSplitterDB.pos or {}
        BankSplitterDB.pos[key] = { point, relPoint, x, y }
    end)
end

local function FS(parent, font, x, y, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text or "")
    return fs
end

--- Red panel button anchored top-left inside parent.
local function BTN(parent, x, y, w, h, label)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 80, h or 22)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label or "")
    return b
end

local function DIV(parent, y)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    tex:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PL, y)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", PR, y)
    tex:SetHeight(16)
end

--- Flat bordered button (tab chips, drop target): dark fill, 1 px border.
--- b:SetSelected(true) turns the border and text gold.
local function CreateFlatButton(parent, w, h, label)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b:SetBackdropColor(0.09, 0.09, 0.11, 0.9)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(label or "")
    local function Paint(self, hover)
        if self.selected then
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            self.text:SetTextColor(1, 0.82, 0)
        else
            local g = hover and 0.75 or 0.32
            self:SetBackdropBorderColor(g, g, g + 0.03, 1)
            self.text:SetTextColor(0.75, 0.75, 0.78)
        end
    end
    b.SetSelected = function(self, selected) self.selected = selected and true or false; Paint(self, false) end
    b:SetScript("OnEnter", function(self) Paint(self, true) end)
    b:SetScript("OnLeave", function(self) Paint(self, false) end)
    Paint(b, false)
    return b
end

-- Exports
ns.BTN = BTN
ns.CreateFlatButton = CreateFlatButton
ns.CreatePanel = CreatePanel
ns.DIV = DIV
ns.FS = FS
ns.H = H
ns.INSET_BOTTOM = INSET_BOTTOM
ns.MakeMovable = MakeMovable
ns.PAGE_TOP = PAGE_TOP
ns.PL = PL
ns.PR = PR
ns.W = W
ns.WHITE = WHITE
