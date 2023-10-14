-----------------------------
--  Krazy Sudoku 1.0       --
--     by J. Beaman        --
--     © 2022              --
--                         --
--  Sudoku puzzle patterns --
--  based on those created --
--  by KrazyDad.com © 2005 --
--                         --
--  Requires GTK 1.0       --
--     by J. Beaman        --
--     © 2021 - 2022       --
-----------------------------
function loadLibrary(libraryName)  
    -- libraryName is a string.  To refer to a 
    -- library from GTKLib, the string starts
    -- with "GTKLib\\".  (i.e. "GTKLib\\GTK_Base")
    local lualib
    
    -- load library source code
    lualib =  var.recall(libraryName)
  
    if not lualib then
      print("Library " .. libraryName .. " failed to load")
      return 
    end
  
    -- compile library  -- first pass
    lualib, err = loadstring(lualib)
    if err then
      error(err)
    end
  
    if not lualib then
      print("Library " .. libraryName .. " failed to compile")
      return
    end
  
    -- Run library   -- second pass 
    lualib()
  end
  
  -- Load GTK Library and image definitions
  loadLibrary("GTKLib\\gtk_base")
  
  local View     = gtk.View
  local Checkbox = gtk.Widgets.Checkbox
  local Button   = gtk.Widgets.Button
  local Label    = gtk.Widgets.Label
  local Input    = gtk.Widgets.Input
  local ListBox  = gtk.Views.ListBox
  local deepcopy = gtk.tools.deepcopy
  local Dialog   = gtk.Views.Dialog
  
  -- View Definitions:
  local puzzleBoard   = View() -- Game board
  local startScreen   = View() -- Opening screen
  local winScreen     = View() -- "Win" screen
  local pauseScreen   = View() -- Pause screen
  local bestTimesView = View() -- Duh
  
  ------------------------------------------------
  -- Sudoku Object                              --
  -- The Sudoku object/table is responsible for --
  -- the puzzle, itself.                        --
  ------------------------------------------------
  local Sudoku = {}
  do
    Sudoku.puzzle = {}
  
    local PlayGrid, DisplayGrid, SolutionGrid, OriginalGrid
    local table = table
    local math = math
  
    -- Deep Table Copy (different from gtk.tools.deepcopy)
    function table.copy(t) 
      local u = { } 
      for k, v in pairs(t) do 
        if type(v) ~= "table" then 
          u[k] = v 
        else 
          --print("Sub-Table detected : "..k.." "..tostring(v)..":"..type(v)) 
          u[k] = table.copy(v) 
        end 
      end 
      --print("Table copied") 
      return setmetatable(u, getmetatable(t)) 
    end 
    
    -- Sudoku Engine 
    
    local function GetLine(Case) 
      return math.floor((Case - 1) / 9) + 1 
    end 
    
    local function GetColumn(Case) 
      return (Case - 1) % 9 + 1 
    end 
    
    local function GetSquare(Case) 
      return math.floor((GetLine(Case)-1)/3) * 3 * 9 + math.floor((GetColumn(Case)-1)/3) * 3 + 1 
    end 
    
    -- Sudoku Engine from: Levak ©2011 (levak.free.fr levak92@gmail.com)
    local SudokuSolver = {}
  
    SudokuSolver.__index = SudokuSolver 
    
    function SudokuSolver.new(newGrid) 
      local sudoku = {} 
      setmetatable(sudoku, SudokuSolver) 
      sudoku.Grid = newGrid 
      return sudoku 
    end 
    
    function SudokuSolver:isHLineValidWithCase(Case, Value) 
      for i = (GetLine(Case) - 1) * 9 + 1, GetLine(Case) * 9 do 
        if Case ~= i and Value == self.Grid[i] then 
          return false 
        end 
      end 
      return true 
    end 
    
    function SudokuSolver:isVLineValidWithCase(Case, Value) 
      for j = GetColumn(Case), GetColumn(Case) + 72, 9 do 
        if Case ~= j and Value == self.Grid[j] then 
          return false 
        end 
      end 
      return true 
    end 
    
    function SudokuSolver:isSquareValidWithCase(Case, Value) 
      for j = 0, 2 do 
        for i = 0, 2 do 
          local c = GetSquare(Case) + i + j * 9 
          if Case ~= c and Value == self.Grid[c] then 
            return false 
          end 
        end 
      end 
      return true 
    end 
    
    function SudokuSolver:GetValidValues(Case) 
      local list = {} 
      for i = 1, 9 do 
        if   self:isHLineValidWithCase(Case, i) 
          and self:isVLineValidWithCase(Case, i) 
          and self:isSquareValidWithCase(Case, i) then 
            table.insert(list, i) 
        end 
      end 
      return list 
    end 
    
    function SudokuSolver:isValid(ZeroMatters) 
      for Case = 1, 81 do 
        if ZeroMatters and self.Grid[Case] == 0 then 
          return false 
        end 
        if self.Grid[Case] ~= 0 then 
          if  not self:isHLineValidWithCase(Case, self.Grid[Case]) 
            or not self:isVLineValidWithCase(Case, self.Grid[Case]) 
            or not self:isSquareValidWithCase(Case, self.Grid[Case]) then 
              return false 
          end 
        end 
      end 
      return true 
    end 
    
    function SudokuSolver:SolveSingletons() 
      local isThereAnySingleton 
      local minPossibilitiesCase 
      local minPossibilitiesCount 
      
      repeat 
        isThereAnySingleton = true 
        minPossibilitiesCase = 0 
        minPossibilitiesCount = 9 
        for Case = 1, 81 do 
          if self.Grid[Case] == 0 then 
            validValues = self:GetValidValues(Case)    
            local count = #validValues 
            if count == 1 then 
              self.Grid[Case] = validValues[1]; 
              isThereAnySingleton = false 
            elseif count > 1 then 
              if minPossibilitiesCount > count then 
                minPossibilitiesCount = count 
                minPossibilitiesCase = Case 
              end 
            end 
          end 
        end  
      until (isThereAnySingleton) 
      return minPossibilitiesCase 
    end 
    
    function SudokuSolver:Solve() 
      local nextCase = self:SolveSingletons() 
      if nextCase > 0 then 
        --print(tostring(nextCase)) 
        local validValues = self:GetValidValues(nextCase) 
        for i,value in ipairs(validValues) do 
          local newGrid = self.Grid --table.copy(self.Grid) 
          newGrid[nextCase] = value 
          local newSudokuSolver = SudokuSolver.new(table.copy(newGrid)) 
          newSudokuSolver:Solve() 
          if newSudokuSolver:isValid(true) then 
            self.Grid = newSudokuSolver.Grid 
            break 
          end 
        end 
      end 
    end 
    
    function SudokuSolver:GiveRandomValue(Case) 
      local validValues = self:GetValidValues(Case) 
      local newCase = validValues[math.random(1, #validValues)] 
      self.Grid[Case] = newCase 
    end 
    
    function SudokuSolver:PickUp() 
      for Case = 1, 81, 10 do 
        self:GiveRandomValue(Case) 
      end 
      for Case = 73, 9, -8 do 
        self:GiveRandomValue(Case) 
      end 
      for Case = 2, 8 do 
        self:GiveRandomValue(Case) 
      end 
      for Case = 74, 80 do 
        self:GiveRandomValue(Case) 
      end 
    end 
    
    function SudokuSolver:Generate() 
      if not pcall(function() return self:PickUp() end) then 
        self:Generate() 
      end 
      self:Solve() 
    end 
    
    function Sudoku:generateNewPuzzle(d, seed)
      local min, max, num
      local seed = seed or math.random(500)
      
      SolutionGrid = {} 
      for i = 1, 81 do 
        SolutionGrid[i] = 0 
      end 
      if d and seed then
        math.randomseed(seed) 
        if d == "easy" then 
          min = 40; max = 50 
        elseif d == "medium" then 
          min = 30; max = 40 
        elseif d == "difficult" then 
          min = 20; max = 30 
        elseif d == "expert" then 
          min = 16; max = 20 
        end 
        local solver = SudokuSolver.new(table.copy(SolutionGrid)) 
        solver:Generate() 
        SolutionGrid = solver.Grid 
      
        local visible = math.random(min, max) 
        OriginalGrid = table.copy(SolutionGrid) 
        local temp = {} 
        for i = 1, 81 do 
          temp[i] = i 
        end 
        --print("Clear Case count : "..tostring(visible)) 
        for i = 1, visible do 
          table.remove(temp, math.random(1, #temp)) 
        end 
        for _, num in pairs(temp) do 
          OriginalGrid[num] = 0 
        end 
      else 
        OriginalGrid = table.copy(SolutionGrid) 
      end 
      PlayGrid = table.copy(OriginalGrid) 
      DisplayGrid = PlayGrid 
      
      self.puzzle = {}
      self.puzzle.SolutionGrid = SolutionGrid
      self.puzzle.OriginalGrid = OriginalGrid
      self.puzzle.DisplayGrid  = DisplayGrid
      self.puzzle.PlayGrid     = PlayGrid
    end
    
    function Sudoku:resetPuzzle()
      local screens = gtk.RootScreen.screens
      local puzzleActive = false
      for x = 1, #screens do
        if screens[x] == puzzleBoard then
          puzzleActive = true
          break
        end
      end
  
      if not puzzleActive then
        return 
      end
      
      local scratchPad = {}
      for x = 1, 81 do
        scratchPad[x] = ""
      end
      self.puzzle.DisplayGrid  = table.copy(self.puzzle.OriginalGrid)
      self.puzzle.PlayGrid     = self.puzzle.DisplayGrid
      self.puzzle.ScratchPad   = scratchPad
      self.puzzle.ErrorCount   = 0
      puzzleBoard:onPushed()
    end
  
    -- (Most, if not all) Puzzle patterns (Challenging) from KrazyDad.com
    function Sudoku:loadPatterns()
      local patterns   = {}
      local varList = var.list()
      
      for x = 1, #varList do
        local varName = varList[x]
        local patternData = var.recall(varName)
        if varName:find("sudoku.pattern") then
          local ID = tonumber(varName:match("%d+"))
          patterns[ID] = {}
          patterns[ID].solution = patternData[1]
          patterns[ID].display  = patternData[2]
        end
      end
      self.patterns = patterns
    end
  
    function Sudoku:setNewPuzzle(mode)
      local scratchPad = {}
      local time       = "00:00:00"
      local errorCount = 0
  
      for x = 1, 81 do
        scratchPad[x] = ""
      end
      
      local pos = mode:find("%s")
      mode = string.lower(mode:match("%a+", pos))
      
      if mode == "krazydad" then
        if not self.patterns then
          self:loadPatterns()
        end
        local patterns  = self.patterns
        local index     = math.random(#patterns)
        local puzzle    = deepcopy(patterns[index].display)
        local key       = deepcopy(patterns[index].solution)
        local digets    = {1, 2, 3, 4, 5, 6, 7, 8, 9}
        local newKey    = {}
        local newPuzzle = {}
      
        for x = 1, 9 do
          local num = math.random(#digets)
          diget = digets[num]
          table.remove(digets, num)
          for y = 1, 81 do
            if puzzle[y] == x then
              newPuzzle[y] = diget
            elseif puzzle[y] == 0 then
              newPuzzle[y] = 0
            end
            if key[y] == x then
              newKey[y] = diget
            end
          end
        end
        self.puzzle = {}
        self.puzzle.SolutionGrid = newKey
        self.puzzle.OriginalGrid = newPuzzle
        self.puzzle.DisplayGrid  = deepcopy(newPuzzle)
        self.puzzle.PlayGrid     = deepcopy(newPuzzle)
      else
        self:generateNewPuzzle(mode)
      end
      self.puzzle.ScratchPad = scratchPad
      self.puzzle.Time       = time
      self.puzzle.ErrorCount = errorCount
      self.puzzle.mode       = mode    
    end
    
    function Sudoku:loadLastPuzzle()
      self.puzzle = {}
      self.puzzle.SolutionGrid = var.recall("krazy.solutiongrid")
      self.puzzle.OriginalGrid = var.recall("krazy.originalgrid")
      self.puzzle.PlayGrid     = var.recall("krazy.playgrid")
      self.puzzle.ScratchPad   = var.recall("krazy.scratchpad")
      self.puzzle.DisplayGrid  = self.puzzle.PlayGrid
      self.puzzle.Time         = var.recall("krazy.time")
      self.puzzle.ErrorCount   = var.recall("krazy.errorcount")
      self.puzzle.mode         = var.recall("krazy.mode")
    end
    
    function Sudoku:enterNewPattern()
      local patternView = View()
  
      local butSave = Button {
        position = Position {
          bottom = "3", right = "3"
        },
        text = "Save",
        auto = true
      }
  
      function butSave:onAction()
        local grids = self.parent.grids
        
        for x = 1, 81 do
          if grids.solution[x] == 0 then
            return 
          end
        end
        
        local varList = var.list()
        local ID = 0
        local varName
        repeat
          ID = ID + 1
          varName = "sudoku.pattern" .. ID
        until not var.recall(varName)
        
        local patternData = {}
        patternData[1] = grids.solution
        patternData[2] = grids.original
        var.store(varName, patternData)
        Sudoku:loadPatterns()
        
        gtk.RootScreen:popScreen()
        gtk.RootScreen:invalidate()
      end
      
      patternView:addChild(butSave)
          
      function patternView:onPushed()
        self.cursor = {1, 1}
        self.showCursor = true
        timer.start(.5)
        self.inputMode = "original"
        self.grids = {}
        local solution = {}
        local original = {}
        
        for x = 1, 81 do
          solution[x] = 0
          original[x] = 0
        end
        
        self.grids.solution = solution
        self.grids.original = original
    
      end
      
      function patternView:timer()
        self.showCursor = not self.showCursor
        self:invalidate()
      end
  
      function patternView:getIndex()
        local row = self.cursor[1]
        local col = self.cursor[2]
        return (row - 1)*9 + col
      end
  
      function patternView:backspaceKey()
        local grids = self.grids
        local mode  = self.inputMode
        local puzzle = grids[mode]
        local i = self:getIndex()
        
        if mode == "solution" and grids.original[i] == 0 then
          puzzle[i] = 0
        elseif mode == "original" then
          puzzle[i] = 0
          grids.solution[i] = 0
        end
        self:invalidate()
      end
      
      function patternView:enterKey()
        if self.focusIndex ~= 0 then
          return 
        end
        if self.inputMode == "original" then
          self.inputMode = "solution"
        else
          self.inputMode = "original"
        end
        self:invalidate()
      end
      
      function patternView:mouseUp(x, y)
        for row = 1, 9 do
          for col = 1, 9 do
            xStart = 26 + col * 23
            yStart = row * 23 - 23
            if x > xStart and x < xStart + 23 and y > yStart and y < yStart + 23 then
              self.cursor = {row, col}
              break
            end
          end
        end
        View.mouseUp(self, x, y)
      end
      
      function patternView:arrowUp()
        if self.focusIndex ~= 0 then
          return 
        end
        self.showCursor = false
        self.cursor[1] = self.cursor[1] - 1
        if self.cursor[1] == 0 then
          self.cursor[1] = 9
        end
      end
      
      function patternView:arrowDown()
        if self.focusIndex ~= 0 then
          return 
        end
        self.showCursor = false
        self.cursor[1] = self.cursor[1] + 1
        if self.cursor[1] == 10 then
          self.cursor[1] = 1
        end
      end
      
      function patternView:arrowLeft()
        if self.focusIndex ~= 0 then
          return 
        end
        self.showCursor = false
        self.cursor[2] = self.cursor[2] - 1
        if self.cursor[2] == 0 then
          self.cursor[2] = 9
        end
      end
      
      function patternView:arrowRight()
        if self.focusIndex ~= 0 then
          return 
        end
        self.showCursor = false
        self.cursor[2] = self.cursor[2] + 1
        if self.cursor[2] == 10 then
          self.cursor[2] = 1
        end
      end
  
      function patternView:charIn(key)
        local grids = self.grids
        local mode = self.inputMode
        local index = self:getIndex()
        
        if key >= "1" and key <= "9" then
          key = tonumber(key)
          if mode == "original" then
            grids.original[index] = key
            grids.solution[index] = key
          elseif grids.original[index] == 0 then
            grids.solution[index] = key
          end
        end
      end    
  
      function patternView:draw(gc)
        local grids = self.grids
        local mode = self.inputMode
        local grid = grids[mode]
        
        -- Border
        gc:setColorRGB(0, 0, 0)
        gc:setPen("medium")
        gc:drawRect(49, 0, 209, 209)
        
        -- Cursor
        local i = 0
        if self.showCursor then
          local row = self.cursor[1]
          local col = self.cursor[2]
          gc:setColorRGB(245, 200, 255)
          gc:fillRect(26 + col * 23, row * 23 - 23, 23, 23)
          gc:setColorRGB(0, 0, 0)
        end
        
        -- Draw board and numbers
        gc:setFont("sansserif", "b", 14)
        for row = 1, 9 do
          for col = 1, 9 do
            i = i + 1
            local num = grid[i]
            local isUserMove = (grids.original[i] == 0) and (mode == "solution")
    
            gc:setPen("thin")
            gc:drawRect(26 + col * 23, row * 23 - 23, 23, 23)
    
            if isUserMove then
              gc:setColorRGB(100, 100, 255)
            else 
              gc:setColorRGB(0, 0, 0)
            end
            if num ~= 0 then
              gc:drawString(num, 33 + col * 23, row * 23 + 2, "bottom")
            end
            gc:setColorRGB(0, 0, 0)
          end
        end
  
        gc:setPen("medium")
        gc:drawLine(119, 0, 119, 209)
        gc:drawLine(188, 0, 188, 209)
        gc:drawLine(50, 69, 259, 69)
        gc:drawLine(50, 138, 259, 138)
        
        gc:setFont("sansserif", "b", 10)
        gc:drawString("Mode:", 2, 2, "top")
        if mode == "original" then
          gc:setColorRGB(100, 100, 255)
        else 
          gc:setColorRGB(255, 0, 0)
        end
        gc:setFont("sansserif", "b", 6)
        gc:drawString(mode, 4, 18, "top")
        
        View.draw(self, gc)
      end
      
      
      gtk.RootScreen:pushScreen(patternView)
      gtk.RootScreen:invalidate()
    end
  
  end
  
  -----------------------
  -- Puzzle Board View --
  -----------------------
  do
    local inputMode = "Normal" -- or "Scratch Pad"
    
    local chkShowErrors = Checkbox {
      position = Position {
        top = "170px", left = "2px"
      },
      text = "Show Errors",
      value = true
    }
    
    local lblMode = Label{
      position = Position {
        top = "50px", left = "2px"
      },
      text = "Input Mode:",
      style = {
        font = {
          size = 9,
          style = "b"
        }
      }
    }
  
    local lblModeStatus = Label {
      position = Position {
        top = "0px", left = "20px", alignment = {
          { ref = lblMode, side = Position.Sides.Bottom },
          { ref = lblMode, side = Position.Sides.Left }
        }
      },
      text = "Normal",
      style = {
        textColor = { 0, 0, 200 },
        font = {
          size = 9,
          style = "b"
        }
      }    
    }
    
    local lblCount = Label{
      position = Position {
        bottom = "5px", left = "2px"
      },
      text = "Error Count: 0",
      style = {
        font = {
          size = 9,
          style = "r"
        }
      }
    }
    
    puzzleBoard:addChildren( lblMode, lblModeStatus, chkShowErrors, lblCount)
    
    function puzzleBoard:onPushed()
      self.clock       = gtk.tools.time.stopWatch()
      self.cursor      = {5, 5}
      self.showCursor  = true
      self.clockTick   = 0
      self.puzzleReady = false
      self.puzzle      = Sudoku.puzzle
      inputMode        = "Normal"
      
      if self.puzzle then
        self.puzzleReady = true
        timer.start(.5)
        self.clock:start()
      end
    end
  
    function puzzleBoard:draw(gc)
      if not self.puzzleReady then
        return 
      end
      local board      = self.puzzle.DisplayGrid
      local puzzle     = self.puzzle.OriginalGrid
      local time       = self.puzzle.Time
      local scratch    = self.puzzle.ScratchPad
      local errorCount = self.puzzle.ErrorCount
  
      -- Display elapsed time:
      gc:setColorRGB(0, 0, 0)
      gc:setFont("sansserif", "b", 9)
      gc:drawString("Elapsed Time:", 2, 10, "top")
      gc:setColorRGB(0, 200, 200)
      gc:drawString(time, 20, 25, "top")
      
      -- Border
      gc:setColorRGB(0, 0, 0)
      gc:setFont("sansserif", "b", 14)
      gc:setPen("medium")
      gc:drawRect(98, 0, 209, 209)
      
      -- Cursor
      local i = 0
      if self.showCursor then
        local row = self.cursor[1]
        local col = self.cursor[2]
        gc:setColorRGB(245, 200, 255)
        gc:fillRect(75 + col * 23, row * 23 - 23, 23, 23)
        gc:setColorRGB(0, 0, 0)
      end
      
      -- Draw board and numbers
      for row = 1, 9 do
        for col = 1, 9 do
          i = i + 1
          local num = board[i]
          local isUserMove = puzzle[i] == 0
  
          gc:setPen("thin")
          gc:drawRect(75 + col * 23, row * 23 - 23, 23, 23)
          if isUserMove then
            gc:setColorRGB(100, 100, 255)
            if chkShowErrors.value and not self:checkKey(i) then
              gc:setColorRGB(255, 100, 100)
            end
          else 
            gc:setColorRGB(0, 0, 0)
          end
          if num ~= 0 then
            gc:drawString(num, 82 + col * 23, row * 23 + 2, "bottom")
          end
          
          -- ScratchPad
          local num = scratch[i]
          if isUserMove and num:find("%d") then
            local str = ""
            local f1, f2, f3 = gc:setFont("sansserif", "r", 6)
            gc:setColorRGB(0, 200, 0)
            for d in string.gmatch(num, "%d") do
              str = str .. d .. " "
            end
            if #str > 4 then
              local str1 = str:sub(1, 4)
              local str2 = str:sub(5, 8) -- No more than four digits are ever displayed.
              gc:drawString(str1, 80 + col * 23, row * 23 - 10, "bottom") 
              gc:drawString(str2, 80 + col * 23, row * 23 - 2, "bottom") 
            else
              gc:drawString(str, 80 + col * 23, row * 23 - 10, "bottom") 
            end
            gc:setFont(f1, f2, f3)
          end
          gc:setColorRGB(0, 0, 0)
        end
      end
  
      gc:setPen("medium")
      gc:drawLine(168, 0, 168, 209)
      gc:drawLine(237, 0, 237, 209)
      gc:drawLine(99, 69, 308, 69)
      gc:drawLine(99, 138, 308, 138)
      
      lblCount.text = "Error Count: " .. errorCount
    end
  
    function puzzleBoard:checkPuzzle()
      local key   = self.puzzle.SolutionGrid
      local board = self.puzzle.PlayGrid
      
      key = table.concat(key)
      board = table.concat(board)
      return key == board
    end
  
    function puzzleBoard:timer()
      self.showCursor = not self.showCursor
      self.clockTick = self.clockTick + 1
      if self.clockTick > 1 then
        self.clockTick = 0
        self.puzzle.Time = self.clock:getTime()
      end
      self:invalidate()
    end
  
    function puzzleBoard:getIndex()
      local row = self.cursor[1]
      local col = self.cursor[2]
      return (row - 1)*9 + col
    end
  
    function puzzleBoard:checkKey(index)
      local key = self.puzzle.SolutionGrid
      local board = self.puzzle.PlayGrid
      
      return key[index] == board[index]
    end
  
    function puzzleBoard:savePuzzle()
      for k, v in pairs(self.puzzle) do
        local varName = "krazy." .. k
        var.store(varName, v)
      end
    end
  
    function puzzleBoard:checkMove()
      local index  = self:getIndex()
      local puzzle = self.puzzle.PlayGrid
      
      return puzzle[index] == 0
    end
  
    function puzzleBoard:backspaceKey()
      if self.focusIndex ~= 0 then
        return 
      end
      local i = self:getIndex()
      local puzzle = self.puzzle.OriginalGrid
      local board = self.puzzle.PlayGrid
      local scratch = self.puzzle.ScratchPad
      
      if puzzle[i] == 0 then
        board[i] = 0
        scratch[i] = ""
      end
      
      self.puzzle.DisplayGrid = self.puzzle.PlayGrid
    end
    
    function puzzleBoard:mouseUp(x, y)
      for row = 1, 9 do
        for col = 1, 9 do
          xStart = 75 + col * 23
          yStart = row * 23 - 23
          if x > xStart and x < xStart + 23 and y > yStart and y < yStart + 23 then
            self.cursor = {row, col}
            break
          end
        end
      end
    end
    
    function puzzleBoard:arrowUp()
      if self.focusIndex ~= 0 then
        return 
      end
      self.showCursor = false
      self.cursor[1] = self.cursor[1] - 1
      if self.cursor[1] == 0 then
        self.cursor[1] = 9
      end
    end
    
    function puzzleBoard:arrowDown()
      if self.focusIndex ~= 0 then
        return 
      end
      self.showCursor = false
      self.cursor[1] = self.cursor[1] + 1
      if self.cursor[1] == 10 then
        self.cursor[1] = 1
      end
    end
    
    function puzzleBoard:arrowLeft()
      if self.focusIndex ~= 0 then
        return 
      end
      self.showCursor = false
      self.cursor[2] = self.cursor[2] - 1
      if self.cursor[2] == 0 then
        self.cursor[2] = 9
      end
    end
    
    function puzzleBoard:arrowRight()
      if self.focusIndex ~= 0 then
        return 
      end
      self.showCursor = false
      self.cursor[2] = self.cursor[2] + 1
      if self.cursor[2] == 10 then
        self.cursor[2] = 1
      end
    end
  
    function puzzleBoard:charIn(key)
      self.focusIndex  = 0
      local board      = self.puzzle.PlayGrid
      local scratchPad = self.puzzle.ScratchPad
      
      local index = self:getIndex()
      if key == "R" then
        Sudoku:resetPuzzle()
        return 
      end
      if key >= "1" and key <= "9" then
        local moveOK = self:checkMove()
        if inputMode == "Normal" then
          if moveOK then
            scratchPad[index] = ""
            board[index] = tonumber(key)
            if not self:checkKey(index) then
              self.puzzle.ErrorCount = self.puzzle.ErrorCount + 1
            end
            if self:checkPuzzle() then
              timer.stop()
              gtk.RootScreen:pushScreen(winScreen)
              gtk.RootScreen:invalidate()
            end
            self:savePuzzle()
          end
        else
          if moveOK then
            local str = scratchPad[index]
            str = str .. key
            scratchPad[index] = str
          end
            self:savePuzzle()
        end
        
      end
      self.puzzle.DisplayGrid = self.puzzle.PlayGrid
    end
  
    function puzzleBoard:enterKey()
      if self.focusIndex ~= 0 then
        return 
      end
      if inputMode == "Normal" then
        inputMode = "Scratch Pad"
      else
        inputMode = "Normal"
      end
      lblModeStatus.text = inputMode
      self:invalidate()
    end
    
    function puzzleBoard:escapeKey()
      self.clock:stop()
      gtk.RootScreen:pushScreen(pauseScreen)
      gtk.RootScreen:invalidate()
    end
  end
  
  -----------------------
  -- Start Screen View --
  -----------------------
  do
    startScreen.backgroundColor = {0, 0, 0}
    local lblTitle = Label {
      position = Position {
        top = "10px", left = "57px"
      },
      text = "Krazy Sudoku",
      style = {
        textColor = {250, 50, 50},
        font = {
          size = 24,
          style = "b",
          serif = "serif"
        }
      }
    }  
    
    local butNewGame = Button {
      position = Position {
        top = "70px", left = "59px"
      },
      text = "       New Game",
      style = {
        defaultWidth = 200,
        defaultHeight = 30,
        backgroundColor = {50, 50, 200},
        textColor = {255, 255, 255},
        focusColor = {250, 50, 50},
        font = {
          size = 16,
          style = "b"
        }
      }
    }
  
    function butNewGame:onAction()
      --[[
      local options = { "Challenging KrazyDad Puzzle", "Generate Easy Sudoku",  "Generate Medium Sudoku", "Generate Difficult Sudoku", "Generate Expert Sudoku" }
      local function setMode(sel)
        local mode = options[sel]
        Sudoku:setNewPuzzle(mode)
        gtk.RootScreen:pushScreen(puzzleBoard)
        gtk.RootScreen:invalidate()
      end
      local dialog = ListBox("New Game", options, setMode)
      local listBox = dialog.children[1]
      listBox.style.backgroundColor = {0, 0, 50}
      listBox.style.textColor = {255, 255, 255}
      listBox.style.selectColor = {100, 0, 0}
      dialog.backgroundColor = { 0, 0, 100 }
      local OK = dialog.children[2]
      function listBox:enterKey()
        OK:onAction()
      end
      
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
      ]]--
      Sudoku:setNewPuzzle("Challenging KrazyDad Puzzle")
      gtk.RootScreen:pushScreen(puzzleBoard)
      gtk.RootScreen:invalidate()
    end
      
    local butResume = Button {
      position = Position {
        top = "120px", left = "59px"
      },
      text = "    Resume Game",
      style = {
        backgroundColor = {50, 50, 200},
        textColor = {255, 255, 255},
        focusColor = {250, 50, 50},
        defaultWidth = 200,
        defaultHeight = 30,
        font = {
          size = 16,
          style = "b"
        }
      }
    }
  
    function butResume:onAction()
      Sudoku:loadLastPuzzle()
      local time = Sudoku.puzzle.Time
      gtk.RootScreen:pushScreen(puzzleBoard)
      puzzleBoard.clock:set(time)
      puzzleBoard.clock:start()
      gtk.RootScreen:invalidate()
    end
    
    local lblAuthor = Label {
      position = Position {
        bottom = "5px", left = "180px"
      },
      text = "By J. Beaman ©2022",
      style = {
        textColor = {255, 255, 255}
      }
    }
      
    startScreen:addChildren(lblTitle, butNewGame, butResume, lblAuthor)
    
    function startScreen:onPushed()
      if not var.recall("krazy.solutiongrid") then
        butResume:hide()
        self:giveFocusToChildAtIndex(2)
      else
        butResume:show()
        self:giveFocusToChildAtIndex(3)
      end
      self:invalidate()
    end
    
  end
  
  ------------------
  -- "Pause" View --
  ------------------
  do 
    local lblPause = Label {
      position = Position {
        top = "50px", left = "100px"
      },
      style = {
        textColor = { 200, 0, 200 },
        font = {
          size = 24,
          style = "b"
        }
      },
      text = "PAUSED"
    }
    
    local lblTime = Label {
      position = Position {
        top = "100px", left = "90px"
      },
      style = {
        textColor = { 255, 0, 255 },
        font = {
          size = 14,
          style = "b"
        }
      },
      text = ""
    }
    
    local lblInstruction = Label {
      position = Position {
        bottom = "5px", right = "5px"
      },
      style = {
        textColor = { 255, 255, 255 },
        font = {
          size = 10,
          style = "b"
        }
      },
      text = "Press ESC to continue."
    }
    
    pauseScreen.backgroundColor = {0, 0, 10}
    
    pauseScreen:addChildren(lblPause, lblTime, lblInstruction)
  
    function pauseScreen:onPushed()
      local count = 0
      local total = 0
      local board = Sudoku.puzzle.PlayGrid
      local orig  = Sudoku.puzzle.OriginalGrid
      
      for x = 1, 81 do
        if board[x] ~= 0 and orig[x] == 0 then
          count = count + 1
        end
        if orig[x] == 0 then
          total = total + 1
        end
      end
      
      local done = math.floor(count/total * 100) .. "% at "
      lblTime.text = done .. Sudoku.puzzle.Time
    end
      
    function pauseScreen:onPopped()
      puzzleBoard.clock:start()
    end
  end
  
  ----------------
  -- "Win" View --
  ----------------
  do 
    local function isShorter(time1, time2)
      local h1 = tonumber(time1:sub(1,2))
      local m1 = tonumber(time1:sub(4,5))
      local s1 = tonumber(time1:sub(7,8))
      m1 = 60 * h1 + m1
      s1 = 60 * m1 + s1
      
      local h2 = tonumber(time2:sub(1,2))
      local m2 = tonumber(time2:sub(4,5))
      local s2 = tonumber(time2:sub(7,8))
      m2 = 60 * h2 + m2
      s2 = 60 * m2 + s2
      
      return s2 > s1
    end
    
    local lblWin = Label {
      position = Position {
        top = "10px", left = "80px"
      },
      style = {
        textColor = { 255, 0, 0 },
        font = {
          size = 24,
          style = "b"
        }
      },
      text = "YOU WIN!"
    }
    
    local lblTime = Label {
      position = Position {
        top = "80px", left = "80px"
      },
      style = {
        textColor = { 0, 0, 255 },
        font = {
          size = 12,
          style = "b"
        }
      },
      text = "Time:   00:15:23"
    }
  
    local lblType = Label {
      position = Position {
        top = "100px", left = "80px"
      },
      style = {
        textColor = { 0, 0, 255 },
        font = {
          size = 12,
          style = "b"
        }
      },
      text = "Level:  Challenging"
    }
  
    local lblInstruction = Label {
      position = Position {
        bottom = "5px", right = "5px"
      },
      style = {
        textColor = { 255, 255, 255 },
        font = {
          size = 10,
          style = "b"
        }
      },
      text = "Press ENTER to continue."
    }
    
    winScreen.backgroundColor = {0, 0, 0}
    
    winScreen:addChildren(lblWin, lblTime, lblType, lblInstruction)
    
    winScreen.bombs = {}
    local Bomb = class()
    do
      function Bomb:init()
        self.x = math.random(318)
        self.y = math.random(212)
        local r = math.random(100, 255)
        local g = math.random(0, 100)
        local b = math.random(100, 255)
        self.color = {r, g, b}
        self.d = 1
      end
      
      function Bomb:draw(gc)
        gc:setPen("thick")
        gc:setColorRGB(unpack(self.color))
        local x = self.x
        local y = self.y
        local d = self.d
        gc:drawCircle(x, y, d)
      end
      
    end
  
    function winScreen:onPushed()
      puzzleBoard.clock:stop()
      local time = puzzleBoard.puzzle.Time
      local mode = puzzleBoard.puzzle.mode
      
      if mode == "krazydad" then
        mode = "challenging"
      end
      
      mode = string.proper(mode)
      puzzleBoard.puzzle.mode = mode
      lblTime.text = "Time:   " .. time
      lblType.text = "Level:  " .. mode
      timer.start(.01)
    end  
    
    function winScreen:timer()
      local bombs = winScreen.bombs
  
      if #bombs < 10 then
        local numNew = math.random(3)
        for x = 1, numNew do
          local bomb = Bomb()
          table.insert(bombs, bomb)
        end
      end
      
      for x = #bombs, 1, -1 do
        bombs[x].d = bombs[x].d + 8
        if bombs[x].d > 40 then
          table.remove(bombs, x)
        end
      end
      self:invalidate()
    end
  
    function winScreen:draw(gc)
      View.draw(self, gc)
      local bombs = self.bombs
      for x = 1, #bombs do
        bombs[x]:draw(gc)
      end
    end
      
    function winScreen:enterKey()
      local screens = gtk.RootScreen.screens
      for x = 1, #screens do
        gtk.RootScreen:popScreen()
      end
      local varList = var.list()
      for x = 1, #varList do
        local varName = varList[x]
        if varName:find("krazy") then
          math.eval("DelVar " .. varName)
        end
      end
      
      gtk.RootScreen:pushScreen(startScreen) 
      gtk.RootScreen:invalidate()
      self:checkBestTimes()
      
    end
    
    function winScreen:checkBestTimes()
      local bestTimes = var.recall("besttimes")
      local time = puzzleBoard.puzzle.Time
      local errorCount = puzzleBoard.puzzle.ErrorCount
      local level = puzzleBoard.puzzle.mode
      local entry = {}
      entry.time = time
      entry.errorCount = errorCount
      entry.level = level
  
      if not bestTimes or #bestTimes < 8 then
        self:addBestTime(entry)
      elseif isShorter(entry.time, bestTimes[8][1]) then
        self:addBestTime(entry)
      else
        gtk.RootScreen:pushScreen(bestTimesView)
        gtk.RootScreen:invalidate()
      end
      
    end
    
    function winScreen:addBestTime(entry)
      local position = Position { top = "30px", left = "59px" }
      local dimension = Dimension("200px", "87px")
      local title = "New Top 8 Time of " .. entry.time .. "!"
      local dialog = Dialog(title, position, dimension)
      
      dialog.backgroundColor = {100, 0, 0}
      dialog.defaultFocus = 1
      
      local lblName = Label {
        position = Position {
          top = "30px", left = "5px"
        },
        text = "Name: ",
        style = {
          textColor = {255, 255, 255}
        }
      }
      
      local txtName = Input {
        position = Position {
          top = "0px", left = "0px", alignment = {
            { ref = lblName, side = Position.Sides.Top },
            { ref = lblName, side = Position.Sides.Right }
          }
        },
        style = {
          defaultWidth = 145,
          backgroundColor = { 0, 0, 100 },
          textColor = {255, 255, 255}
        }
      }
      
      local butSave = Button {
        position = Position {
          bottom = "4px", right = "4px"
        },
        auto = true,
        text = "Save"
      }
  
      function butSave:onAction()
        local bestTimes = var.recall("besttimes") or {  }
        local newEntry = {}
        local function byTimeA(a, b)
          return isShorter(a[1], b[1])
        end
  
        newEntry[1] = entry.time
        newEntry[2] = txtName.value
        newEntry[3] = entry.level
        newEntry[4] = entry.errorCount
        
        table.insert(bestTimes, newEntry)
        if #bestTimes > 1 then
          table.sort(bestTimes, byTimeA)
        end
  
        if #bestTimes > 8 then
          table.remove(bestTimes)
        end
        var.store("besttimes", bestTimes)
        
        gtk.RootScreen:popScreen()
        gtk.RootScreen:pushScreen(bestTimesView)
        gtk.RootScreen:invalidate()
      end
  
      dialog:addChildren(lblName, txtName, butSave)
      dialog.defaultFocus = 2
      
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
    
  end
  
  ---------------------
  -- Best Times View --
  ---------------------
  do
    bestTimesView.backgroundColor = {0, 0, 50}
    
    lblTitle = Label {
      position = Position {
        top = "0px", left = "75px"
      },
      style = {
        textColor = { 255, 0, 0 },
        font = {
          size = 24,
          style = "b"
        }
      },
      text = "Best Times"
    }
    
    lblTitleShadow = Label {
      position = Position {
        top = "1px", left = "76px"
      },
      style = {
        textColor = { 255, 0, 255 },
        font = {
          size = 24,
          style = "b"
        }
      },
      text = "Best Times"
    }
  
    local lblInstruction = Label {
      position = Position {
        bottom = "5px", right = "5px"
      },
      style = {
        textColor = { 255, 255, 255 },
        font = {
          size = 10,
          style = "b"
        }
      },
      text = "Press ESC to continue."
    }
    
    bestTimesView:addChildren(lblTitleShadow, lblTitle, lblInstruction)
  
    function bestTimesView:draw(gc)
      View.draw(self, gc)
      
      local bestTimes = var.recall("besttimes") or {}
      local xPos = { 2, 70, 200, 270 }
      local labels = { "Time", "Name", "Level", "Errors"}
      gc:setColorRGB(0, 255, 0)
      gc:setFont("sansserif", "b", 10)
  
      for x = 1, 4 do
        gc:drawString(labels[x], xPos[x], 40, "top")
      end
      xPos[4] = 290
      
      gc:setColorRGB(0, 0, 255)
      gc:setFont("sansserif", "r", 10)
      
      for x = 1, #bestTimes do
        local entry = bestTimes[x]
        for y = 1, 4 do
          gc:drawString(entry[y], xPos[y], 45 + x * 15, "top")
        end
      end
    end
  end
  
  local function startPuzzle(_, mode)
    local screens = gtk.RootScreen.screens
    Sudoku:setNewPuzzle(mode)
    for x = 1, #screens do
      if screens[x] == puzzleBoard then
        table.remove(screens, x)
        break
      end
    end
    gtk.RootScreen:pushScreen(puzzleBoard)
  end
  
  local menu = {
    { "New Puzzle",
      { "Generate Easy Sudoku", startPuzzle },
      { "Generate Medium Sudoku", startPuzzle },
      { "Generate Difficult Sudoku", startPuzzle },
      { "Generate Expert Sudoku", startPuzzle },
      { "Challenging KrazyDad Puzzle", startPuzzle }
    },
    { "Puzzle",
      { "Restart   (SHIFT + R)", function () Sudoku:resetPuzzle() end },
    },
    { "Options",
      { "Show Best Times", function () gtk.RootScreen:pushScreen(bestTimesView) gtk.RootScreen:invalidate() end },
      { "Enter New Pattern", function () Sudoku:enterNewPattern() end },
    },
  }
  toolpalette.register(menu)
  
  gtk.RootScreen:pushScreen(startScreen)
  