local function inspectWindows()
    local allWindows = hs.window.allWindows()
    print("\nAll visible windows:")
    print("==================")
    for _, win in ipairs(allWindows) do
        local app = win:application()
        if app then
            print(string.format("App: %s", app:name()))
            print(string.format("Window Title: %s", win:title()))
            print(string.format("Role: %s", win:role() or "N/A"))
            print(string.format("Subrole: %s", win:subrole() or "N/A"))
            print("------------------")
        end
    end
end

return inspectWindows 