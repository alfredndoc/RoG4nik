--============================================================
--// THEMES
--============================================================
local Themes = {
    Dark = {
        Background = Color3.fromRGB(17, 18, 21), Sidebar = Color3.fromRGB(20, 21, 25),
        Panel = Color3.fromRGB(27, 28, 33), PanelRaised = Color3.fromRGB(32, 33, 39),
        Hover = Color3.fromRGB(42, 44, 51), Selected = Color3.fromRGB(35, 42, 52),
        Accent = Color3.fromRGB(47, 112, 171), AccentHover = Color3.fromRGB(41, 119, 166),
        AccentSoft = Color3.fromRGB(29, 47, 61), PrimaryText = Color3.fromRGB(244, 245, 247),
        MutedText = Color3.fromRGB(163, 166, 174), QuietText = Color3.fromRGB(119, 123, 132),
        Border = Color3.fromRGB(55, 57, 64), Danger = Color3.fromRGB(236, 92, 101),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(19, 20, 24),
        SegmentedBg = Color3.fromRGB(23, 24, 28),
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
    Red = {
        Background = Color3.fromRGB(28, 18, 22), Sidebar = Color3.fromRGB(38, 22, 28),
        Panel = Color3.fromRGB(49, 27, 34), PanelRaised = Color3.fromRGB(59, 31, 40),
        Hover = Color3.fromRGB(74, 37, 47), Selected = Color3.fromRGB(88, 39, 50),
        Accent = Color3.fromRGB(238, 75, 94), AccentHover = Color3.fromRGB(255, 101, 116),
        AccentSoft = Color3.fromRGB(91, 38, 51), PrimaryText = Color3.fromRGB(250, 239, 241),
        MutedText = Color3.fromRGB(190, 157, 164), QuietText = Color3.fromRGB(139, 108, 116),
        Border = Color3.fromRGB(88, 49, 59), Danger = Color3.fromRGB(255, 90, 90),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(34, 20, 25),
        SegmentedBg = Color3.fromRGB(25, 16, 20),
    },
    CursorBlack = {
        Background = Color3.fromRGB(8, 9, 11), Sidebar = Color3.fromRGB(12, 13, 16),
        Panel = Color3.fromRGB(19, 20, 24), PanelRaised = Color3.fromRGB(25, 26, 31),
        Hover = Color3.fromRGB(34, 35, 41), Selected = Color3.fromRGB(39, 40, 47),
        Accent = Color3.fromRGB(160, 145, 255), AccentHover = Color3.fromRGB(180, 168, 255),
        AccentSoft = Color3.fromRGB(45, 40, 72), PrimaryText = Color3.fromRGB(245, 245, 248),
        MutedText = Color3.fromRGB(165, 166, 174), QuietText = Color3.fromRGB(112, 114, 124),
        Border = Color3.fromRGB(47, 48, 56), Danger = Color3.fromRGB(245, 86, 94),
        White = Color3.new(1, 1, 1), RightBg = Color3.fromRGB(10, 11, 13),
        SegmentedBg = Color3.fromRGB(15, 16, 19),
    },
}

local themeOrder = { "Dark", "White", "Blue", "MidnightBlue", "Red", "CursorBlack" }
local themeDisplayNames = { Dark = "Dark", White = "White", Blue = "Blue", MidnightBlue = "Midnight", Red = "Red", CursorBlack = "Cursor Black" }
