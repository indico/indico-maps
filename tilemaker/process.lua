-- Nodes will only be processed if one of these keys is present

node_keys = { "natural" }

-- Initialize Lua logic

function init_function()
end

-- Finalize Lua logic()
function exit_function()
end

-- Assign nodes to a layer, and set attributes, based on OSM tags

function node_function(node)
end

-- Similarly for ways

function way_function(way)
    local highway = way:Find("highway")
    local waterway = way:Find("waterway")
    local building = way:Find("building")
    local amenity = way:Find("amenity")
    local natural = way:Find("natural")
    local landuse = way:Find("landuse")

    if highway~="" then
        way:Layer("transportation", false)
        way:Attribute("class", highway)
    end
    if waterway~="" then
        way:Layer("waterway", false)
        way:Attribute("class", waterway)
    end
    if building~="" then
        local name = way:Find("name")
        if way:Intersects("cern_sites") then
            way:Layer("cern_building", true)
            if name ~= "" then
                way:LayerAsCentroid("building_names")
                way:Attribute("name", name)
            end
        else
            way:Layer("building", true)
        end
    end
    if amenity == "research_institute" then
        way:Layer("limits", false)
    end
    if natural ~= "" then
        way:Layer("spaces", true)
        way:Attribute("class", natural)
    end
    if landuse == "grass" then
        way:Layer("spaces", true)
        way:Attribute("class", "grass")
    end
end
