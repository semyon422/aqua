-- https://love2d.org/wiki/Gradients
return function(dir, ...)
    local isHorizontal = true
    if dir == "vertical" then
        isHorizontal = false
    elseif dir ~= "horizontal" then
        error("bad argument #1 to 'gradient' (invalid value)", 2)
    end

    local colorLen = select("#", ...)
    if colorLen < 2 then
        error("color list is less than two", 2)
    end

    local meshData = {}
    if isHorizontal then
        for i = 1, colorLen do
            local color = select(i, ...)
            local x = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = {x, 1, x, 1, unpack(color)}
            meshData[#meshData + 1] = {x, 0, x, 0, unpack(color)}
        end
    else
        for i = 1, colorLen do
            local color = select(i, ...)
            local y = (i - 1) / (colorLen - 1)

            meshData[#meshData + 1] = {1, y, 1, y, unpack(color)}
            meshData[#meshData + 1] = {0, y, 0, y, unpack(color)}
        end
    end

    return love.graphics.newMesh(meshData, "strip", "static")
end
