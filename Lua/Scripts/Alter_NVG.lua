local DefaultColor = GUI.ScreenOverlayColor

function SwitchNVG(MaskColor)
    if Game.LightManager.LightingEnabled then
        Game.GameScreen.ColorFade(DefaultColor,MaskColor,0.3)
        Game.LightManager.LightingEnabled = not Game.LightManager.LightingEnabled
    else
        Game.GameScreen.ColorFade(MaskColor,DefaultColor,0.3)
        Game.LightManager.LightingEnabled = not Game.LightManager.LightingEnabled
    end
end

Hook.Add("Deep_NVG_G", "Deep_NVG_G", function()
    SwitchNVG(Color(0,255,0,10))
end)