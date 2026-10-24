--============================================================
--// THEMES
--============================================================
local Themes = {
    Dark = {
        Background   = Color3.fromRGB(30, 30, 36), Sidebar = Color3.fromRGB(35, 35, 43),
        Panel = Color3.fromRGB(43, 43, 54), PanelRaised = Color3.fromRGB(49, 49, 61),
        Hover = Color3.fromRGB(58, 58, 70), Selected = Color3.fromRGB(53, 53, 66),
        Accent = Color3.fromRGB(78, 111, 255), AccentHover = Color3.fromRGB(102, 130, 255),
        AccentSoft = Color3.fromRGB(43, 53, 91), PrimaryText = Color3.fromRGB(245, 245, 250),
        MutedText = Color3.fromRGB(164, 164, 179), QuietText = Color3.fromRGB(124, 124, 142),
        Border = Color3.fromRGB(67, 67, 81), Danger = Color3.fromRGB(235, 83, 91),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(38, 38, 46),
        SegmentedBg = Color3.fromRGB(29, 29, 36),
    },
    White = {
        Background   = Color3.fromRGB(248, 248, 250), Sidebar = Color3.fromRGB(240, 240, 244),
        Panel = Color3.fromRGB(254, 254, 255), PanelRaised = Color3.fromRGB(250, 250, 253),
        Hover = Color3.fromRGB(230, 230, 236), Selected = Color3.fromRGB(226, 230, 245),
        Accent = Color3.fromRGB(78, 111, 255), AccentHover = Color3.fromRGB(102, 130, 255),
        AccentSoft = Color3.fromRGB(224, 232, 255), PrimaryText = Color3.fromRGB(25, 25, 35),
        MutedText = Color3.fromRGB(90, 90, 105), QuietText = Color3.fromRGB(140, 140, 155),
        Border = Color3.fromRGB(210, 210, 218), Danger = Color3.fromRGB(220, 60, 70),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(252, 252, 254),
        SegmentedBg = Color3.fromRGB(232, 232, 238),
    },
    Blue = {
        Background   = Color3.fromRGB(24, 40, 78), Sidebar = Color3.fromRGB(30, 48, 92),
        Panel = Color3.fromRGB(38, 58, 108), PanelRaised = Color3.fromRGB(44, 66, 120),
        Hover = Color3.fromRGB(52, 76, 135), Selected = Color3.fromRGB(58, 84, 148),
        Accent = Color3.fromRGB(120, 168, 255), AccentHover = Color3.fromRGB(150, 190, 255),
        AccentSoft = Color3.fromRGB(50, 82, 150), PrimaryText = Color3.fromRGB(235, 242, 255),
        MutedText = Color3.fromRGB(160, 180, 220), QuietText = Color3.fromRGB(120, 145, 195),
        Border = Color3.fromRGB(60, 88, 155), Danger = Color3.fromRGB(240, 100, 110),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(28, 46, 86),
        SegmentedBg = Color3.fromRGB(20, 34, 68),
    },
    MidnightBlue = {
        Background   = Color3.fromRGB(12, 16, 32), Sidebar = Color3.fromRGB(16, 22, 44),
        Panel = Color3.fromRGB(20, 28, 54), PanelRaised = Color3.fromRGB(26, 34, 64),
        Hover = Color3.fromRGB(34, 44, 80), Selected = Color3.fromRGB(40, 52, 92),
        Accent = Color3.fromRGB(90, 130, 255), AccentHover = Color3.fromRGB(120, 158, 255),
        AccentSoft = Color3.fromRGB(32, 46, 92), PrimaryText = Color3.fromRGB(228, 235, 250),
        MutedText = Color3.fromRGB(140, 155, 185), QuietText = Color3.fromRGB(100, 115, 150),
        Border = Color3.fromRGB(40, 52, 88), Danger = Color3.fromRGB(235, 83, 91),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(14, 20, 40),
        SegmentedBg = Color3.fromRGB(10, 14, 28),
    },
}

local themeOrder = { "Dark", "White", "Blue", "MidnightBlue" }
local themeDisplayNames = { Dark = "Dark", White = "White", Blue = "Blue", MidnightBlue = "Midnight" }
