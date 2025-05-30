--------------------------------------------------------------------------------
-- Bucket Catch (Solar2D / Lua) – single‑file version, syntax‑checked
-- Tested on Solar2D 2025.3720 (Windows).  No external assets required.
--------------------------------------------------------------------------------

-- ╔══════════════╗
-- ║ 0 | SETUP   ║
-- ╚══════════════╝
local physics = require("physics")
physics.start()
physics.setGravity(0, 10)
physics.setDrawMode("normal")  -- change to "hybrid" for debug

-- Screen helpers
local cx, cy = display.contentCenterX, display.contentCenterY
local fullW, fullH = display.actualContentWidth, display.actualContentHeight
local left, right  = display.screenOriginX, fullW - display.screenOriginX
local top,  bottom = display.screenOriginY, fullH - display.screenOriginY

-- ╔════════════════════╗
-- ║ 1 | GAME VARIABLES ║
-- ╚════════════════════╝
local score, level, misses = 0, 1, 0
local livesMax, nextLevel  = 3, 10
local spawnDelay           = 700  -- milliseconds
local gameOver            = false
local balls               = {}
local spawnTimer          = nil

-- ╔══════════════╗
-- ║ 2 | UI / HUD ║
-- ╚══════════════╝
local hudGroup = display.newGroup()
local scoreTxt = display.newText({parent=hudGroup, text="Score: 0", x=left+100, y=top+40, fontSize=28, align="left"})
local levelTxt = display.newText({parent=hudGroup, text="Level: 1", x=left+100, y=top+80, fontSize=22})
local lifeIcons = {}
for i=1, livesMax do
    local heart = display.newText({
        parent = hudGroup,
        text   = "♥",          -- Unicode heart
        x      = left + 26 + (i-1)*36,
        y      = top  + 120,
        font   = native.systemFontBold,
        fontSize = 28
    })
    heart:setFillColor(1, 0.25, 0.6)
    lifeIcons[i] = heart
end

-- ╔══════════════╗
-- ║ 3 | BUCKET  ║
-- ╚══════════════╝
local bucketWidth, bucketHeight = 140, 90
local verts = {
    -bucketWidth/2, 0,
     bucketWidth/2, 0,
     bucketWidth*0.35, bucketHeight,
    -bucketWidth*0.35, bucketHeight,
}
local bucket = display.newPolygon(cx, bottom - bucketHeight/2 - 16, verts)
bucket.fill = { type="gradient", color1={0.7,0.4,1}, color2={1,0.5,0.9}, direction="down" }
local rim = display.newRect(bucket.x, bucket.y - bucketHeight/2 + 2, bucketWidth*0.92, 6)
rim:setFillColor(1,1,1,0.9)
physics.addBody(bucket, "static", {shape=verts})

-- bucket collision
local function bucketCollision(self, event)
    if event.phase ~= "began" then return end
    local ball = event.other
    if not balls[ball] then return end
    balls[ball] = nil; display.remove(ball)
    -- update score & level
    score = score + 1
    if score >= nextLevel then
        level      = level + 1
        nextLevel  = nextLevel + 10
        spawnDelay = math.max(250, spawnDelay - 60)
        if spawnTimer then timer.cancel(spawnTimer) end
        spawnTimer = timer.performWithDelay(spawnDelay, function() Runtime:dispatchEvent({name="spawnBall"}) end, 0)
    end
    scoreTxt.text = "Score: "..score
    levelTxt.text = "Level: "..level
end
bucket.collision = bucketCollision
bucket:addEventListener("collision")

-- ╔══════════════════╗
-- ║ 4 | BALL SPAWN   ║
-- ╚══════════════════╝
local palette = { {1,0.25,0.25}, {1,0.55,0.1}, {1,0.9,0}, {0.3,0.8,0.3}, {0.3,0.6,1}, {0.8,0.4,1} }
local function spawnBall()
    if gameOver then return end
    local radius = math.random(14,24)
    local xPos   = math.random(left+radius, right-radius)
    local ball   = display.newCircle(xPos, top - radius - 40, radius)
    ball:setFillColor(unpack(palette[math.random(#palette)]))
    physics.addBody(ball, "dynamic", {radius=radius, bounce=0})
    ball.isSensor = true
    ball:setLinearVelocity(0, 60 + level*20)
    balls[ball] = true
end
Runtime:addEventListener("spawnBall", spawnBall)

-- Initial timer
spawnTimer = timer.performWithDelay(spawnDelay, function() Runtime:dispatchEvent({name="spawnBall"}) end, 0)

-- ╔══════════════════════════╗
-- ║ 5 | GAME LOOP (FRAME)   ║
-- ╚══════════════════════════╝
local function gameLoop()
    if gameOver then return end
    for b,_ in pairs(balls) do
        if b and (b.y - b.path.radius > bottom + 30) then
            balls[b] = nil; display.remove(b)
            misses = misses + 1
            for i=1,livesMax do lifeIcons[i].isVisible = i <= (livesMax - misses) end
            if misses >= livesMax then
                -- Trigger Game Over
                gameOver = true; physics.pause(); timer.cancel(spawnTimer)
                local overlay = display.newRect(cx, cy, fullW, fullH); overlay:setFillColor(0,0,0,0.6)
                local txt  = display.newText({text="Game Over\nScore: "..score, x=cx, y=cy-40, fontSize=36, align="center"})
                local btn  = display.newRoundedRect(cx, cy+60, 180, 60, 12); btn:setFillColor(0.2,0.7,1)
                local lbl  = display.newText({text="Restart", x=btn.x, y=btn.y, fontSize=24})
                local function restart()
                    -- cleanup
                    for bb,_ in pairs(balls) do display.remove(bb) end; balls = {}
                    display.remove(overlay); display.remove(txt); display.remove(btn); display.remove(lbl)
                    score, level, misses, nextLevel = 0,1,0,10; spawnDelay = 700; gameOver=false
                    physics.start(); scoreTxt.text="Score: 0"; levelTxt.text="Level: 1"
                    for i=1,livesMax do lifeIcons[i].isVisible=true end
                    Runtime:addEventListener("enterFrame", gameLoop)
                    spawnTimer = timer.performWithDelay(spawnDelay, function() Runtime:dispatchEvent({name="spawnBall"}) end, 0)
                end
                btn:addEventListener("tap", restart)
                Runtime:removeEventListener("enterFrame", gameLoop)
                return
            end
        end
    end
end
Runtime:addEventListener("enterFrame", gameLoop)

-- ╔══════════════════╗
-- ║ 6 | INPUT TOUCH  ║
-- ╚══════════════════╝
local function onTouch(event)
    if gameOver then return true end
    if event.phase == "began" or event.phase == "moved" then
        local newX = math.max(left + bucketWidth/2, math.min(right - bucketWidth/2, event.x))
        bucket.x = newX; rim.x = newX
    end
    return true
end
Runtime:addEventListener("touch", onTouch)
