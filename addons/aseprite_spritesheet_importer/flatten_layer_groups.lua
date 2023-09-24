
local sprite = app.sprites[1]

function rename_flattened (group_name)
    for i,layer in ipairs(sprite.layers) do
        if layer.name == "Flattened" then
            layer.name = group_name
            layers_children_visible (layer, false)
            return
        end
    end
end

function layers_children_visible (layer, visibility)
    layer.isVisible = visibility
    if layer.isGroup then
        for i,lyr in ipairs(layer.layers) do
            layers_children_visible(lyr, visibility)
        end
    end
end

function delete_invisible_children (layer)
    if layer.isGroup then
        for i,lyr in ipairs(layer.layers) do
            delete_invisible_children(lyr)
        end
    end
    if layer.isVisible == false then
        app.range.layers = { layer }
        app.command.RemoveLayer()
    end
end

function get_next_group ()
    for i,lyr in ipairs(sprite.layers) do
        if lyr.isGroup then
            return lyr
        end
    end
    return nil
end

function flatten_groups ()
    if app.params["delete_invisible"] == "true" then
        for i,lyr in ipairs(sprite.layers) do
            delete_invisible_children (lyr)
        end
    end

    for i,lyr in ipairs(sprite.layers) do
        layers_children_visible (lyr, false)
    end

    while true do
        local group = get_next_group()
        if group == nil then
            break
        end
        local group_name = group.name
        -- Make all children visible and flatten visible
        layers_children_visible (group, true)
        app.command.FlattenLayers{ ["visibleOnly"]="true" }
        rename_flattened(group_name)
    end

    for i,lyr in ipairs(sprite.layers) do
        layers_children_visible (lyr, true)
    end
end

app.transaction(flatten_groups)
