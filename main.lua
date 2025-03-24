-- main.lua
-- Five-species automaton + darkening with age + invisible noise
-- Minimalist UI at bottom-center, all sliders horizontal, including zoom.
--
-- Tweaks:
--  1) When multiple species each have neighborCount==3 for a dead cell, pick one at random.
--  2) If multiple species tie for "dominant," pick one at random if it exceeds the old species' neighbor count.
--
-- This prevents species 1 from always winning ties and births.

---------------------------
-- GLOBAL CONFIGURATION  --
---------------------------

local SIM_CELL_SIZE = 10
local MIN_ZOOM = 0.25
local MAX_ZOOM = 2.0

-- Larger base interval => more noticeable speed slider
local BASE_INTERVAL = 0.1

---------------------------
-- GLOBAL VARIABLES      --
---------------------------

local updateInterval = BASE_INTERVAL
local updateTimer = 0
local running = true

-- Simulation state
local cells = {}
local cellAge = {}

-- "Render" copies for invisible noise
local renderCells = {}
local renderAges  = {}

local gridWidth, gridHeight = 0, 0

-- We'll define a bottom UI panel
local UI_PANEL_W = 800
local UI_PANEL_H = 90
local uiPanelX   = 0
local uiPanelY   = 0

-- We'll define the four sliders as horizontal
local speedSlider = { x=0, y=0, w=100, h=10, value=1.0, dragging=false }
local fadeSlider  = { x=0, y=0, w=100, h=10, value=1.0, dragging=false }
local noiseSlider = { x=0, y=0, w=100, h=10, value=0.0, dragging=false }
local zoomSlider  = { x=0, y=0, w=100, h=10, value=0.0, dragging=false }

local zoomFactor = 1.0

-- Panning
local panX, panY = 0, 0
local panning = false
local panStartX, panStartY = 0, 0
local mouseStartX, mouseStartY = 0, 0

-- Tools
local toolMode = "default"

-- Generation counter
local generation = 0

-- Trails
local enableTrails = true
local trailAlpha = 0.05

---------------------------
-- HELPER FUNCTIONS      --
---------------------------

local function getSpeedMultiplier(value)
    -- 0 => 100%, 1 => 5000%
    return 1.0 + 49.0 * (value^2)
end

local function getFadeMultiplier(value)
    -- 0 => 100%, 1 => 5000% (slower fade)
    return 1.0 + 49.0 * (value^2)
end

local function getNoiseChance(value)
    -- 0 => 0%, 1 => 5%
    return 0.05 * value
end

-- Count neighbors for species 1..5
local function countAllNeighbors(x, y)
    local neighborCount = { [1]=0, [2]=0, [3]=0, [4]=0, [5]=0 }
    for j=-1,1 do
        for i=-1,1 do
            if not (i==0 and j==0) then
                local nx = ((x-1 + i) % gridWidth) + 1
                local ny = ((y-1 + j) % gridHeight) + 1
                local val = cells[ny][nx]
                if val>=1 and val<=5 then
                    neighborCount[val] = neighborCount[val] + 1
                end
            end
        end
    end
    return neighborCount
end

-- Modified to handle ties by picking at random if they exceed oldVal's count
local function findDominantSpecies(oldVal, neighborCount)
    -- If oldVal not in 1..5, no dominance check
    if oldVal<1 or oldVal>5 then
        return nil
    end

    local oldCount = neighborCount[oldVal]
    local bestCount = -1
    local candidates = {}

    for s=1,5 do
        local c = neighborCount[s]
        if c > bestCount then
            bestCount = c
            candidates = { s }
        elseif c == bestCount then
            table.insert(candidates, s)
        end
    end

    -- If bestCount <= oldCount, no takeover
    if bestCount <= oldCount then
        return nil
    end

    -- bestCount > oldCount => pick from candidates at random
    if #candidates==1 then
        return candidates[1]
    else
        -- tie => random pick
        return candidates[ math.random(#candidates) ]
    end
end

---------------------------
-- INIT & GRID           --
---------------------------

local function initGrid(randomize)
    randomize = (randomize==nil) and true or randomize
    local baseWidth  = math.floor(love.graphics.getWidth() / SIM_CELL_SIZE)
    local baseHeight = math.floor(love.graphics.getHeight() / SIM_CELL_SIZE)
    gridWidth  = baseWidth  * 2
    gridHeight = baseHeight * 2

    cells = {}
    cellAge = {}
    for y=1, gridHeight do
        cells[y] = {}
        cellAge[y] = {}
        for x=1, gridWidth do
            if randomize then
                local r = math.random()
                if r < 0.04 then
                    cells[y][x] = 1
                    cellAge[y][x] = 1
                elseif r < 0.08 then
                    cells[y][x] = 2
                    cellAge[y][x] = 1
                elseif r < 0.12 then
                    cells[y][x] = 3
                    cellAge[y][x] = 1
                elseif r < 0.16 then
                    cells[y][x] = 4
                    cellAge[y][x] = 1
                elseif r < 0.20 then
                    cells[y][x] = 5
                    cellAge[y][x] = 1
                else
                    cells[y][x] = 0
                    cellAge[y][x] = 0
                end
            else
                cells[y][x] = 0
                cellAge[y][x] = 0
            end
        end
    end

    -- Copy to render
    renderCells = {}
    renderAges  = {}
    for y=1, gridHeight do
        renderCells[y] = {}
        renderAges[y]  = {}
        for x=1, gridWidth do
            renderCells[y][x] = cells[y][x]
            renderAges[y][x]  = cellAge[y][x]
        end
    end
end

---------------------------
-- UPDATE LOGIC          --
---------------------------

local function updateCells(noiseChance)
    local newCells = {}
    local newAges  = {}

    for y=1, gridHeight do
        newCells[y] = {}
        newAges[y]  = {}
        for x=1, gridWidth do
            local oldVal = cells[y][x]
            local oldAge = cellAge[y][x]
            local neighborCount = countAllNeighbors(x, y)

            if oldVal>=1 and oldVal<=5 then
                local dominator = findDominantSpecies(oldVal, neighborCount)
                if dominator then
                    newCells[y][x] = dominator
                    newAges[y][x]  = 1
                else
                    local sameCount = neighborCount[oldVal]
                    if sameCount<2 or sameCount>3 then
                        newCells[y][x] = 0
                        newAges[y][x]  = oldAge
                    else
                        newCells[y][x] = oldVal
                        newAges[y][x]  = oldAge+1
                    end
                end

            else
                -- Dead cell => random pick if multiple species have neighbors==3
                local candidates = {}
                for s=1,5 do
                    if neighborCount[s]==3 then
                        table.insert(candidates, s)
                    end
                end

                if #candidates>0 then
                    -- pick random among them
                    local pick = candidates[ math.random(#candidates) ]
                    newCells[y][x] = pick
                    newAges[y][x]  = 1
                else
                    newCells[y][x] = 0
                    if oldVal==0 then
                        newAges[y][x] = math.max(oldAge-1, 0)
                    else
                        newAges[y][x] = oldAge
                    end
                end
            end
        end
    end

    -- Copy for rendering (pre-noise)
    for y=1, gridHeight do
        renderCells[y] = {}
        renderAges[y]  = {}
        for x=1, gridWidth do
            renderCells[y][x] = newCells[y][x]
            renderAges[y][x]  = newAges[y][x]
        end
    end

    -- Noise flips (invisible now)
    if noiseChance>0 then
        for y=1, gridHeight do
            for x=1, gridWidth do
                if math.random()<noiseChance then
                    local rv = math.random(0,5)
                    newCells[y][x] = rv
                    if rv==0 then
                        -- keep oldAge
                    else
                        newAges[y][x] = 1
                    end
                end
            end
        end
    end

    cells   = newCells
    cellAge = newAges
end

---------------------------
-- DRAWING FUNCTIONS     --
---------------------------

-- living cells darken to black => color = base*(1 - t)
local function drawSpeciesCell(s, age, x, y, fadeFactor)
    local t = math.min(age / fadeFactor, 1)
    local size = SIM_CELL_SIZE
    local half = size*0.5
    local cx   = (x-1)*size + half
    local cy   = (y-1)*size + half

    if s==1 then
        local baseR, baseG, baseB = 0.6, 0.9, 1.0
        local r = baseR*(1 - t)
        local g = baseG*(1 - t)
        local b = baseB*(1 - t)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle("fill", cx, cy, half)

    elseif s==2 then
        local baseR, baseG, baseB = 0.8, 0.3, 1.0
        local r = baseR*(1 - t)
        local g = baseG*(1 - t)
        local b = baseB*(1 - t)
        love.graphics.setColor(r, g, b, 1)
        local off = size*0.1
        local sq  = size*0.8
        love.graphics.rectangle("fill",(x-1)*size+off,(y-1)*size+off,sq,sq)

    elseif s==3 then
        local baseR, baseG, baseB = 1.0, 0.6, 0.0
        local r = baseR*(1 - t)
        local g = baseG*(1 - t)
        local b = baseB*(1 - t)
        love.graphics.setColor(r, g, b, 1)
        local off = size*0.1
        local tri = size*0.8
        local x1 = (x-1)*size + off
        local y1 = (y-1)*size + (off+tri)
        local x2 = x1 + tri
        local y2 = y1
        local xm = x1 + tri*0.5
        local ym = (y-1)*size + off
        love.graphics.polygon("fill", x1,y1, x2,y2, xm,ym)

    elseif s==4 then
        local baseR, baseG, baseB = 0.0, 1.0, 0.4
        local r = baseR*(1 - t)
        local g = baseG*(1 - t)
        local b = baseB*(1 - t)
        love.graphics.setColor(r, g, b, 1)
        local d = size*0.7
        local cx2 = cx
        local cy2 = cy
        love.graphics.polygon("fill",
            cx2,     cy2 - d*0.5,
            cx2 + d*0.5, cy2,
            cx2,     cy2 + d*0.5,
            cx2 - d*0.5, cy2)

    elseif s==5 then
        local baseR, baseG, baseB = 1.0, 0.5, 0.8
        local r = baseR*(1 - t)
        local g = baseG*(1 - t)
        local b = baseB*(1 - t)
        love.graphics.setColor(r, g, b, 1)
        local star = size*0.4
        love.graphics.polygon("fill",
            cx,       cy - star,
            cx+star,  cy,
            cx,       cy + star,
            cx-star,  cy)
    end
end

local function drawCells()
    local fadeFactor = 20 * getFadeMultiplier(fadeSlider.value)
    for y=1, gridHeight do
        for x=1, gridWidth do
            local s   = renderCells[y][x]
            local age = renderAges[y][x]
            if s>=1 and s<=5 then
                drawSpeciesCell(s, age, x, y, fadeFactor)
            else
                if age>0 then
                    local t = math.min(age/fadeFactor, 1)
                    local a = 1 - t
                    love.graphics.setColor(0.2,0,0,a)
                    love.graphics.rectangle("fill",(x-1)*SIM_CELL_SIZE,(y-1)*SIM_CELL_SIZE,SIM_CELL_SIZE,SIM_CELL_SIZE)
                end
            end
        end
    end
end

local function drawUI()
    -- Compute bottom panel position
    uiPanelX = (love.graphics.getWidth() - UI_PANEL_W)/2
    uiPanelY = love.graphics.getHeight() - UI_PANEL_H

    -- Draw semi-transparent rectangle
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", uiPanelX, uiPanelY, UI_PANEL_W, UI_PANEL_H)

    -- We'll place the sliders side by side
    local sliderY = uiPanelY + 40
    local sliderX = uiPanelX + 40
    local sliderGap = 140

    -- Speed slider
    speedSlider.x = sliderX
    speedSlider.y = sliderY
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", speedSlider.x, speedSlider.y, speedSlider.w, speedSlider.h)
    love.graphics.setColor(0.8,0.1,0.1)
    love.graphics.rectangle("fill",
        speedSlider.x + speedSlider.value*speedSlider.w - 5,
        speedSlider.y, 10, speedSlider.h)
    local spdPct = math.floor(getSpeedMultiplier(speedSlider.value)*100)
    love.graphics.setColor(1,0,0)
    love.graphics.print("Speed: "..spdPct.."%", speedSlider.x+speedSlider.w+10, speedSlider.y-3)

    -- Fade slider
    fadeSlider.x = sliderX + sliderGap
    fadeSlider.y = sliderY
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", fadeSlider.x, fadeSlider.y, fadeSlider.w, fadeSlider.h)
    love.graphics.setColor(0.8,0.1,0.1)
    love.graphics.rectangle("fill",
        fadeSlider.x + fadeSlider.value*fadeSlider.w - 5,
        fadeSlider.y, 10, fadeSlider.h)
    local fadePct = math.floor(getFadeMultiplier(fadeSlider.value)*100)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Fade: "..fadePct.."%", fadeSlider.x+fadeSlider.w+10, fadeSlider.y-3)

    -- Noise slider
    noiseSlider.x = sliderX + sliderGap*2
    noiseSlider.y = sliderY
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", noiseSlider.x, noiseSlider.y, noiseSlider.w, noiseSlider.h)
    love.graphics.setColor(0.8,0.1,0.1)
    love.graphics.rectangle("fill",
        noiseSlider.x + noiseSlider.value*noiseSlider.w - 5,
        noiseSlider.y, 10, noiseSlider.h)
    local noiPct = getNoiseChance(noiseSlider.value)*100
    love.graphics.setColor(1,1,1)
    love.graphics.print("Noise: "..string.format("%.2f", noiPct).."%", noiseSlider.x+noiseSlider.w+10, noiseSlider.y-3)

    -- Zoom slider
    zoomSlider.x = sliderX + sliderGap*3
    zoomSlider.y = sliderY
    love.graphics.setColor(0.3,0.3,0.3)
    love.graphics.rectangle("fill", zoomSlider.x, zoomSlider.y, zoomSlider.w, zoomSlider.h)
    love.graphics.setColor(0.8,0.1,0.1)
    love.graphics.rectangle("fill",
        zoomSlider.x + zoomSlider.value*zoomSlider.w - 5,
        zoomSlider.y, 10, zoomSlider.h)
    local zoomPct = math.floor(zoomFactor*100)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Zoom: "..zoomPct.."%", zoomSlider.x+zoomSlider.w+10, zoomSlider.y-3)

    -- Generation & Tool
    love.graphics.setColor(1,1,1)
    love.graphics.print("Generation: "..generation, uiPanelX+20, uiPanelY+10)
    love.graphics.print("Tool: "..toolMode, uiPanelX+220, uiPanelY+10)

    -- Instructions in one line
    love.graphics.print("[Space]=Pause  [R]=Random  [0]=Clear  [1..5]=Paint  [E]=Erase  [D]=Cycle  Middle=Pan  Wheel=Zoom",
        uiPanelX+20, uiPanelY+UI_PANEL_H-20)
end

---------------------------
-- LOVE CALLBACKS        --
---------------------------

function love.load()
    love.window.setTitle("Five-Species Automaton (Random Ties + Darken + Invisible Noise)")
    love.window.setMode(1920, 1080)

    initGrid(true)

    zoomSlider.value = (0.5 - MIN_ZOOM)/(MAX_ZOOM - MIN_ZOOM)
    zoomSlider.value = math.max(0, math.min(1, zoomSlider.value))
    zoomFactor = 0.5

    speedSlider.value = 1.0
    fadeSlider.value  = 1.0
    noiseSlider.value = 0.0

    panX, panY = 0,0
end

function love.update(dt)
    if speedSlider.dragging then
        local mx = love.mouse.getX()
        local rel = math.min(math.max(mx - speedSlider.x, 0), speedSlider.w)
        speedSlider.value = rel / speedSlider.w
    end
    if fadeSlider.dragging then
        local mx = love.mouse.getX()
        local rel = math.min(math.max(mx - fadeSlider.x, 0), fadeSlider.w)
        fadeSlider.value = rel / fadeSlider.w
    end
    if noiseSlider.dragging then
        local mx = love.mouse.getX()
        local rel = math.min(math.max(mx - noiseSlider.x, 0), noiseSlider.w)
        noiseSlider.value = rel / noiseSlider.w
    end
    if zoomSlider.dragging then
        local mx = love.mouse.getX()
        local rel = math.min(math.max(mx - zoomSlider.x, 0), zoomSlider.w)
        zoomSlider.value = rel / zoomSlider.w
        zoomFactor = MIN_ZOOM + (MAX_ZOOM - MIN_ZOOM)*zoomSlider.value
    end

    if panning then
        local mx,my = love.mouse.getPosition()
        panX = panStartX + (mx - mouseStartX)
        panY = panStartY + (my - mouseStartY)
    end

    local speedMult   = getSpeedMultiplier(speedSlider.value)
    updateInterval    = BASE_INTERVAL / speedMult
    local noiseChance = getNoiseChance(noiseSlider.value)

    if running then
        updateTimer = updateTimer + dt
        if updateTimer >= updateInterval then
            updateTimer = 0
            generation = generation + 1
            updateCells(noiseChance)
        end
    end
end

function love.draw()
    if enableTrails then
        love.graphics.setColor(0,0,0, trailAlpha)
        love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())
    else
        love.graphics.clear(0,0,0)
    end

    love.graphics.push()
    love.graphics.translate(panX, panY)
    love.graphics.scale(zoomFactor)

    drawCells()

    love.graphics.pop()

    drawUI()
end

function love.mousepressed(x, y, button)
    if button==1 then
        -- Check if clicking on sliders
        if x>=speedSlider.x and x<=speedSlider.x+speedSlider.w
           and y>=speedSlider.y and y<=speedSlider.y+speedSlider.h then
            speedSlider.dragging=true
            return
        end
        if x>=fadeSlider.x and x<=fadeSlider.x+fadeSlider.w
           and y>=fadeSlider.y and y<=fadeSlider.y+fadeSlider.h then
            fadeSlider.dragging=true
            return
        end
        if x>=noiseSlider.x and x<=noiseSlider.x+noiseSlider.w
           and y>=noiseSlider.y and y<=noiseSlider.y+noiseSlider.h then
            noiseSlider.dragging=true
            return
        end
        if x>=zoomSlider.x and x<=zoomSlider.x+zoomSlider.w
           and y>=zoomSlider.y and y<=zoomSlider.y+zoomSlider.h then
            zoomSlider.dragging=true
            return
        end
    end

    if button==2 then
        panning=true
        panStartX=panX
        panStartY=panY
        mouseStartX=x
        mouseStartY=y
        return
    end

    local gx = math.floor((x - panX)/(zoomFactor*SIM_CELL_SIZE)) + 1
    local gy = math.floor((y - panY)/(zoomFactor*SIM_CELL_SIZE)) + 1
    if gx<1 or gx>gridWidth or gy<1 or gy>gridHeight then return end

    if button==1 then
        if toolMode=="paint1" then
            cells[gy][gx] = 1
            cellAge[gy][gx] = 1
        elseif toolMode=="paint2" then
            cells[gy][gx] = 2
            cellAge[gy][gx] = 1
        elseif toolMode=="paint3" then
            cells[gy][gx] = 3
            cellAge[gy][gx] = 1
        elseif toolMode=="paint4" then
            cells[gy][gx] = 4
            cellAge[gy][gx] = 1
        elseif toolMode=="paint5" then
            cells[gy][gx] = 5
            cellAge[gy][gx] = 1
        elseif toolMode=="erase" then
            if cells[gy][gx]~=0 then
                cells[gy][gx] = 0
            end
        else
            -- default cycle: 0->1->2->3->4->5->0
            local ov = cells[gy][gx]
            local nv = (ov+1)%6
            cells[gy][gx] = nv
            if nv~=0 then
                cellAge[gy][gx] = 1
            end
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if panning then
        panX=panX+dx
        panY=panY+dy
    end
end

function love.mousereleased(x, y, button)
    if button==1 then
        speedSlider.dragging=false
        fadeSlider.dragging=false
        noiseSlider.dragging=false
        zoomSlider.dragging=false
    elseif button==2 then
        panning=false
    end
end

function love.wheelmoved(x, y)
    if y~=0 then
        local oldZ=zoomFactor
        zoomSlider.value = zoomSlider.value + y*0.05
        zoomSlider.value = math.max(0,math.min(1,zoomSlider.value))
        zoomFactor = MIN_ZOOM + (MAX_ZOOM - MIN_ZOOM)*zoomSlider.value

        local mx,my = love.mouse.getPosition()
        if oldZ~=0 then
            panX=mx-(mx-panX)*(zoomFactor/oldZ)
            panY=my-(my-panY)*(zoomFactor/oldZ)
        end
    end
end

function love.keypressed(key)
    if key=="space" then
        running=not running
    elseif key=="r" then
        generation=0
        initGrid(true)
    elseif key=="0" then
        generation=0
        initGrid(false)
    elseif key=="1" then
        toolMode="paint1"
    elseif key=="2" then
        toolMode="paint2"
    elseif key=="3" then
        toolMode="paint3"
    elseif key=="4" then
        toolMode="paint4"
    elseif key=="5" then
        toolMode="paint5"
    elseif key=="e" then
        toolMode="erase"
    elseif key=="d" then
        toolMode="default"
    end
end
