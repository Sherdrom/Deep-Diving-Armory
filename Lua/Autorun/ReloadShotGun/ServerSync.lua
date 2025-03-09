if SERVER then
    Networking.Receive("IsShootable", function(message, client)
        local itemID = tonumber(message.ReadString())
        print(client.Name .. " sent " .. itemID)
        local item = Entity.FindEntityByID(itemID)
        item.IsShootable = true
    end)
    return
end