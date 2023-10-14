-----------------------------
--     nPlanner 2.0        --
--     by J. Beaman        --
--     © 2021 - 2022       --
--                         --
--  Organizer app for the  --
--  TI-Nspire CX series    --
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
  loadLibrary("nplanner.images")
  
  -- GTK View and Views
  local View            = gtk.View
  local CheckOptionBox  = gtk.Views.CheckOptionBox
  local ConfirmationBox = gtk.Views.ConfirmationBox
  local Dialog          = gtk.Views.Dialog
  local ListBox         = gtk.Views.ListBox
  local MessageBox      = gtk.Views.MessageBox
  local ScrollingDialog = gtk.Views.ScrollingDialog
  local ScrollingView   = gtk.Views.ScrollingView
  local SelectDate      = gtk.Views.SelectDate
  
  -- GTK Widgets
  local Button    = gtk.Widgets.Button
  local Checkbox  = gtk.Widgets.Checkbox
  local Dropdown  = gtk.Widgets.Dropdown
  local Editor    = gtk.Widgets.Editor
  local Input     = gtk.Widgets.Input
  local Label     = gtk.Widgets.Label
  local List      = gtk.Widgets.List
  
  -- GTK Widget Groups
  local DateGroup = gtk.WidgetGroups.DateGroup
  local TimeGroup = gtk.WidgetGroups.TimeGroup
  
  -- GTK Date Functions and Data
  local dayAbbrev    = gtk.tools.constants.dayAbbreviations
  local dayNames     = gtk.tools.constants.dayNames
  local monthNames   = gtk.tools.constants.monthNames
  local getFirstDay  = gtk.tools.date.getFirstDay
  local maxDays      = gtk.tools.date.numDays
  local splitDate    = gtk.tools.date.split
  local concatDate   = gtk.tools.date.concat
  local addDays      = gtk.tools.date.addDays
  local subtractDays = gtk.tools.date.subtractDays
  local date2Text    = gtk.tools.date.text
  local firstDate    = gtk.tools.date.first
  local lastDate     = gtk.tools.date.last
  local firstTime    = gtk.tools.time.first
  local lastTime     = gtk.tools.time.last
  local splitTime    = gtk.tools.time.split
  local concatTime   = gtk.tools.time.concat
  
  -- GTK General Tools
  local deepcopy = gtk.tools.deepcopy
  
  ---------------------------------------------
  -- nPlanner Views that must be referrenced --
  -- elsewhere.  (I.e. for scope.)           --
  ---------------------------------------------
  local calendarView     = View()
  local projectManager   = View()
  local contactDirectory = View()
  local contactInfo      = View()
  local plannerView      = View()
  
  local scrollDelay = 4 -- that is in 1/2 seconds, so 2 sec.
  
  -------------------------------------------
  -- This object provides settings data to --
  -- Views, handles loading/saving, and    --
  -- defines dialogs for the user to edit  --
  -- the settings.                         --
  -------------------------------------------
  local settingsManager = {}
  do
    function settingsManager:loadSettings()
      self.eventCategories    = var.recall("nplanner.eventCats")     or {"Personal", "Chapel", "IAG Group", "BPH Prep", "Art", "Study", "TV Show", "Radio", "Prayer"}
      self.contactCategories  = var.recall("nplanner.contactCats")   or {"Friend", "Family", "Catholic Apostolate", "Catholic Business", "Catholic Parish/Diocese", "Catholic Association", "Business", "Organization", "State/Federal Agency", "School/University"}
      self.communicationTypes = var.recall("nplanner.commTypes")     or {"Received Letter", "Sent Letter", "Phone Call", "Received Email", "Sent Email" }
      self.projectSettings    = var.recall("nplanner.projSettings")  or {"Priority", true }
      self.generalSettings    = var.recall("nplanner.genSettings")   or { 4 }
      self.eventFilter        = var.recall("nplanner.eventFilter")   or {}
      self.contactFilter      = var.recall("nplanner.contactFilter") or {}
      self.projectFilter      = var.recall("nplanner.projectFilter") or {}
      self.lastDate           = var.recall("nplanner.lastDate")      or "02/11/2022"
      
      local eventFilter = self.eventFilter
      if #eventFilter == 0 then
        self:resetFilter("eventFilter")
      end
      
      local contactFilter = self.contactFilter
      if #contactFilter == 0 then
        self:resetFilter("contactFilter")
      end
      
      local projectFilter = self.projectFilter
      if #projectFilter == 0 then
        self:resetFilter("projectFilter")
      end
    end
  
    function settingsManager:setFilter(name)
      local filter = name
      local choices
      if filter == "eventFilter" or filter == "projectFilter" then
        choices = self.eventCategories
      else
        choices = self.contactCategories
      end
      local values  = self[filter]
      
      local function set(newValues)
        self[filter] = newValues
        settingsManager:saveSettings()
        calendarView:refresh()
        local view = gtk.RootScreen:peekScreen()
        if view == projectManager then
          projectManager:resetView()
        end
      end
      local dialog = CheckOptionBox("Choose Categories", choices, set, values)
      
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
    
    function settingsManager:setLastDate(date)
      self.lastDate = date
      var.store("nplanner.lastDate", date)
    end
    
    function settingsManager:getLastDate()
      return self.lastDate
    end
    
    function settingsManager:saveSettings()
      var.store("nplanner.eventCats", self.eventCategories)
      var.store("nplanner.contactCats", self.contactCategories)
      var.store("nplanner.commTypes", self.communicationTypes)
      var.store("nplanner.projSettings", self.projectSettings)
      var.store("nplanner.genSettings", self.generalSettings)
      var.store("nplanner.eventFilter", self.eventFilter)
      var.store("nplanner.contactFilter", self.contactFilter)
      var.store("nplanner.projectFilter", self.projectFilter)
    end
    
    function settingsManager:resetFilter(filterName)
      local categoryName
      if filterName == "eventFilter" or filterName == "projectFilter" then
        categoryName = "eventCategories"
      else
        categoryName = "contactCategories"
      end
      local categories = self[categoryName]
      local filter = {}
      
      for x = 1, #categories do
        table.insert(filter, true)
      end
  
      self[filterName] = filter
    end
    
    function settingsManager:editList(settingName)
      local settings = deepcopy(self[settingName])
      local title = settingName
      if title == "eventCategories" then
        title = "Event/Project Categories"
      elseif title == "contactCategories" then
        title = "Contact Categories"
      else
        title = "Communication Types"
      end
      local position = Position { top = "10px", left = "20%" }
      local dimension = Dimension("60%", "160px")
      local dialog = Dialog(title, position, dimension)
      
      local lstItems = List {
        position = Position {
          top = "30px", left = "5px"
        },
        items = settings,
        style = {
          defaultHeight = 91
        }
      }
      
      local lblNew = Label {
        position = Position {
          top = "3px", left = "5px", alignment = {
            { ref = lstItems, side = Position.Sides.Bottom }
          }
        },
        text = "New Item:",
        style = {
          font = {
            size = 6
          }
        }
      }
      
      local txtNew = Input {
        position = Position {
          bottom = "5px", left = "5px"
        },
        style = {
          defaultWidth = 120
        }
      }
  
      local butUp = Button {
        position = Position {
          top = "30px", right = "5px"
        },
        text = "▲",
        auto = true
      }
      
      local butDown = Button {
        position = Position {
          top = "3px", right = "5px", alignment = {
            { ref = butUp, side = Position.Sides.Bottom }
          }
        },
        text = "▼",
        auto = true
      }
      
      local butSave = Button {
        position = Position {
          bottom = "3px", right = "4px"
        },
        text = "Save",
        auto = true
      }
  
      local butDelete = Button {
        position = Position {
          top = "7px", right = "7px", alignment = {
            { ref = butDown, side = Position.Sides.Bottom }
          }
        },
        text = "∅",
        auto = true,
        style = {
          font = {
            style = "b"
          },
          textColor = {255, 0, 0}
        }
      }
      
      dialog:addChildren(lstItems, lblNew, txtNew, butUp, butDown, butSave, butDelete)
      dialog.defaultFocus = 1
      
      -- Widget Methods:
      function butUp:onAction()
        lstItems:moveItemUp()
      end
      
      function butDown:onAction()
        lstItems:moveItemDown()
      end
      
      function lstItems:onAction()
        local sel   = self.selected
        local items = self.items
        local item  = items[sel]
        
        txtNew.value = item
        lblNew.text = "Edit Item:"
        self.parent:tabKey()
      end
      
      function txtNew:onFocus()
        if not lblNew.text:find("enter") then
          lblNew.text = lblNew.text .. " (<enter> to save)"
        end
      end
      
      function txtNew:onBlur()
        lstItems:invalidate()
        self.value = ""
        lblNew.text = "New Item:"
      end
      
      function txtNew:enterKey()
        local edit  = lblNew.text:find("Edit")
        local items = lstItems.items
        local sel   = lstItems.selected
        
        if edit and self.value ~= "" then
          items[sel] = self.value
        elseif self.value ~= "" then
          table.insert(items, 1, self.value)
          lstItems.selected = 1
          lstItems.top = 0
        end
        
        self.parent:backtabKey()
      end
      
      function txtNew:escapeKey()
        self.value = ""
        self.parent:backtabKey()
      end
      
      function butDelete:onAction()
        local sel = lstItems.selected
        local items = lstItems.items
        
        table.remove(items, sel)
        if sel > #items then
          lstItems.selected = #items
        end
      end
      
      function butSave:onAction()
        settingsManager[settingName] = deepcopy(lstItems.items)
        if settingName == "contactCategories" then
          settingsManager:resetFilter("contactFilter")
        else
          settingsManager:resetFilter("projectFilter")
          settingsManager:resetFilter("eventFilter")
        end
        
        settingsManager:saveSettings()
        calendarView:refresh()
        gtk.RootScreen:popScreen()
        gtk.RootScreen:invalidate()
      end
      
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
  end
  
  -- Default function used to make cursor work:
  function gtk.View:onPopped()
    timer.start(.5)
    local screens = gtk.RootScreen.screens
    local prev = screens[#screens - 1]
    if prev and prev.refresh then
      prev:refresh()
    end
  end
  
  -- Load settings:
  settingsManager:loadSettings()
  
  
  -----------------------------------------
  -- Contact Table/Object                --
  --                                     --
  -- Object is responsible for contact   --
  -- data file I/O from TI vars/files,   --
  -- and makes data available to other   --
  -- objects (i.e. Views).               --
  -----------------------------------------
  local Contact = {}
  do 
    Contact.searchFields = {"Name", "Address", "Phone", "Email", "DOB", "Notes", "History" }
    -- Not written as a "method" to make it easier to call from the menu
    function Contact.search(text, selectedCategories, selectedFields)
      if not Contact.varNames then
        Contact:getVarNames()
      end
      local varNames   = Contact.varNames
      local categories = settingsManager.contactCategories
      local catIndex   = Enum(categories)
      local fields     = Contact.searchFields
      local fieldIndex = Enum(fields)
      local results    = {}
      
      for x = 1, #fields do
        fieldIndex[fields[x]] = selectedFields[x]
      end
      for x = 1, #categories do
        catIndex[categories[x]] = selectedCategories[x]
      end
  
      for x = 1, #varNames do
        local varName = varNames[x]
        local contact = Contact:get(varName)
        if catIndex[contact.Category] then
          for y = 1, #fields do
            local field = fields[y]
            if fieldIndex[field] then
              if field == "History" and contact.History then
                local history = contact.History
                local historyDone = false
                for z = 1, #history do
                  if string.find(history[z].Date, text) or string.find(history[z].Type, text) or string.find(history[z].Notes, text) then
                    historyDone = true
                  end
                end
                if historyDone then
                  table.insert(results, contact)
                  break
                end
              else
                if type(contact[field]) == "string" and string.find(contact[field], text) then
                  table.insert(results, contact)
                  break
                end
              end
            end
          end
        end
      end
      if #results > 0 then
        local position  = Position { top = "5%", left = "10%" }
        local dimension = Dimension("80%", "78%")
        local dialog    = Dialog("Found " .. #results .. " Contacts", position, dimension)
        local items     = {}
        
        for x = 1, #results do
          local contact = results[x]
          table.insert(items, contact.Name)
        end
        local lstResults = List {
          position = Position {
            top = "30px", left = "3px"
          },
          items = items,
          style = {
            defaultWidth = 248,
            defaultHeight = 131
          }
        }
        
        function lstResults:onAction()
          local sel = self.selected
          local contact = results[sel]
          local current = gtk.RootScreen:peekScreen()
          
          if current ~= contactDirectory then
            gtk.RootScreen:pushScreen(contactDirectory)
          end
          gtk.RootScreen:pushScreen(contactInfo, contact)
          gtk.RootScreen:invalidate()
        end
        
        dialog:addChild(lstResults)
        dialog.defaultFocus = 1  
        gtk.RootScreen:pushScreen(dialog)
        gtk.RootScreen:invalidate()
      end
    end
  
    function Contact:saveHistory(contact)
      local sortD = gtk.tools.date.sortD
      local ID = contact.ID
      local history = contact.History or {}
      local varName = "history.n" .. ID
      local data = {}
      for x = 1, #history do
        data[x] = {}
        data[x][1] = history[x].Date
        data[x][2] = history[x].Type
        data[x][3] = history[x].Notes or ""
      end
      
      local function typeSort(data)
        for x = 1, #data - 1 do
          if data[x][1] == data[x + 1][1] then
            local a = data[x][2]
            local b = data[x + 1][2]
            if a:find("Receive") and b:find("Sent") then
              local temp = data[x]
              data[x] = data[x + 1]
              data[x + 1] = temp
            end
          end
        end
        return data
      end
      
      if #data > 0 then
        data = sortD(data, 1)
        data = typeSort(data)
        var.store(varName, data)
      else
        math.eval("DelVar " .. varName)
      end
    end
      
    function Contact:save(contact)
      local reindex = false
      if not contact then
        return 
      end
      
      if not contact.ID then
        contact.ID = self:getNewID()
        reindex = true
      end
      
      local varName = "contacts.n" .. contact.ID
      local data = {}
      data[1] = contact.Name
      data[2] = contact.Address or ""
      data[3] = contact.Phone or ""
      data[4] = contact.Email or ""
      data[5] = contact.Category or ""
      data[6] = contact.DOB or ""
      data[7] = contact.Notes or ""
      
      var.store(varName, data)
      self:getVarNames()
      
      if contact.History then
        self:saveHistory(contact)
      end
    end
    
    function Contact:getNewID()
      local ID = 1
      while var.recall("contacts.n" .. ID) do
        ID = ID + 1
      end
      return ID
    end
    
    function Contact:get(varName)
      local data = var.recall(varName)
      if not data then
        return false
      end
      local contact = {}
      contact.Name     = data[1]
      contact.Address  = data[2]
      contact.Phone    = data[3]
      contact.Email    = data[4]
      contact.Category = data[5]
      contact.DOB      = data[6]
      contact.Notes    = data[7]
      contact.ID       = varName:match("%d+")
      
      varName = "history.n" .. contact.ID
      data = var.recall(varName)
      local history
      
      if data then
        history = {}
        for x = 1, #data do
          history[x] = {}
          history[x].Date = data[x][1]
          history[x].Type = data[x][2]
          history[x].Notes = data[x][3]
        end
        contact.History = history
      end
      return contact
    end
    
    function Contact:getVarNames()
      local varList = var.list()
      local contactVars = {}
      
      for x = 1, #varList do
        local varName = varList[x]
        if varName:find("contacts.n") then
          table.insert(contactVars, varName)
        end
      end
      
      self.varNames = contactVars
    end
    
    function Contact:getIndex(letter)
      local index = {}
      local varList = self.varNames
      
      for x = 1, #varList do
        local varName = varList[x]
        local data = var.recall(varName)
        local name = data[1]
        local indexLetter = name:sub(1, 1)
        indexLetter = indexLetter:upper()
        
        if indexLetter == letter then
          table.insert(index, { name, varName })
        elseif letter == "#" and indexLetter:find("%d") then
          table.insert(index, { name, varName })
        end
        
        local function sortIndex(a, b)
          local a = a[1]
          aStart = a:sub(1, 1)
          aStart = aStart:upper()
          a = aStart .. a:sub(2)
          
          local b = b[1]
          bStart = b:sub(1, 1)
          bStart = bStart:upper()
          b = bStart .. b:sub(2)
          
          if a < b then
            return true
          end
        end
        
        table.sort(index, sortIndex)
        self.currentIndex = index
      end
    end
    
    function Contact:getNames()
      local index = self.currentIndex
      local names = { "--  Add New Contact --"}
      
      for x = 1, #index do
        table.insert(names,index[x][1])
      end
      
      return names
    end
    
    function Contact:delete(contact)
      if not contact or not contact.ID then
        return 
      end
      
      local varName = "contacts.n" .. contact.ID
      math.eval("DelVar " .. varName)
      
      varName = "history.n " .. contact.ID
      math.eval("DelVar " .. varName)
    end
  end
  
  -----------------------------------------
  -- calendarData Table                  --
  --                                     --
  -- Object is responsible for event     --
  -- data file I/O from TI vars/files,   --
  -- and makes data available to other   --
  -- objects (i.e. Views).               --
  -----------------------------------------
  local calendarData = {}
  do
    local eventTypes = {"Appointment", "Repeating", "HolyDay", "Holiday", "Anniversary" }
  
    -- Returns a list of dates that a given repeating
    -- event will fall on.
    local function getRepeatDates(event, month, year)
      local max        = maxDays(month, year)
      local monthStart = concatDate(month, 1, year)        
      local monthEnd   = concatDate(month, max, year)
      local repType    = string.sub(event.RepInfo, 1, 1)
      local repNum     = string.match(event.RepInfo, "%d+")
      local interval   = string.match(event.RepInfo, "%a", 2)
      local repDays    = ""
      local dates      = {}
    
      local inMonth
      
      if event.EndDate then
        inMonth = firstDate(event.Date, monthEnd) and lastDate(event.EndDate, monthStart)
      else
        inMonth = firstDate(event.Date, monthEnd)
      end
    
      if not inMonth then
        return {}
      end
    
      if repType == "C" then
        local pos = string.find(event.RepInfo, "%a", 2)
        repDays = string.sub(event.RepInfo, pos + 1)
      end
      
      if repType == "S" then
        local date = event.Date
        while firstDate(date, monthEnd) do
          if not event.EndDate or (event.EndDate and firstDate(date, event.EndDate)) then
            if lastDate(date, monthStart) then
              table.insert(dates, date)
            end
          end
          if interval == "D" then
            date = addDays(date, repNum)
          elseif interval == "W" then
            date = addDays(date, 7 * repNum)
          elseif interval == "M" then
            local m1, d1, y1 = splitDate(date)
            m1 = m1 + repNum
            if m1 > 12 then
              m1 = m1 - 12
              y1 = y1 + 1
            end
            date = concatDate(m1, d1, y1)
          elseif interval == "Y" then
            local m1, d1, y1 = splitDate(date)
            y1 = y1 + 1
            date = concatDate(m1, d1, y1)
          end
        end
      else
        local date = event.Date
        while firstDate(date, monthEnd) do
          local m, d, y = splitDate(date)
          if m < month then
            m = m + repNum
            d = 1
            if m > 12 then
              m = m - 12
              y = y + 1
            end
            date = concatDate(m, d, y)
          else
            local dayOfWeek = getFirstDay(month, year)
            local weekOfMonth = 1
            local m, d, y = splitDate(date)
            local dayCount = 0
            
            for day = 1, max do
              local checkFor = weekOfMonth .. dayOfWeek
              if repDays:find(checkFor) then
                date = concatDate(m, day, y)
                if firstDate(event.Date, date) then
                  if event.EndDate then
                    if lastDate(event.EndDate, date) then
                      table.insert(dates, date)
                    end
                  else
                    table.insert(dates, date)
                  end
                end
              end          
              dayOfWeek = dayOfWeek + 1
              dayCount = dayCount + 1
              if dayOfWeek > 7 then
                dayOfWeek = 1
              end
              if dayCount == 7 then
                dayCount = 0
                weekOfMonth = weekOfMonth + 1
              end
            end
            break
          end
        end
      end
      if #dates > 0 and #event.SkipDates > 0 then
        for x = #dates, 1, -1 do
          local date = dates[x]
          if event.SkipDates:find(date) then
            table.remove(dates, x)
          end
        end
      end
      return dates
    end
  
    function calendarData:purgeOld(date)
      if not date then
        return 
      end
      local m, d, y = splitDate(date)
      if not m or not d or not y then
        return 
      end
      
      local count   = 0
      local indexes = self.indexes
      local index   = indexes.Appointment or {}
      for x = 1, #index do
        local event = self:loadEvent(index[x])
        if firstDate(event.Date, date) then
          local varName = event.Type .. ".n" .. event.ID
          math.eval("DelVar " .. varName)
          count = count + 1
        end
      end
      index   = indexes.Repeating or {}
      for x = 1, #index do
        local event = self:loadEvent(index[x])
        if event.EndDate and firstDate(event.EndDate, date) then
          local varName = event.Type .. ".n" .. event.ID
          math.eval("DelVar " .. varName)
          count = count + 1
        end
      end
      
      calendarView:refresh()
      local dialog = MessageBox("Purge Complete", count .. " items were deleted.")
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
    
    -- Coded as a "member" rather than a "method" to
    -- make it easier to call from the menu.
    function calendarData.search(text)
      local indexes = calendarData.indexes
      local results = {}
      
      for category, index in pairs(indexes) do
        for x = 1, #index do
          local varName = index[x]
          local event = calendarData:loadEvent(varName)
          if string.find(event.Title, text) then
            table.insert(results, event)
          elseif event.Notes and string.find(event.Notes, text) then
            table.insert(results, event)
          end
        end
      end
      
      if #results > 0 then
        local items = {}
        for x = 1, #results do
          local event = results[x]
          items[x] = event.Date .. " - " .. event.Title .. " (" .. event.Type .. ")"
        end
  
        local position  = Position { top = "5%", left = "10%" }
        local dimension = Dimension("80%", "78%")
        local dialog    = Dialog("Found " .. #results .. " Events", position, dimension)
  
        local lstResults = List {
          position = Position {
            top = "30px", left = "3px"
          },
          items = items,
          style = {
            defaultWidth = 248,
            defaultHeight = 131
          }
        }
        
        function lstResults:onAction()
          local sel = self.selected
          local event = results[sel]
          local date = event.Date
          local m, d, y = splitDate(date)
          
          if not y then
            local _, _, y = splitDate(calendarView.date)
            date = concatDate(m, d, y)
          end
          
          calendarView.date = date
          calendarView:refresh()
          gtk.RootScreen:invalidate()
        end
        
        dialog:addChild(lstResults)
        dialog.defaultFocus = 1  
        gtk.RootScreen:pushScreen(dialog)
        gtk.RootScreen:invalidate()
  
        
      end
    end
    
    -- For a given event, finds an available ID
    function calendarData:getNewID(event)
      local prefix = event.Type .. ".n"
      local ID = 1
      
      while var.recall(prefix .. ID) do
        ID = ID + 1
      end    
      return ID    
    end
    
    function calendarData:loadEvent(varName)
      local varData = var.recall(varName)
      local event = {}
      local eventType = varName:match("%a+")
      local firstChar = eventType:sub(1, 1)
      
      firstChar = string.upper(firstChar)
      eventType = firstChar .. eventType:sub(2)
    
      event.Type  = eventType
      event.ID    = varName:match("%d+")
      event.Date  = varData[1]
      event.Title = varData[2]
      
      if eventType == "Appointment" or eventType == "Repeating" then
        event.Start    = varData[3]
        event.End      = varData[4]
        event.Category = varData[5]
        event.Priority = varData[6]
        event.Notes    = varData[7]
        event.ShowIcon = varData[8]
      elseif eventType == "Holyday" or eventType == "HolyDay" then
        event.Type     = "HolyDay"
        event.Rank     = varData[3]
      end
      
      if eventType == "Repeating" then
        event.EndDate   = varData[9]
        event.RepInfo   = varData[10]
        event.SkipDates = varData[11]
      end
      
      return event
    end
    
    function calendarData:saveEvent(event)
      event.ID = event.ID or self:getNewID(event)
      local varName = event.Type .. ".n" .. event.ID
    
      local data = {}
      data[1] = event.Date
      data[2] = event.Title
  
      if event.Type == "Appointment" or event.Type == "Repeating" then
        data[3] = event.Start
        data[4] = event.End
        data[5] = event.Category
        data[6] = event.Priority
        data[7] = event.Notes
        if event.ShowIcon == "True" then
          event.ShowIcon = true
        elseif event.ShowIcon == "False" then
          event.ShowIcon = false
        elseif event.ShowIcon == "Holiday" then
          event.ShowIcon = "Holiday"
        elseif event.ShowIcon == "Holy Day" then
          event.ShowIcon = "HolyDay"
        elseif event.ShowIcon == nil then
          event.ShowIcon = false
        end
        data[8] = event.ShowIcon
      elseif event.Type == "HolyDay" then
        data[3] = event.Rank
      end
      
      if event.Type == "Repeating" then
        data[9] = event.EndDate
        data[10] = event.RepInfo
        data[11] = event.SkipDates or ""
      end
      
      local m, d, y = splitDate(event.Date)
      
      var.store(varName, data)
      calendarView:refresh()
    end
  
    function calendarData:deleteEvent(event)
      local varName = event.Type .. ".n" .. event.ID
  
      math.eval("DelVar " .. varName)
      calendarView:refresh()
    end
      
    -- From all available TI variable files,
    -- generate indexes (list of file names)
    -- for appointments, holidays, etc.
    -- To limit index to one type, specify the
    -- type as a string (as above).
    function calendarData:indexVarNames(eventType)
      local varList = var.list()
      local indexes = {}
      indexes.Appointment = {}
      indexes.Repeating = {}
      indexes.HolyDay = {}
      indexes.Holiday = {}
      indexes.Anniversary = {}
      
      local indexTypes = eventTypes
      
      if eventType then
        indexTypes = { eventType }
      end
      
      for x = 1, #indexTypes do
        local varType = indexTypes[x]
        for num = #varList, 1, - 1 do
          varName = varList[num]
          if varName:find(string.lower(varType)) then
            table.insert(indexes[varType], varName)
            table.remove(varList, num)
          end
        end
      end
  
      if eventType then
        self.indexs[eventType] = indexes[eventType]
      else
        self.indexes = indexes
      end
    end
  
    function calendarData:applyFilter(month, year)
      local filter     = settingsManager.eventFilter
      local categories = settingsManager.eventCategories
      local needFilter = false
      
      for x = 1, #filter do
        if not filter[x] then
          needFilter = true
          break
        end
      end
      
      if not needFilter then
        return 
      end
      
      local data     = self.data[year][month]
      local max      = maxDays(month, year)
      local catIndex = Enum(settingsManager.eventCategories)
      
      for d = 1, max do
        local dayData = data[d]
        for k, v in pairs(dayData) do
          if k == "Repeating" or k == "Appointment" then
            for x = #v, 1, -1 do
              local event = v[x]
              local category = event.Category
              local index = catIndex[category]
              local hideEvent = false
              if index then
                hideEvent = not settingsManager.eventFilter[index]
              end
              if hideEvent then
                table.remove(v, x)
              end
            end
          end
        end
      end
      self.data[year][month] = data
    end
    
    function calendarData:loadMonth(month, year)
      local indexes = self.indexes
      local data = {}
      local max  = maxDays(month, year)
      
      if not indexes then
        self:indexVarNames()
        indexes = self.indexes
      end
      if not self.data then
        self.data = {}
      end
      if not self.data[year] then
        self.data[year] = {}
      end
      self.data[year][month] = {}
      data = self.data[year][month]
      for x = 1, #eventTypes do
        local eventType = eventTypes[x]
        local requireFullDate = eventType == "Appointment"
        
        local index = deepcopy(indexes[eventType])
  
        if eventType ~= "Repeating" and index then  -- Repeating events are handled separately
          for i = #index, 1, -1  do
            local varName = index[i]
            local varData = var.recall(varName)
            local date = varData[1]
            local m, d, y = splitDate(date)
            if (requireFullDate and m == month and year == y) or (m == month and not requireFullDate) then
              if not data[d] then
                data[d] = {}
              end
              if not data[d][eventType] then
                data[d][eventType] = {}
              end
              event = self:loadEvent(varName) or {}
              
              table.insert(data[d][eventType], event)
            end
          end
        elseif eventType == "Repeating" and index then
          for i = 1, #index do
            local varName = index[i]
            local event = self:loadEvent(varName)
            local dates = getRepeatDates(event, month, year)
            for _ = 1, #dates do
              local repDate = dates[_]
              local m, d, y = splitDate(repDate)
              if not data[d] then
                data[d] = {}
              end
              if not data[d][eventType] then
                data[d][eventType] = {}
              end
              table.insert(data[d][eventType], event)
            end
          end
        end
      end
  
      -- Get projects due this month:
      local varList = var.list()
      for x = 1, #varList do
        local varName = varList[x]
        if varName:find("projects.n") then
          --local varData = var.recall(varName)
          
          local project = projectManager:getProject(varName)
  
          if project.Due and string.sub(projectManager:getPercentDone(project), 1, 3) ~= "100" then
            local m, d, y = splitDate(project.Due)
            if m == month and y == year then
              if not data[d].DueDate then
                data[d].DueDate = {}
              end
              project.Type  = "DueDate"
              project.Date  = project.Start
              table.insert(data[d].DueDate, project)
            end
          end
        end
      end
      
      self.data[year][month] = data
      self:applyFilter(month, year)
    end
  
    function calendarData:getData(month, day, year)
      local data = self.data or {}
      if not data[year] or not data[year][month] then
        self:loadMonth(month, year)
        data = self.data
      end
      return data[year][month][day]
    end
    
    function calendarData:refresh(month, year)
      self.indexes = nil
      self.data = nil
      calendarData:loadMonth(month, year)
    end
    
    -- 'getEventList' returns a table with formatted
    -- event titles (long or short, depending on
    -- boolean 'fullText'), along with other fields
    -- used by Views.  'data' is the output of a 
    -- call to 'calendarData:getData(m, d, y).
    function calendarData:getEventList(data, fullText)
      local eventList = {}
      local sortA     = gtk.tools.time.sortA
      
      for k, v in pairs(data) do
        if k == "Appointment" or k == "Repeating" then
          for i = 1, #v do
            local event    = v[i]
            local text     = ""
            local lineItem = event
            
            if fullText then
              if event.Start then
                text = string.gsub(event.Start, " ", "") .. "-" .. string.gsub(event.End, " ", "") .. "  "
              else
                text = "All Day          "
              end
            else
              if event.Start then
                text = event.Start .. " - "
              else
                text = "All Day    - "
              end
            end
            
            text = text .. event.Title .. " (" .. event.Category .. ")"
            
            if event.Type == "Repeating" then
              text = text .. " ®"
            end
            lineItem.text = text
            table.insert(eventList, lineItem)
          end
        end
      end
    
      eventList = sortA(eventList, "Start")
    
      if data.Holiday then
        for i = 1, #data.Holiday do
          local event    = data.Holiday[i]
          local lineItem = event
          local text     = event.Title
          
          lineItem.text = text
          table.insert(eventList, 1, lineItem)
        end
      end
      
      if data.Anniversary then
        for i = 1, #data.Anniversary do
          local event    = data.Anniversary[i]
          local lineItem = event
          local text     = event.Title
          
          local m, d, y = splitDate(event.Date)
          if y then
            local mm, dd, yy = splitDate(calendarView.date)
            y = yy - y
            text = text .. " (" .. y .. ")"
          end
          lineItem.text = text
          table.insert(eventList, 1, lineItem)
        end
      end
      
      if data.HolyDay then
        for i = 1, #data.HolyDay do
          local event = data.HolyDay[i]
          local text  = event.Title
          local rank  = event.Rank
          local lineItem = event
    
          if fullText then
            rank = "  (" .. rank .. ")"
          else
            if rank == "Optional Memorial" then
              rank = " (OM)"
            elseif rank == "Memorial" then
              rank = " (M)"
            elseif rank == "Feast" then
              rank = " (Feast)"
            elseif rank == "Solemnity" then
              rank = " (Solemnity)"
            elseif rank == "Holy Day of Obligation" then
              rank = " (Solemnity ★)"
            end
          end
          
          lineItem.text = text .. rank
          table.insert(eventList, 1, lineItem)
        end
      end
  
      if data.DueDate then
        for i = 1, #data.DueDate do
          local event    = data.DueDate[i]
          local lineItem = event
          local text     = event.Title
          local space    = " "
          if fullText then
            space = "      "
          end
          lineItem.text = "Project due:" .. space .. text .. "  Status: " .. projectManager:getPercentDone(event) .. "   (" .. event.Category .. ")"
          table.insert(eventList, 1, lineItem)
        end
      end
      
      return eventList  
    end  
  end
  
  ------------------------------------------
  -- Tools/Dialogs used by multiple Views --
  ------------------------------------------
  
  --------------------------------------
  -- Purge completed appointments and --
  -- repeating events.                --
  --------------------------------------
  local function showPurgeDialog()
    local position  = Position { top = "30px", left = "50px" }
    local dimension = Dimension("200px", "110px")
    local title     = "Purge Old Events"
    local dialog    = Dialog(title, position, dimension)
    local date      = calendarView.date
    
    local lblTitle = Label {
      position = Position {
        top = "30px", left = "5px"
      },
      text = "Delete events ON and BEFORE:"
    }
    
    dialog:addChild(lblTitle)
    
    local dateGroup = DateGroup(
      Position {
        top = "4px", left = "50px", alignment = {
          { ref = lblTitle, side = Position.Sides.Bottom },
          { ref = lblTitle, side = Position.Sides.Left }
        }
      },
      dialog,
      date
    )
    
    local butCancel = Button {
      position = Position { 
        bottom = "3px", right = "43px"
      },
      text = "Cancel",
      auto = true
    }
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
    
    local butDelete = Button {
      position = Position { 
        bottom = "3px", right = "5px", alignment = {
          { ref = butCancel, side = Position.Sides.Left }
        }
      },
      text = "Delete",
      auto = true
    }
    function butDelete:onAction()
      local date = dateGroup:getValue()
      local function purge()
        calendarData:purgeOld(date)
      end
      gtk.RootScreen:popScreen()
      local dialog = ConfirmationBox("Purge Events!", "Are you sure you want to DELETE all appointments completed ON or BEFORE: " .. date .. "?", purge)
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
    
    dialog:addChildren(butCancel, butDelete)
    dialog.defaultFocus = 2
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  ---------------------------------------
  -- Generate "Letters Project" Dialog --
  ---------------------------------------
  local function showAutoTaskDialog()
    local position   = Position { top = "15%", left = "15%" }
    local dimension  = Dimension("213px", "127px")
    local title      = "Write to..."
    local dialog     = Dialog(title, position, dimension)
    local categories = settingsManager.contactCategories
    local selected   = {}
    local catText    = "Family, Friends"
    local date       = calendarView.date
    
    for x = 1, #categories do
      if categories[x] == "Family" or categories[x] == "Friend"  then
        selected[x] = true
      else
        selected[x] = false
      end
    end
    
    local lblCategories = Label {
      position = Position {
        top = "30px", left = "5px"
      },
      text = "Categories: " .. catText,
      limit = true,
      style = {
        defaultWidth = 198,
        textColor = { 0, 0, 100 },
        font = {
          size = 9,
          style = "b"
        }
      }
    }
    
    local butSelect = Button {
      position = Position {
        top = "48px", right = "5px"
      },
      text = "Select Categories",
      auto = true,
      style = {
        defaultHeight = 18,
        textColor = {0, 0, 200},
        font = {
          size = 8
        }
      }
    }
    
    local chkAll = Checkbox {
      position = Position {
        top = "50px", left = "5px"
      },
      text = "All Dates",
      value = true
    }
    
    local lblFrom = Label {
      position = Position {
        top = "7px", left = "0px", alignment = {
          { ref = chkAll, side = Position.Sides.Bottom },
          { ref = chkAll, side = Position.Sides.Left }
        }
      },
      text = "Start From: "
    }
      
    dialog:addChildren(lblCategories, butSelect, chkAll, lblFrom)
  
    local from = DateGroup(
      Position {
        top = "4px", left = "-18px", alignment = {
          { ref = butSelect, side = Position.Sides.Bottom },
          { ref = butSelect, side = Position.Sides.Left }
        }
      },
      dialog,
      date
    )
    
    local butStart = Button {
      position = Position { 
        bottom = "3px", right = "60px"
      },
      text = "Start",
      auto = true
    }
    
    local butCancel = Button {
      position = Position { 
        bottom = "3px", right = "5px", alignment = {
          { ref = butStart, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    
    -- Widget Actions:
    function chkAll:onAction()
      if self.value then
        from:disable()
      else
        from:enable()
      end
    end
    
    function butSelect:onAction()
      local function set(val)
        local str = ""
        selected = val
        for x = 1, #categories do
          if selected[x] then
            if #str > 1 then
              str = str .. ", "
            end
            str = str .. categories[x]
          end
        end
        lblCategories.text = "Categories: " .. str
      end
      local dialog = CheckOptionBox("Choose Categories", categories, set, selected)
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
  
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
    
    function butStart:onAction()
      Contact:getVarNames()
      local catIndex = Enum(categories)
      local index    = Contact.varNames
      local tasks    = {}
      local received = {}
      
      for x = 1, #index do
        local contact = Contact:get(index[x])
        local cat = contact.Category
        
        if selected[catIndex[cat]] and contact.History then
          local history = contact.History[1]
          local date    = history.Date
          local item    = history.Type
          local after   = true
          
          if not chkAll.value then
            after = from:getValue()
            after = lastDate(date, after)
          end
          
          if item:find("Received") and after then
            table.insert(received, { contact.Name, history.Date })
          end  
        end
        
      end
      
      if #received > 0 then
        local project    = {}
        
        received = gtk.tools.date.sortA(received, 2)
        for t = 1, #received do
          table.insert(tasks, received[t][1] .. " (" .. received[t][2] .. ")")
        end
        project.Title    = "Write Letters " .. calendarView.date
        project.Notes    = ""
        project.Due      = false
        project.Start    = false
        project.Category = "Personal"
        project.Priority = "High"
        
        local taskIDs = {}
        for x = 1, #tasks do
  
          local taskID = 0
          local task = {tasks[x], false}
          
          if taskID == 0 then
            local ID = 1
            while var.recall("tasks.n" .. ID) do
              ID = ID + 1
            end
            taskID = ID
            table.insert(taskIDs, taskID)
          end
          
          var.store("tasks.n" .. taskID, task)                
        end
        project.TaskIDs = table.concat(taskIDs, ";")
        projectManager:saveProject(project)
        
        dialog = MessageBox(project.Title, "The project has been saved.  You have " .. #tasks .. " letters to write.")
      else
        dialog = MessageBox("Information", "No correspondence fits the given criteria")
      end
      gtk.RootScreen:popScreen()
      gtk.RootScreen:pushScreen(dialog)
    end
    
    dialog:addChildren(butStart, butCancel)
    dialog.defaultFocus = 2
    
    gtk.RootScreen:pushScreen(dialog)
    from:disable()
    
    gtk.RootScreen:invalidate()
  end
  
  ----------------------------------
  -- Simple Search Dialog (Can be --
  -- used for multiple searches)  --
  ----------------------------------
  local function showSimpleSearchDialog(title, searchFunction)
    local position   = Position { top = "20%", left = "15%" }
    local dimension  = Dimension("212px", "85px")
    local title      = title or ""
    local dialog     = Dialog(title, position, dimension)
  
    local txtSearch = Input {
      position = Position {
        top ="30px", left = "5px"
      },
      style = {
        defaultWidth = 201
      }
    }
    
    local butSearch = Button {
      position = Position { 
        bottom = "3px", right = "55px"
      },
      text = "Search",
      auto = true
    }
    
    local butCancel = Button {
      position = Position { 
        bottom = "3px", right = "5px", alignment = {
          { ref = butSearch, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    
    dialog:addChildren(txtSearch, butSearch, butCancel)
    
    -- Widget Actions:
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
    
    function butSearch:onAction()
      local text = txtSearch.value
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
      searchFunction(text)
    end
    
    dialog.defaultFocus = 1
    
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  ---------------------------------
  -- Search Dialog  (Can be      --
  -- used for multiple searchs)  --
  ---------------------------------
  local function showSearchDialog(title, categories, fields, searchFunction)
    local position   = Position { top = "15%", left = "15%" }
    local dimension  = Dimension("213px", "127px")
    local title      = title or ""
    local dialog     = Dialog(title, position, dimension)
    local categories = categories or {}  
    local fields     = fields or {}
    local selectedFields     = {}
    local selectedCategories = {}
    
    for x = 1, #categories do
      selectedCategories[x] = true
    end
    for x = 1, #fields do
      selectedFields[x] = true
    end
    
    local lblCategories = Label {
      position = Position {
        top = "30px", left = "5px"
      },
      text = "Search " .. #selectedCategories .. " Categories...",
      style = {
        defaultWidth = 100,
        textColor = { 0, 0, 100 },
        font = {
          size = 6,
          style = "b"
        }
      }
    }
  
    local lblFields = Label {
      position = Position {
        top = "30px", right = "7px"
      },
      text = "Search " .. #selectedFields .. " Fields...",
      style = {
        defaultWidth = 100,
        textColor = { 0, 0, 100 },
        font = {
          size = 6,
          style = "b"
        }
      }
    }
      
    local butCategories = Button {
      position = Position {
        top = "48px", left = "5px"
      },
      text = "Select Categories",
      auto = true,
      style = {
        defaultHeight = 18,
        textColor = {0, 0, 200},
        font = {
          size = 8
        }
      }
    }
  
    local butFields = Button {
      position = Position {
        top = "48px", right = "5px"
      },
      text = "   Select Fields   ",
      auto = true,
      style = {
        defaultHeight = 18,
        textColor = {0, 0, 200},
        font = {
          size = 8
        }
      }
    }
  
    local txtSearch = Input {
      position = Position {
        top ="4px", left = "0px", alignment = {
          { ref = butCategories, side = Position.Sides.Bottom },
          { ref = butCategories, side = Position.Sides.Left }
        }
      },
      style = {
        defaultWidth = 201
      }
    }
    
    local butSearch = Button {
      position = Position { 
        bottom = "3px", right = "55px"
      },
      text = "Search",
      auto = true
    }
    
    local butCancel = Button {
      position = Position { 
        bottom = "3px", right = "5px", alignment = {
          { ref = butSearch, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    
    dialog:addChildren(lblCategories, lblFields, butCategories, butFields, txtSearch, butSearch, butCancel)
    
    -- Widget Actions:
    
    function butCategories:onAction()
      local function set(val)
        selectedCategories = val
        local count = 0
        for x = 1, #categories do
          if selectedCategories[x] then
            count = count + 1
          end
        end
        lblCategories.text = "Search " .. count .. " Categories..."
      end
      local dialog = CheckOptionBox("Choose Categories", categories, set, selectedCategories)
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
  
    function butFields:onAction()
      local function set(val)
        selectedFields = val
        local count = 0
        for x = 1, #fields do
          if selectedFields[x] then
            count = count + 1
          end
        end
        lblFields.text = "Search " .. count .. " Fields..."
      end
      local dialog = CheckOptionBox("Choose Fields", fields, set, selectedFields)
      gtk.RootScreen:pushScreen(dialog)
      gtk.RootScreen:invalidate()
    end
  
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
    
    function butSearch:onAction()
      local text = txtSearch.value
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
      searchFunction(text, selectedCategories, selectedFields)
    end
    
    dialog.defaultFocus = 5
    
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  --------------------------
  -- New/Edit Anniversary --
  --------------------------
  local function showAnniversaryDialog(anniversary)
    local position    = Position { top = "15%", left = "15%" }
    local dimension   = Dimension("213px", "112px")
    local anniversary = anniversary or {}
    local title       = (anniversary.ID and "Edit Anniversary") or "New Anniversary"
    local dialog      = Dialog(title, position, dimension)
    local date        = anniversary.Date or settingsManager:getLastDate()
    local m, d, y     = splitDate(date)
  
    local txtTitle = Input {
      position = Position {
        top = "30px", left = "48px"
      },
      style = {
        defaultWidth = 154
      },
      value = anniversary.Title or ""
    }
    
    local lblTitle = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Top },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      text = "Title: "
    }
  
    local txtMonth = Input {
      position = Position { 
        top = "4px", left = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = m
    }
    
    local lblDate = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Left }
        }
      },
      text = "Date: "
    }
  
    lblDivide1 = Label {
      position = Position { 
        top = "0px", left = "1px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Right }
        }
      },
      text = "/"
    }
  
    local txtDay = Input {
      position = Position { 
        top = "4px", left = "1px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = lblDivide1, side = Position.Sides.Right }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = d
    }
  
    lblDivide2 = Label {
      position = Position { 
        top = "0px", left = "1px", alignment = {
          { ref = txtDay, side = Position.Sides.Top },
          { ref = txtDay, side = Position.Sides.Right }
        }
      },
      text = "/"
    }
  
    local txtYear = Input {
      position = Position { 
        top = "4px", left = "1px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = lblDivide2, side = Position.Sides.Right }
        }
      },
      number = true,
      style = {
        defaultWidth = 36
      },
      value = y
    }
  
    local butSave = Button {
      position = Position {
        right = "10px", bottom = "5px"
      },
      text = "Save",
      auto = true
    }
    function butSave:onAction()
      local ID = anniversary.ID or 1
      if not anniversary.ID then
        while var.recall("anniversary.n" .. ID) do
          ID = ID + 1
        end
      end
      
      local varName = "anniversary.n" .. ID
      local data = {}
      data[1] = concatDate(txtMonth.value, txtDay.value, txtYear.value)
      data[2] = txtTitle.value
      
      var.store(varName, data)
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
      calendarView:refresh()
    end
    
    local butCancel = Button {
      position = Position {
        right = "5px", bottom = "5px", alignment = {
          { ref = butSave, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
  
    dialog:addChildren(txtTitle, lblTitle, txtMonth, lblDate, lblDivide1, txtDay, lblDivide2, txtYear, butSave, butCancel)
    dialog.defaultFocus = 1
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  -----------------------
  -- New/Edit Holy Day --
  -----------------------
  local function showHolyDayDialog(holyDay)
    local position  = Position { top = "15%", left = "15%" }
    local dimension = Dimension("213px", "112px")
    local holyDay   = holyDay or {}
    local title     = (holyDay.ID and "Edit Holy Day") or "New Holy Day"
    local dialog    = Dialog(title, position, dimension)
    local date      = holyDay.Date or settingsManager:getLastDate()
    local m, d, y   = splitDate(date)
  
    local txtTitle = Input {
      position = Position {
        top = "30px", left = "48px"
      },
      style = {
        defaultWidth = 154
      },
      value = holyDay.Title or ""
    }
    
    local lblTitle = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Top },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      text = "Title: "
    }
  
    local drpRank = Dropdown {
      position = Position { 
        top = "5px", left = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      items = { "Optional Memorial", "Memorial", "Feast", "Solemnity", "Solemnity ★" },
      value = holyDay.Rank,
      style = {
        defaultWidth = 155
      }
    }
  
    local lblRank = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = drpRank, side = Position.Sides.Top },
          { ref = drpRank, side = Position.Sides.Left }
        }
      },
      text = "Rank: "
    }
  
    local txtMonth = Input {
      position = Position { 
        top = "4px", left = "0px", alignment = {
          { ref = drpRank, side = Position.Sides.Bottom },
          { ref = drpRank, side = Position.Sides.Left }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = m
    }
    
    local lblDate = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Left }
        }
      },
      text = "Date: "
    }
  
    lblDivide = Label {
      position = Position { 
        top = "0px", left = "1px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Right }
        }
      },
      text = "/"
    }
  
    local txtDay = Input {
      position = Position { 
        top = "4px", left = "1px", alignment = {
          { ref = drpRank, side = Position.Sides.Bottom },
          { ref = lblDivide, side = Position.Sides.Right }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = d
    }
  
    local butSave = Button {
      position = Position {
        right = "10px", bottom = "5px"
      },
      text = "Save",
      auto = true
    }
    function butSave:onAction()
      local ID = holyDay.ID or 1
      if not holyDay.ID then
        while var.recall("holyday.n" .. ID) do
          ID = ID + 1
        end
      end
      
      local varName = "holyday.n" .. ID
      local data = {}
      data[1] = concatDate(txtMonth.value, txtDay.value)
      data[2] = txtTitle.value
      data[3] = drpRank.value
      
      var.store(varName, data)
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
      calendarView:refresh()
    end
    
    local butCancel = Button {
      position = Position {
        right = "5px", bottom = "5px", alignment = {
          { ref = butSave, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
  
    dialog:addChildren(txtTitle, lblTitle, drpRank, lblRank, txtMonth, lblDate, lblDivide, txtDay, butSave, butCancel)
    dialog.defaultFocus = 1
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  ----------------------
  -- New/Edit Holiday --
  ----------------------
  local function showHolidayDialog(holiday)
    local position  = Position { top = "15%", left = "15%" }
    local dimension = Dimension("213px", "112px")
    local holiday   = holiday or {}
    local title     = (holiday.ID and "Edit Holiday") or "New Holiday"
    local dialog    = Dialog(title, position, dimension)
    local date      = holiday.Date or settingsManager:getLastDate()
    local m, d, y   = splitDate(date)
  
    local txtTitle = Input {
      position = Position {
        top = "30px", left = "48px"
      },
      style = {
        defaultWidth = 154
      },
      value = holiday.Title or ""
    }
    
    local lblTitle = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Top },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      text = "Title: "
    }
  
    local txtMonth = Input {
      position = Position { 
        top = "4px", left = "0px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = txtTitle, side = Position.Sides.Left }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = m
    }
    
    local lblDate = Label {
      position = Position { 
        top = "0px", right = "0px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Left }
        }
      },
      text = "Date: "
    }
  
    lblDivide = Label {
      position = Position { 
        top = "0px", left = "1px", alignment = {
          { ref = txtMonth, side = Position.Sides.Top },
          { ref = txtMonth, side = Position.Sides.Right }
        }
      },
      text = "/"
    }
  
    local txtDay = Input {
      position = Position { 
        top = "4px", left = "1px", alignment = {
          { ref = txtTitle, side = Position.Sides.Bottom },
          { ref = lblDivide, side = Position.Sides.Right }
        }
      },
      number = true,
      style = {
        defaultWidth = 18
      },
      value = d
    }
  
    local butSave = Button {
      position = Position {
        right = "10px", bottom = "5px"
      },
      text = "Save",
      auto = true
    }
    function butSave:onAction()
      local ID = holiday.ID or 1
      if not holiday.ID then
        while var.recall("holiday.n" .. ID) do
          ID = ID + 1
        end
      end
      
      local varName = "holiday.n" .. ID
      local data = {}
      data[1] = concatDate(txtMonth.value, txtDay.value)
      data[2] = txtTitle.value
      
      var.store(varName, data)
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
      calendarView:refresh()
    end
    
    local butCancel = Button {
      position = Position {
        right = "5px", bottom = "5px", alignment = {
          { ref = butSave, side = Position.Sides.Left }
        }
      },
      text = "Cancel",
      auto = true
    }
    function butCancel:onAction()
      gtk.RootScreen:popScreen()
      gtk.RootScreen:invalidate()
    end
  
    dialog:addChildren(txtTitle, lblTitle, txtMonth, lblDate, lblDivide, txtDay, butSave, butCancel)
    dialog.defaultFocus = 1
    gtk.RootScreen:pushScreen(dialog)
    gtk.RootScreen:invalidate()
  end
  
  --------------------------
  -- New/Edit Appointment --
  --------------------------
  local function showAppointmentDialog(appointment)
    -- This dialog is called from 
    -- showAppointmentDialog, when creating or
    -- editing a repeating event.
    local function showRepeatDialog(event)
      local event = event or {}
      local title = (event.ID and "Edit") or "New"
      title = title .. " Repeating Event Setup"
      local position = Position { top = "0px", left = "10%" }
      local dimension = Dimension("80%", "99%")
      local dialog = Dialog(title, position, dimension)
      local endDate = event.EndDate
      local repInfo = event.RepInfo
      local repType = "Standard"
      
      local function hideCustom()
        local children = dialog.children
        for x = 14, #children - 2 do
          local child = children[x]
          child:disable()
          child.visible = false
        end
        dialog.dimension = Dimension("80%", "50%")
        dialog.position = Position { top = "30px", left = "10%" }
        for x = 1, #children do
          local child = children[x]
          child.position:invalidate()
        end
        children[5].readOnly = false
        gtk.RootScreen:invalidate()
      end
      
      local function showCustom()
        local children = dialog.children
        children[5].readOnly = true
        children[5].value = "Month(s)"
        for x = 14, #children - 2 do
          local child = children[x]
          child:enable()
          child.visible = true
        end
        for x = 1, #children do
          local child = children[x]
          child.position:invalidate()
        end
    
        dialog.dimension = Dimension("80%", "99%")
        dialog.position = Position { top = "0px", left = "10%" }
        gtk.RootScreen:invalidate()
      end
      
      local num = 1
      local interval = "Week(s)"
         
      local lblType = Label {
        position = Position {
          top = "30px", left = "5px"
        },
        text = "Repeat Type: "
      }
      
      local drpType = Dropdown {
        position = Position {
          top = "0px", left = "4px", alignment = {
            { ref = lblType, side = Position.Sides.Top },
            { ref = lblType, side = Position.Sides.Right }
          }
        },
        value = repType,
        items = { "Standard", "Custom" },
        style = {
          defaultWidth = 100
        }
      }
      
      local lblEvery = Label {
        position = Position {
          top = "5px", left = "0px", alignment = {
            { ref = lblType, side = Position.Sides.Bottom },
            { ref = lblType, side = Position.Sides.Left }
          }
        },
        text = "Repeat every: "
      }  
    
      local txtNum = Input {
        position = Position {
          top = "0px", left = "0px", alignment = {
            { ref = lblEvery, side = Position.Sides.Top },
            { ref = lblEvery, side = Position.Sides.Right }
          }
        },
        value = num,
        number = true,
        style = {
          defaultWidth = 18
        }
      }
    
      local drpInterval = Dropdown {
        position = Position {
          top = "0px", left = "3px", alignment = {
            { ref = txtNum, side = Position.Sides.Top },
            { ref = txtNum, side = Position.Sides.Right }
          }
        },
        value = interval,
        items = { "Day(s)", "Week(s)", "Month(s)", "Year(s)" },
        style = {
          defaultWidth = 80
        }
      }
      
      local chkEndDate = Checkbox {
        position = Position {
          top = "8px", left = "0px", alignment = {
            { ref = lblEvery, side = Position.Sides.Bottom },
            { ref = lblEvery, side = Position.Sides.Left }
          }
        },
        value = event.EndDate,
      }
      
      local lblEnds = Label {
        position = Position {
          top = "-3px", left = "5px", alignment = {
            { ref = chkEndDate, side = Position.Sides.Top },
            { ref = chkEndDate, side = Position.Sides.Right }
          }
        },
        text = "Ends on: "
      }  
      
      dialog:addChildren(lblType, drpType, lblEvery, txtNum, drpInterval, chkEndDate, lblEnds)
      
      local dateGroup = DateGroup(
        Position {
          top = "4px", left = "0px", alignment = {
            { ref = txtNum, side = Position.Sides.Bottom },
            { ref = txtNum, side = Position.Sides.Left }
          }
        },
        dialog,
        endDate or event.Date
      )
    
      local week = {}
      local weekLabels = {}
      local weekText = {"First:", "Second:", "Third:", "Fourth:", "Fifth:", "Sixth:" }
      for w = 1, 6 do
        week[w] = {}
        weekLabels[w] = Label {
          position = Position {
            top = 102 + 15 * w .. "px", left = "40px"
          },
          text = weekText[w],
          style = {
            font = {
              size = 9,
              style = "b"
            }
          }
        }
        dialog:addChild(weekLabels[w])    
    
        for d = 1, 7 do
          if w == 6 and d > 2 then
            break
          end
          week[w][d] = Checkbox {
            position = Position {
              top = 103 + 15 * w .. "px", left = 75 + 15 * d .. "px" 
            }
          }
          dialog:addChild(week[w][d])
        end
      end
    
      local lblDays = Label {
        position = Position {
          top = "6px", left = "13px", alignment = {
            { ref = lblEnds, side = Position.Sides.Bottom },
            { ref = lblEnds, side = Position.Sides.Right }
          }
        },
        style = {
          font = {
            size = 9,
            style = "b"
          }
        },
        text = " S  M  T  W  T   F   S"
      }
    
      local butSave = Button {
        position = Position {
          bottom = "35px", right = "5px"
        },
        text = "Save"
      }
      
      local butCancel = Button {
        position = Position {
          bottom = "5px", right = "5px"
        },
        text = "Cancel",
        style = {
            font = {
                size = 9,
              },
            }
          }
          
          local butClearAll = Button {
            position = Position {
              top = "0px", right = "3px", alignment = {
                { ref = weekLabels[1], side = Position.Sides.Top },
                { ref = weekLabels[1], side = Position.Sides.Left }
              }
            },
            text = "▫ All",
            style = {
              font = {
                size = 8,
                style = "b"
              },
              defaultWidth = 34,
              defaultHeight = 18
            }
          }
          
          local butCheckAll = Button {
            position = Position {
              top = "5px", left = "0px", alignment = {
                { ref = butClearAll, side = Position.Sides.Bottom },
                { ref = butClearAll, side = Position.Sides.Left }
              }
            },
            text = "✓ All",
            style = {
              font = {
                size = 8,
                style = "b"
              },
              defaultWidth = 34,
              defaultHeight = 18
            }
          }
        
          dialog:addChildren(lblDays, butClearAll, butCheckAll, butSave, butCancel)
      
          dialog.defaultFocus = 2
          gtk.RootScreen:pushScreen(dialog)
        
          if repInfo and repInfo ~= "" then
            txtNum:setValue(tonumber(repInfo:match("%d+")))
            interval = repInfo:match("%a", 2)
            repType = repInfo:find("S")
            if interval == "D" then
              interval = "Day(s)"
            elseif interval == "W" then
              interval = "Week(s)"
            elseif interval == "M" then
              interval = "Month(s)"
            else 
              interval = "Year(s)"
            end
            
            if repType then
              repType = "Standard"
              drpType.value = repType
            else
              repType = "Custom"
              drpType.value = repType
              interval = "Month(s)"
              local days = repInfo:find("%a",2)
              days = repInfo:sub(days + 1)
              for day in string.gmatch(days, "%d+") do
                local w = tonumber(day:sub(1, 1))
                local d = tonumber(day:sub(2, 2))
                week[w][d].value = true
              end
            end
        
            drpInterval.value = interval
          end
          
          if not event.EndDate then
            dateGroup:disable()
          end
              
          function drpType:onAction(value)
            repType = value
            if repType == "Standard" then
              hideCustom()
            else
              showCustom()
            end
          end
          
          function chkEndDate:onAction()
            if self.value then
              dateGroup:enable()
            else 
              dateGroup:disable()
            end
            self.parent:invalidate()
          end
          
          function butCheckAll:onAction()
            for w = 1, 6 do
              for d = 1, #week[w] do
                week[w][d].value = true
              end
            end
          end
          
          function butClearAll:onAction()
            for w = 1, 6 do
              for d = 1, #week[w] do
                week[w][d].value = false
              end
            end
          end
          dialog:invalidate()
          
          function butCancel:onAction()
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
          
          function butSave:onAction()
            local repInfo = string.sub(drpType.value, 1, 1)
            repInfo = repInfo .. txtNum.value
            repInfo = repInfo .. string.sub(drpInterval.value, 1, 1)
            
            if drpType.value == "Custom" then
              for w = 1, 6 do
                for d = 1, #week[w] do
                  if week[w][d].value then
                    repInfo = repInfo .. w .. d .. ";"
                  end
                end
              end
            end
            
            event.RepInfo = repInfo
            if chkEndDate.value then
              event.EndDate = dateGroup:getValue()
            else
              event.EndDate = false
            end
            
            calendarData:saveEvent(event)
            
            gtk.RootScreen:popScreen()
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
      
          if repType == "Standard" then
            hideCustom()
          end
      
          gtk.RootScreen:invalidate()
          
        end
        
        ------------------------------------
        -- The main showAppointmentDialog --
        ------------------------------------
        local appointment = appointment or {}
        local title       = (appointment.ID and "Edit Appointment" or "New Appointment") .. " - " .. (appointment.Date or "unknown date")
        local position    = Position { top = "5px", left = "2px" }
        local dimension   = Dimension("311px", "198px")
        local dialog      = ScrollingDialog(title, position, dimension, 190)
        local showIcon    = appointment.ShowIcon
        
        if showIcon == true then
          showIcon = "True"
        elseif type(showIcon) == "string" then
          if showIcon == "HolyDay" then
            showIcon = "Holy Day"
          elseif showIcon == "Holiday" then
            showIcon = "Holiday"
          else
            showIcon = "True"
          end
        else
          showIcon = "False"
        end
        
        local butDate = Button {
          position = Position {
            top = "2px", right = "2px"
          },
          pic = calendarIcon,
          style = {
            defaultWidth = 20,
            defaultHeight = 20,
            textColor = { 100, 0, 0 },
            font = {
              size = 9,
              style = "b"
            }
          }
        }
        butDate.protected = true
        function butDate:onAction()
          local function setDate(date)
            appointment.Date = date
            title = (appointment.ID and "Edit Appointment" or "New Appointment") .. " - " .. appointment.Date
            dialog.title = title
            dialog:invalidate()
          end
          local dateView = SelectDate("Appointment Date", appointment.Date or "01/15/2022", setDate)
          gtk.RootScreen:pushScreen(dateView)
          gtk.RootScreen:invalidate()
        end
        
        local txtTitle = Input {
          position = Position {
            top = "5px", left = "52px"
          },
          value = appointment.Title or "",
          style = {
            defaultWidth = 231
          }
        }
      
        local lblTitle = Label {
          position = Position {
            top = "0px", right = "0px", alignment = {
              { ref = txtTitle, side = Position.Sides.Top },
              { ref = txtTitle, side = Position.Sides.Left }
            }
          },
          text = "Title: "
        }
      
        local drpPriority = Dropdown {
          position = Position {
            top = "5px", left = "0px", alignment = {
              { ref = txtTitle, side = Position.Sides.Bottom },
              { ref = txtTitle, side = Position.Sides.Left }
            }
          },
          items = {"Normal", "Low", "High" },
          value = appointment.Priority,
          style = {
            defaultWidth = 72
          }
        }
      
        local lblPriority = Label {
          position = Position {
            top = "0px", right = "0px", alignment = {
              { ref = drpPriority, side = Position.Sides.Top },
              { ref = drpPriority, side = Position.Sides.Left }
            }
          },
          text = "Priority: "
        }
      
          local drpCategory = Dropdown {
          position = Position {
            top = "5px", right = "-1px", alignment = {
              { ref = txtTitle, side = Position.Sides.Bottom },
              { ref = txtTitle, side = Position.Sides.Right }
            }
          },
          items = settingsManager.eventCategories,
          value = appointment.Category,
          style = {
            defaultWidth = 90
          }
        }
      
        local lblCategory = Label {
          position = Position {
            top = "0px", right = "0px", alignment = {
              { ref = drpCategory, side = Position.Sides.Top },
              { ref = drpCategory, side = Position.Sides.Left }
            }
          },
          text = "Category: "
        }
      
        local chkAllDay = Checkbox {
          position = Position {
            top = "5px", left = "0px", alignment = {
              { ref = drpPriority, side = Position.Sides.Bottom },
              { ref = drpPriority, side = Position.Sides.Left }
            }
          },
          text = "All-Day Event",
          value = not appointment.Start
        }
      
        local lblStart = Label {
          position = Position {
            top =   "24px", right = "0px", alignment = {
              { ref = lblPriority, side = Position.Sides.Bottom },
              { ref = lblPriority, side = Position.Sides.Right }
            }
          },
          text = "Starts: "
        }
      
        local lblEnd = Label {
          position = Position {
            top =   "24px", left = "95px", alignment = {
              { ref = lblPriority, side = Position.Sides.Bottom },
              { ref = lblPriority, side = Position.Sides.Right }
            }
          },
          text = " Ends: "
        }
        
        dialog:addChildren(butDate, txtTitle, lblTitle, drpPriority, lblPriority, drpCategory, lblCategory, chkAllDay, lblStart, lblEnd)
      
        local startTime = TimeGroup(
          Position {    
            top = "5px", left = "0px", alignment = {
              {ref = chkAllDay, side = Position.Sides.Bottom },
              {ref = chkAllDay, side = Position.Sides.Left }
            }
          },
          dialog,
          appointment.Start or "8:00 AM"
        )
      
        local endTime = TimeGroup(
          Position {    
            top = "5px", left = "-5px", alignment = {
              {ref = chkAllDay, side = Position.Sides.Bottom },
              {ref = drpCategory, side = Position.Sides.Left }
            }
          },
          dialog,
          appointment.End or "9:00 AM"
        )
      
        function chkAllDay:onAction()
          if self.value then
            startTime:disable()
            endTime:disable()
          else
            startTime:enable()
            endTime:enable()
          end
        end
        chkAllDay:onAction()  -- Sets initial conditions
        
        local lblNotes = Label {
          position = Position {
            top =   "6px", right = "0px", alignment = {
              { ref = lblStart, side = Position.Sides.Bottom },
              { ref = lblStart, side = Position.Sides.Right }
            }
          },
          text = "Notes: "
        }
      
        local edtNotes = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblNotes, side = Position.Sides.Top },
              { ref = lblNotes, side = Position.Sides.Right }
            }
          },
          value = appointment.Notes or "",
          style = {
            defaultWidth = 231
          }
        }
        
        local drpShowIcon = Dropdown {
          position = Position {
            top = "5px", left = "0px", alignment = {
              { ref = edtNotes, side = Position.Sides.Bottom},
              { ref = edtNotes, side = Position.Sides.Left}
            }
          },
          items = { "True", "False", "Holiday", "Holy Day" },
          value = showIcon or "False",
          style = {
            defaultWidth = 105
          }
        }
          
        local lblShowIcon = Label {
          position = Position {
            top =   "0px", right = "0px", alignment = {
              { ref = drpShowIcon, side = Position.Sides.Top },
              { ref = drpShowIcon, side = Position.Sides.Left }
            }
          },
          text = "Icon: "
        }
        
        local chkRepeat = Checkbox {
          position = Position {
            top =   "3px", left = "20px", alignment = {
              { ref = drpShowIcon, side = Position.Sides.Top },
              { ref = drpShowIcon, side = Position.Sides.Right }
            }
          },
          text = "Event Repeats",
          value = appointment.RepInfo
        }
        function chkRepeat:onAction()
          if self.value then
            dialog.OK.text = "Continue"
          else
            dialog.OK.text = "Save"
          end
        end
        
        function dialog.OK:onAction()    
          appointment.Title = txtTitle.value
          if appointment.Title == "" then
            local warn = MessageBox("ERROR", "Appointment must have a title!")
            dialog:giveFocusToChildAtIndex(5)
            gtk.RootScreen:pushScreen(warn)
            gtk.RootScreen:invalidate()
            return 
          end
          if not appointment.Date or appointment.Date == "" then
            local warn = MessageBox("ERROR", "Appointment must have a date!")
            dialog:giveFocusToChildAtIndex(4)
            gtk.RootScreen:pushScreen(warn)
            gtk.RootScreen:invalidate()
            return 
          end
      
          if chkAllDay.value then
            appointment.Start = false
            appointment.End = false
          else
            appointment.Start = startTime:getValue()
            appointment.End   = endTime:getValue()
          end
      
          appointment.Category = drpCategory.value
          appointment.Priority = drpPriority.value
          appointment.Notes = edtNotes.value
          appointment.ShowIcon = drpShowIcon.value
          
          if chkRepeat.value then
            if appointment.Type == "Appointment" then
              appointment.ID = nil
            end
            appointment.Type = "Repeating"
            showRepeatDialog(appointment)
          else
            if appointment.Type == "Repeating" then
              appointment.ID = nil
            end
            appointment.Type = "Appointment"
            calendarData:saveEvent(appointment)
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
        end
        
        function dialog.Cancel:onAction()
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
        end
        
        dialog:addChildren(lblNotes, edtNotes, drpShowIcon, lblShowIcon, chkRepeat)
        dialog.defaultFocus = 5
        dialog.OK.text = "Save"
        chkRepeat:onAction()
        
        gtk.RootScreen:pushScreen(dialog)
        gtk.RootScreen:invalidate()
      end
      
      ------------------------------
      -- Show Event Detail Dialog --
      ------------------------------
      local function showDetailDialog(event)
        local colors  = {}
        colors.Other  = { 100, 0, 0 }
        colors.High   = { 200, 0, 0 }
        colors.Normal = { 0, 0, 150 }
        colors.Low    = { 255, 80, 200 }
          
        local eventDetail = ScrollingView {
          position = Position {
            top = "66px", left = "59px" 
          },
          dimension = Dimension("200px", "80px"),
          maxFrameHeight = 145
        }
        
        function eventDetail:draw(gc, x, y, width, height)
          gc:setColorRGB(200, 200, 255)
          gc:fillRect(x + 1, y + 1, width - 1, height - 1)
          ScrollingView.draw(self, gc, x, y, width, height)
        end
      
        local edtTitle = Editor {
          position = Position {
            top = "0px", left = "18px"
          },
          readOnly = true,
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = { 100, 0, 0 },
            focusColor = { 255, 250, 250},
            borderColor = {255, 255, 255},
            defaultWidth = 158,
            defaultHeight = 15
          },
          value = event.Title
        }
        
        local lblType = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = edtTitle, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              style = "b"
            }
          },
          text = "Type: "
        }
      
        local eventType = event.Type
        local priorityText = "Priority: "
        if eventType == "HolyDay" then
          eventType = "Holy Day"
          priorityText = "Rank: "
        elseif eventType == "DueDate" then
          eventType = "Project with Due Date"
        end
        local lblTypeText = Label {
          position = Position {
            top = "0px", left = "20px", alignment = {
              { ref = lblType, side = Position.Sides.Top },
              { ref = lblType, side = Position.Sides.Right }
            }
          },
          text = eventType,
          style = {
            font = {
              size = 8,
              --style = "b"
            },
            textColor = { 0, 0, 100 }
          },
        }  
      
        local lblPriority = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = lblType, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              style = "b"
            }
          },
          text = priorityText
        }
        
        local priorityTextColor = colors[event.Priority or "Other"]
        local lblPriorityText = Label {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblPriority, side = Position.Sides.Top },
              { ref = lblTypeText, side = Position.Sides.Left }
            }
          },
          text = (event.Priority or event.Rank) or "N/A",
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = priorityTextColor
          },
        }  
      
        local lblCategory = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = lblPriority, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              style = "b"
            }
          },
          text = "Category: "
        }
        
        local lblCategoryText = Label {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblCategory, side = Position.Sides.Top },
              { ref = lblTypeText, side = Position.Sides.Left }
            }
          },
          text = event.Category or "N/A",
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = {0, 0, 100}
          },
        }  
      
        local times = event.Start and event.End
        if times then
          times = event.Start .. " to " .. event.End
        else
          times = "All Day"
        end
      
        local lblTime = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = lblCategory, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              style = "b"
            }
          },
          text = "Time: "
        }
        
        local lblTimeText = Label {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblTime, side = Position.Sides.Top },
              { ref = lblTypeText, side = Position.Sides.Left }
            }
          },
          text = times,
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = {0, 0, 100}
          },
        }  
        
        local notes = event.Notes or "N/A"
        
        local lblNotes = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = lblTime, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              style = "b"
            }
          },
          text = "Notes:"
        }
        
        local edtNotes = Editor {
          position = Position {
            top = "-2px", left = "3px", alignment = {
              { ref = lblNotes, side = Position.Sides.Bottom }
            }
          },
          style = {
            font = {
              size = 8,
              --style = "b"
            },
            defaultWidth = 170,
            defaultHeight = 35
          },
          readOnly = true,
          value = event.Notes or "N/A"
        }
        
        local butClose = Button {
          position = Position {
            top = "4px", right = "3px", alignment = {
              { ref = edtNotes, side = Position.Sides.Bottom }
            }
          },
          text = "Close",
          auto = true,
          style = {
            defaultHeight = 20
          }
        }
           
        local butEdit = Button {
          position = Position {
            top = "0px", right = "3px", alignment = {
              {ref = butClose, side = Position.Sides.Top },
              {ref = butClose, side = Position.Sides.Left }
            }
          },
          text = "Edit",
          auto = true,
          style = {
            defaultHeight = 20
          }
        }
        
        local butDelete = Button {
          position = Position {
            top = "0px", right = "3px", alignment = {
              {ref = butEdit, side = Position.Sides.Top },
              {ref = butEdit, side = Position.Sides.Left }
            }
          },
          text = "Delete",
          auto = true,
          style = {
            defaultHeight = 20
          }
        }
            
        eventDetail:addChildren(edtTitle, lblType, lblTypeText, lblPriority, lblPriorityText, lblCategory, lblCategoryText, lblTime, lblTimeText, lblNotes, edtNotes, butClose, butEdit, butDelete)
        
        gtk.RootScreen:pushScreen(eventDetail)
        gtk.RootScreen:invalidate()
        
        -- Widget actions:
        function edtTitle:draw(gc, x, y, width, height)
          Editor.draw(self, gc, x, y, width, height)
          
          local icon = eventIcons[event.Type]
          gc:drawImage(icon, x - 13, y + 2)
        end
        
        function butClose:onAction()
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
        end
        
        function butEdit:onAction()
          local date = plannerView.date
          local function editEvent(sel)
            if sel == 1 then
              event.SkipDates = event.SkipDates .. ";" .. date
              calendarData:saveEvent(event)
              local appointment = deepcopy(event)
              appointment.Type = "Appointment"
              appointment.EndDate = nil
              appointment.SkipDates = nil
              appointment.RepInfo = nil
              appointment.Date = date
              appointment.ID = calendarData:getNewID(appointment)
              calendarData:saveEvent(appointment)
              showAppointmentDialog(appointment)
            elseif sel == 2 then
              local new = deepcopy(event)
              event.EndDate = subtractDays(date, 1)
              calendarData:saveEvent(event)
              new.ID = calendarData:getNewID(new)
              new.Date = date
              showAppointmentDialog(new)
            else
              showAppointmentDialog(event)
            end
          end
          gtk.RootScreen:popScreen()
          if event.Type == "Appointment" then
            showAppointmentDialog(event)
          elseif event.Type == "HolyDay" then
            showHolyDayDialog(event)
          elseif event.Type == "Holiday" then
            showHolidayDialog(event)
          elseif event.Type == "Anniversary" then
            showAnniversaryDialog(event)
          elseif event.Type == "Repeating" then
            local options = {"Only this occurrence", "This and future occurrences", "All occurrences"}
            local dialog = ListBox("Edit Repeating Event", options, editEvent)
            gtk.RootScreen:pushScreen(dialog)
            gtk.RootScreen:invalidate()
          elseif event.Type == "DueDate" then
            gtk.RootScreen:pushScreen(projectManager)
            projectManager:showProjectDialog(event)
          end
        end
        
        function butDelete:onAction()
          local date = plannerView.date
          local function deleteEntry(event)
            local function deleteRepeatingEvent(sel)
              if sel == 1 then
                event.SkipDates = event.SkipDates .. ";" .. date
                calendarData:saveEvent(event)
              elseif sel == 2 then
                event.EndDate = subtractDays(date, 1)
                calendarData:saveEvent(event)
              else
                calendarData:deleteEvent(event)
              end
            end
                  
            if event.Type == "Repeating" then
              local options = {"Only this occurrence", "This and future occurrences", "All occurrences"}
              local dialog = ListBox("Delete Repeating Event", options, deleteRepeatingEvent)
              gtk.RootScreen:pushScreen(dialog)
              gtk.RootScreen:invalidate()
            elseif event.Type == "DueDate" then
              local warn = MessageBox("Information", "Project " .. event.Title .. " cannot be deleted from the Agenda.")
              gtk.RootScreen:pushScreen(warn)
              gtk.RootScreen:invalidate()
            else
              calendarData:deleteEvent(event)
            end
          end
          
          gtk.RootScreen:popScreen()
          local dialog = ConfirmationBox("Delete " .. event.Type .. "?", "Are you sure you want to delete: " .. event.Title, deleteEntry, event)
          gtk.RootScreen:pushScreen(dialog)
          gtk.RootScreen:invalidate()
        end
      end
      
      ---------------------------------
      -- Agenda View/Dialog          --
      --   (Written as a function    --
      -- to make it easier to call.) --
      ---------------------------------
      local function showAgenda(date)
        local m, d, y   = splitDate(date)
        local title     = "Agenda for " .. date2Text(m, d, y)
        local position  = Position { top = "5px", left = "5px" }
        local dimension = Dimension(306, 200)
        local dialog    = Dialog(title, position, dimension)
        local data      = calendarData:getData(m, d, y) or {}
        local eventList = calendarData:getEventList(data, true) or {}
        local itemLines = {}
      
        for x = 1, #eventList do
          itemLines[x] = eventList[x].text
        end
          
        local lstAgenda = List {
          position = Position {
            top = "30px", left = "3px"
          },
          style = {
            defaultWidth = 300,
            defaultHeight = 120,
            lineHeight = 20,
            font = {
              size = 8
            }
          },
          items = itemLines
        }
        
        function lstAgenda:arrowRight()
          local date = addDays(date, 1)
          gtk.RootScreen:popScreen()
          return showAgenda(date)
        end
        
        function lstAgenda:arrowLeft()
          local date = subtractDays(date, 1)
          gtk.RootScreen:popScreen()
          return showAgenda(date)
        end
        
        function lstAgenda:onAction()
          local sel = self.selected
          local event = eventList[sel]
      
          local function editEvent(sel)
            if sel == 1 then
              event.SkipDates = event.SkipDates .. ";" .. date
              calendarData:saveEvent(event)
              local appointment = deepcopy(event)
              appointment.Type = "Appointment"
              appointment.EndDate = nil
              appointment.SkipDates = nil
              appointment.RepInfo = nil
              appointment.Date = date
              appointment.ID = calendarData:getNewID(appointment)
              calendarData:saveEvent(appointment)
              showAppointmentDialog(appointment)
            elseif sel == 2 then
              local new = deepcopy(event)
              event.EndDate = subtractDays(date, 1)
              calendarData:saveEvent(event)
              new.ID = calendarData:getNewID(new)
              new.Date = date
              showAppointmentDialog(new)
            else
              showAppointmentDialog(event)
            end
          end
          gtk.RootScreen:popScreen()
          if event.Type == "Appointment" then
            showAppointmentDialog(event)
          elseif event.Type == "HolyDay" then
            showHolyDayDialog(event)
          elseif event.Type == "Holiday" then
            showHolidayDialog(event)
          elseif event.Type == "Anniversary" then
            showAnniversaryDialog(event)
          elseif event.Type == "Repeating" then
            local options = {"Only this occurrence", "This and future occurrences", "All occurrences"}
            local dialog = ListBox("Edit Repeating Event", options, editEvent)
            gtk.RootScreen:pushScreen(dialog)
            gtk.RootScreen:invalidate()
          elseif event.Type == "DueDate" then
            gtk.RootScreen:pushScreen(projectManager)
            projectManager:showProjectDialog(event)
          end
        end
        
        function lstAgenda:backspaceKey()
          local sel = self.selected
          local event = eventList[sel]
          local function deleteEntry(event)
            local function deleteRepeatingEvent(sel)
              if sel == 1 then
                event.SkipDates = event.SkipDates .. ";" .. date
                calendarData:saveEvent(event)
              elseif sel == 2 then
                event.EndDate = subtractDays(date, 1)
                calendarData:saveEvent(event)
              else
                calendarData:deleteEvent(event)
              end
            end
                  
            if event.Type == "Repeating" then
              local options = {"Only this occurrence", "This and future occurrences", "All occurrences"}
              local dialog = ListBox("Delete Repeating Event", options, deleteRepeatingEvent)
              gtk.RootScreen:pushScreen(dialog)
              gtk.RootScreen:invalidate()
            elseif event.Type == "DueDate" then
              local warn = MessageBox("Information", "Project " .. event.Title .. " cannot be deleted from the Agenda.")
              gtk.RootScreen:pushScreen(warn)
              gtk.RootScreen:invalidate()
            else
              calendarData:deleteEvent(event)
            end
          end
          
          gtk.RootScreen:popScreen()
          local dialog = ConfirmationBox("Delete " .. event.Type .. "?", "Are you sure you want to delete: " .. event.Title, deleteEntry, event)
          gtk.RootScreen:pushScreen(dialog)
          gtk.RootScreen:invalidate()
        end
        
        function lstAgenda:draw(gc, x, y, width, height)
          local x = x
          local y = y
          local w = width
          local h = height
          
          local lh         = self.style.lineHeight
          local top        = self.top
          local sel        = self.selected
          local style      = self.style
          local items      = self.items            
          local numVisible = math.floor(h / lh)
          
          self.numVisible = numVisible
          
          if self.hasFocus then
            gc:setColorRGB(unpack(style.focusColor))
            gc:setPen("medium")
            gc:drawRect(x, y, w, h)
            gc:setPen()
          end
          
          gc:smartClipRect("subset", x, y, w + 1, h + 1)
      
          -- Background
          gc:setColorRGB(unpack(style.backgroundColor))
          gc:fillRect(x, y, w, h)
          
          -- Border
          gc:setColorRGB(unpack(style.borderColor))
          gc:drawRect(x, y, w, h)
          
          local font = self.style.font
          gc:setFont(font.serif, font.style, font.size)
        
          -- Lines
          local function wrap(text, event)
            local words = text:split(" ")
            local line1 = words[1]
            local line2 = "   "
            if event.Priority  then
              line1 = line1 .. "  "
            end
            local nextLine = false
            for x = 2, #words do
              local l = gc:getStringWidth(line1 .. words[x])
              if l <= w - 29 and not nextLine then
                line1 = line1 .. words[x] .. " " 
              else
                nextLine = true
                line2 = line2 .. words[x] .. " "
              end
            end
            return line1, line2
          end
          
          local label, item, event, time
          local colors  = {}
          colors.Other  = { 100, 0, 0 }
          colors.High   = { 200, 0, 0 }
          colors.Normal = { 0, 0, 150 }
          colors.Low    = { 255, 80, 200 }
            
          for i=1, math.min(#items - top, numVisible + 1) do
            item  = items[i + top]
            event = eventList[i + top]
            local line1, line2 = wrap(item, event)
            time  = line1:sub(1, 15)
            label = line1:sub(16)
            
            if (i + top)/2 == math.floor((i + top)/2) then
              gc:setColorRGB(225, 228, 252)
            else
              gc:setColorRGB(204, 212, 252)
            end
            gc:fillRect(x + 1, y + i * lh - lh + 1, w - 15, lh)
              
            if event.Priority then
              gc:setColorRGB(180, 180, 225)
              gc:fillRect(x + 1, y + i * lh - lh + 1, 87, lh)
              gc:setColorRGB(0, 0, 0)
              if i + top == sel then
                gc:setColorRGB(0, 0, 0)
                gc:fillRect(x + 1, y + i * lh - lh + 1, 87, lh)
                gc:drawRect(x + 88, y + i * lh - lh + 1, w - 15 - 87, lh - 1)
                gc:setColorRGB(unpack(style.selectedTextColor))
              end
              gc:drawString(time, x + 3, y + i * lh - lh, "top")
              gc:setColorRGB(unpack(colors[event.Priority]))
              gc:drawString(label, x + 85, y + i * lh - lh, "top")
              if #line2 > 0 then
                gc:drawString(line2, x + 85, y + i * lh - lh + 10, "top")
              end
            else
              if i + top == sel then
                gc:setColorRGB(0, 0, 0)
                gc:drawRect(x + 1, y + i * lh - lh + 1, w - 15, lh -1)
                gc:setColorRGB(unpack(colors.Other))
              else
                gc:setColorRGB(unpack(colors.Other))
              end
              gc:drawString(time .. label, x + 3, y + i * lh - lh, "top")
              if #line2 > 0 then
                gc:drawString(line2, x + 85, y + i * lh - lh + 10, "top")
              end
            end
      
          end
          gc:smartClipRect("restore")
          
          self.scrollBar:update(top, numVisible, #items)
          
          if eventList[sel] then
            local event = eventList[sel]
            local t = event.Type
            local icon = eventIcons[t]:copy(22, 22)
            if t == "Appointment" or t == "Repeating" then
              icon = event.ShowIcon
              if icon and type(icon) ~= "string" then
                icon = eventIcons[t]:copy(22, 22)
              elseif icon then
                icon = eventIcons[icon]:copy(22, 22)
              end
            end
            gc:setColorRGB(255, 255, 255)
            gc:fillRect(16, 172, 22, 22)
            if icon then
              gc:drawImage(icon, 16, 172)
            end
            gc:setColorRGB(0, 0, 0)
            gc:drawRect(16, 172, 22, 22)
            gc:setFont("sansserif", "r", 6)
            gc:drawString("Icon:", 15, 171)
          end
        end
          
        local edtNotes = Editor {
          position = Position {
            bottom = "4px", left = "50px"
          },
          readOnly = true,
          style = {
            defaultWidth = 150,
            defaultHeight = 29
          }
        }
        
        function lstAgenda:change(sel)
          local event = eventList[sel]
          
          edtNotes:setValue(event.Notes or "")
          
          platform.window:invalidate()
        end
      
        local lblNotes = Label {
          position = Position {
            bottom = "-1px", left = "0px", alignment = {
              { ref = edtNotes, side = Position.Sides.Top },
              { ref = edtNotes, side = Position.Sides.Left }
            }
          },
          text = "Notes:",
          style = {
            font = {
              size = 6
            }
          }
        }
        
        local lblNav = Label {
          position = Position {
            bottom = "-1px", right = "40px", alignment = {
              { ref = edtNotes, side = Position.Sides.Top },
            }
          },
          text = "Navigation:",
          style = {
            font = {
              size = 6
            }
          }
        }
        
        local butLeft = Button {
          position = Position {
            top = "0px", left = "0px", alignment = {
              {ref = edtNotes, side = Position.Sides.Top},
              {ref = lblNav, side = Position.Sides.Left}
            }
          },
          text = "◀",
          style = {
            defaultWidth = 22,
            defaultHeight = 22
          }
        }
        function butLeft:onAction()
          local date = subtractDays(date, 1)
          gtk.RootScreen:popScreen()
          return showAgenda(date)
        end
        
        local butRight = Button {
          position = Position {
            top = "0px", left = "3px", alignment = {
              {ref = butLeft, side = Position.Sides.Top},
              {ref = butLeft, side = Position.Sides.Right}
            }
          },
          text = " ▶",
          style = {
            defaultWidth = 22,
            defaultHeight = 22
          }
        }
      
        function butRight:onAction()
          local date = addDays(date, 1)
          gtk.RootScreen:popScreen()
          return showAgenda(date)
        end
          
        local butDate = Button {
          position = Position {
            top = "0px", left = "3px", alignment = {
              {ref = butRight, side = Position.Sides.Top},
              {ref = butRight, side = Position.Sides.Right}
            }
          },
          pic = calendarIcon,
          style = {
            defaultWidth = 22,
            defaultHeight = 22,
            textColor = { 100, 0, 0 },
            font = {
              size = 9,
              style = "b"
            }
          }
        }
      
        function butDate:onAction()
          local function setDate(date)
            gtk.RootScreen:popScreen()
            return showAgenda(date)
          end
          local dateView = SelectDate("Select Date", date, setDate)
          gtk.RootScreen:pushScreen(dateView)
          gtk.RootScreen:invalidate()
        end
        
        lstAgenda:change(1)
        
        dialog.defaultFocus = 1
        dialog:addChildren(lstAgenda, edtNotes, lblNotes, lblNav, butLeft, butRight, butDate)
        
        function dialog:onPopped()
          timer.start(.5)
        end
        
        gtk.RootScreen:pushScreen(dialog)
        gtk.RootScreen:invalidate()
        
      end
      
      ------------------
      -- Planner View --
      ------------------
      do
        local function timeToPixels(time)
          local hr, min, mer = splitTime(time)
          if hr == 12 and mer == "AM" then
            hr = 0
          elseif mer == "PM" and hr ~= 12 then
            hr = hr + 12 
          end
          return math.floor((hr * 60 + min)/3)
        end
      
        local lblDate = Label {
          position = Position {
            top = "0px", left = "2px"
          },
          center = true,
          text = "Sunday, November 31, 2022",
          style = {
            textColor = { 0, 0, 120 },
            defaultWidth = 314,
            font = {
              size = 14
            }
          }
        }
        
        local lblFilter = Label {
          position = Position {
            top = "0px", right = "2px", alignment = {
              { ref = lblDate, side = Position.Sides.Bottom }
            }
          },
          text = "Categories Hidden: 3",
          style = {
            textColor = { 120, 0, 0 },
            font = {
              size = 6
            }
          }
        }
        
        local lblAllDay = Label {
          position = Position {
            top = "0px", left = "2px", alignment = {
              { ref = lblDate, side = Position.Sides.Bottom }
            }
          },
          text = "All-Day Events",
          style = {
            textColor = { 0, 0, 120 },
            font = {
              size = 6
            }
          }
        }
        
        local lstAllDay = List {
          position = Position {
            top = "0px", left = "1px", alignment = {
              { ref = lblFilter, side = Position.Sides.Bottom }
            }
          },
          style = {
            borderColor = { 120, 0, 0 },
            defaultWidth = 315,
            defaultHeight = 30,
            lineHeight = 12,
            font = {
              size = 8
            }
          },
          items = {  }
        }
        
        local lblSchedule = Label {
          position = Position {
            top = "3px", left = "2px", alignment = {
              { ref = lstAllDay, side = Position.Sides.Bottom }
            }
          },
          text = "Schedule",
          style = {
            textColor = { 0, 0, 120 },
            font = {
              size = 6
            }
          }
        }
        
        local lstSchedule = List {
          position = Position {
            top = "-1px", left = "1px", alignment = {
              { ref = lblSchedule, side = Position.Sides.Bottom }
            }
          },
          style = {
            borderColor = { 120, 0, 0 },
            defaultWidth = 315,
            defaultHeight = 122,
            lineHeight = 10,
            font = {
              size = 8
            }
          },
          items = { }
        }
          
        plannerView.defaultFocus = 6
        plannerView:addChildren(lblDate, lblFilter, lblAllDay, lstAllDay, lblSchedule, lstSchedule)
        
        -- Widget actions:
        function lstAllDay:onBlur()
          self.selected = 0
          self.top = 0
        end
        
        function lstAllDay:onFocus()
          self.selected = 1
          self.top = 0
        end
        
        function lstSchedule:arrowRight()
          calendarView:arrowRight()
          plannerView.date = calendarView.date
          plannerView:refresh()
        end
        lstAllDay.arrowRight = lstSchedule.arrowRight
        
        function lstSchedule:arrowLeft()
          calendarView:arrowLeft()
          plannerView.date = calendarView.date
          plannerView:refresh()
        end
        lstAllDay.arrowLeft = lstSchedule.arrowLeft
      
        function lstAllDay:onAction()
          local sel = self.selected
          local data = self.parent.allDayData
          local event = data[sel]
          showDetailDialog(event)
        end
        
        function lstAllDay:draw(gc, x, y, width, height)
          local x = x
          local y = y
          local w = width
          local h = height
          
          local lh         = self.style.lineHeight
          local top        = self.top
          local sel        = self.selected
          local style      = self.style
          local items      = self.items            
          local numVisible = math.floor(h / lh)
          
          self.numVisible = numVisible
          
          if self.hasFocus then
            gc:setColorRGB(unpack(style.focusColor))
            gc:setPen("medium")
            gc:drawRect(x, y, w, h)
            gc:setPen()
          end
          
          gc:smartClipRect("subset", x, y, w + 1, h + 1)
      
          gc:setColorRGB(unpack(style.backgroundColor))
          gc:fillRect(x, y, w, h)
          
          gc:setColorRGB(unpack(style.borderColor))
          gc:drawRect(x, y, w, h)
          
          local font = self.style.font
          gc:setFont(font.serif, font.style, font.size)
        
          local label, item
          local data = self.parent.allDayData
          for i = 1, math.min(#items - top, numVisible + 1) do
            item    = items[i + top]
            label   = gc:textLimit(item, w - 30)
            local event = data[i + top]
            
            if i + top == sel then
              gc:setColorRGB(120, 0, 0)
              gc:fillRect(x + 1, y + i * lh - lh + 1, w - 15, lh)
              
            else
              gc:setColorRGB(unpack(style.textColor))
            end
            local icon = eventIcons[event.Type]
      
            gc:drawImage(icon, x + 3, y + 1 + i * lh - lh)
            gc:setFont(font.serif, font.style, font.size)
            
            local colors  = {} 
            colors.High   = { 200, 0, 0 }
            colors.Normal = { 0, 0, 150 }
            colors.Low    = { 200, 160, 200 }
            
            if event.Priority then
              gc:setColorRGB(unpack(colors[event.Priority]))
            else 
              gc:setColorRGB(0, 0, 100)
            end
            if sel == top + i then
              gc:setColorRGB(unpack(style.selectedTextColor))
            end
            gc:drawString(label, x + 17, y + i * lh - lh, "top")
          end
          gc:smartClipRect("restore")
          
          self.scrollBar:update(top, numVisible, #items)
        end
        
        function lstSchedule:onAction()
          local data = plannerView.timeIndex
          local times = gtk.tools.constants.times
          local time = times[self.selected]
          local events = data[time]
      
          if #events == 0 then
            return 
          elseif #events == 1 then
            showDetailDialog(events[1])
          elseif #events > 1 then
            local options = {}
            local function show(sel)
              showDetailDialog(events[sel])
            end
            for x = 1, #events do
              options[x] = events[x].Title
            end
            local dialog = ListBox("Select Event", options, show)
            gtk.RootScreen:pushScreen(dialog)
            gtk.RootScreen:invalidate()
          end
          
        end
          
        function lstSchedule:charIn(key)
          local sel = self.selected
          local times = gtk.tools.constants.times
          local data = self.parent.timeIndex
          local top = self.top
          local numVisible = self.numVisible
          
          if key == "+" then
            local appointment = {}
            appointment.Start = times[sel]
            appointment.End = times[sel + 2] or times[#times]
            appointment.Date = plannerView.date
            showAppointmentDialog(appointment)
          elseif key == "*" then
            for x = sel + 1, #times do
              local key = times[x]
              local eventTable = data[key]
              if #eventTable > 0 then
                self.selected = x
                if sel > top + numVisible then
                  top = sel - numVisible
                end
                self:invalidate()
                break
              end
            end
          elseif key == "/" then
            for x = sel - 1, 1, -1 do
              local key = times[x]
              local eventTable = data[key]
              if #eventTable > 0 then
                self.selected = x
                if sel < top + 1 then
                  top = sel + 1
                end
                self:invalidate()
                break
              end
            end
          end
          List.charIn(self, key)
        end
        
        function lstSchedule:draw(gc, x, y, width, height)
          local x = x
          local y = y
          local w = width
          local h = height
          
          local lh         = self.style.lineHeight
          local top        = self.top
          local sel        = self.selected
          local style      = self.style
          local items      = self.items            
          local numVisible = math.floor(h / lh)
          local timeIndex  = plannerView.timeIndex    
          local schedule   = plannerView.schedule
          local times      = gtk.tools.constants.times
          local pixelIndex = plannerView.pixelIndex
          
          self.numVisible = numVisible
          
          if self.hasFocus then
            gc:setColorRGB(unpack(style.focusColor))
            gc:setPen("medium")
            gc:drawRect(x, y, w, h)
            gc:setPen()
          end
          
          gc:smartClipRect("subset", x, y, w + 1, h + 1)
      
          -- Background:
          gc:setColorRGB(unpack(style.backgroundColor))
          gc:fillRect(x, y, w, h)
      
          local font = self.style.font
          gc:setFont(font.serif, font.style, font.size)
              
          for i = 1, math.min(#items - top, numVisible + 1) do
            if (i + top)/2 == math.floor((i + top)/2) then
              gc:setColorRGB(225, 228, 252)
            else
              gc:setColorRGB(204, 212, 252)
            end
            gc:fillRect(x + 1, y + i * lh - lh + 1, w - 15, lh)
            gc:setColorRGB(180, 180, 225)
            gc:fillRect(x + 1, y + i * lh - lh + 1, 48, lh)
            gc:setColorRGB(100, 0, 0)
            local time = times[i + top]
            gc:drawString(time, x + 3, y + i * lh - lh, "top")
          end
          
          local startTime = timeToPixels(times[top + 1])
          local endTime   = timeToPixels(times[top + math.min(#items - top, numVisible + 1)])
          local colors    = {}
          colors.High     = { 250, 150, 150 }
          colors.Normal   = { 150, 150, 255 }
          colors.Low      = { 255, 200, 255 }
          colors.Conflict = { 240, 240, 240 }
      
          for i = startTime, endTime do      
            if pixelIndex[i] then
              local color = pixelIndex[i]
              local conflict = string.find(color, "Conflict")
              if conflict then
                color = string.sub(color, 1, conflict - 1)
              end
              gc:setColorRGB(unpack(colors[color]))
              if conflict then
                gc:setPen("thin", "dotted")
                local off = 0
                if i/2 == math.floor(i/2) then
                  off = 2
                end
                gc:drawLine(x + 51 + off, y + (i - startTime) + 1, x + w - 15, y + (i - startTime) + 1)
              else 
                gc:setPen("thin")
                gc:drawLine(x + 51, y + (i - startTime) + 1, x + w - 15, y + (i - startTime) + 1)
              end
      
            end
          end
          
          gc:setPen()
          -- Text
          for i = 1, math.min(#items - top, numVisible + 1) do
            gc:setColorRGB(0, 0, 0)
            gc:drawString(items[i + top], x + 52, y + i * lh - lh, "top")
            if sel == i + top then
              gc:drawRect(x + 1, y + i * lh - lh + 1, w - 15, lh)
            end
          end
      
              
          -- Border
          gc:setColorRGB(unpack(style.borderColor))
          gc:drawRect(x, y, w, h)
          
          gc:smartClipRect("restore")
          
          self.scrollBar:update(top, numVisible, #items)
          
        end
      
        function plannerView:fillAllDayEvents()
          local data = self.data
          local allDayData = {}
          
          for index, events in pairs(data) do
            for x = 1, #events do
              local event = events[x]
              if not event.Start or event.Type == "DueDate" then
                table.insert(allDayData, event)
              end
            end
          end
          self.allDayData = allDayData
          
          local listItems = {}
          for x = 1, #allDayData do
            local event = allDayData[x]
            local line = ""
            if event.Type == "DueDate" then
              line = "Project Due: " .. event.Title .. "  Status: " .. projectManager:getPercentDone(event) .. "  (" .. event.Category .. ")"
            elseif event.Type == "HolyDay" then
              line = event.Title .. "  (" .. event.Rank .. ")"
            elseif event.Type ~= "Appointment" and event.Type ~= "Repeating" then
              line = event.Title .. "  (" .. event.Type .. ")"
            else
              line = event.Title .. "  (" .. event.Category .. ")"
            end
            if event.Type == "Repeating" then
              line = "®  " .. line
            end
            table.insert(listItems, line)
          end
          lstAllDay.items = listItems
          lstAllDay.selected = 0
          lstAllDay.top = 0
          lstAllDay:invalidate()
        end
        
        function plannerView:fillSchedule()
          local sortA      = gtk.tools.time.sortA
          local data       = self.data
          local schedule   = {}
          local times      = gtk.tools.constants.times
          local timeIndex  = deepcopy(times)
          local pixelIndex = {}
          
          timeIndex = Enum(timeIndex)
          for time, value in pairs(timeIndex) do
            timeIndex[time] = {}
          end
          
          for index, events in pairs(data) do
            for x = 1, #events do
              local event = events[x]
              if event.Start and event.Type ~= "DueDate" then
                table.insert(schedule, event)
              end
            end
          end
          
          schedule = sortA(schedule, "Start")
          self.schedule = schedule
      
          for x = 1, #schedule do
            local event    = schedule[x]
            local start    = event.Start
            local endTime  = event.End
            local priority = event.Priority
            
            -- Fill pixel index
            local pixStart = timeToPixels(start)      
            local pixEnd   = timeToPixels(endTime)
      
            for y = pixStart, pixEnd do
            
              if not pixelIndex[y] then
                pixelIndex[y] = priority
              else
                pixelIndex[y] = priority .. "Conflict"
              end
            end
          end
          self.pixelIndex = pixelIndex
        
          for x = 1, #schedule do
            local event    = schedule[x]
            local start    = event.Start
      
            -- Arrange events by time index
            if timeIndex[start] then
              table.insert(timeIndex[start], event)
            else
              for y = #times, 1, -1 do
                local time = times[y]
                if firstTime(time, start) then
                  table.insert(timeIndex[time], event)
                  break
                end
              end
            end
          end
          self.timeIndex = timeIndex
          
          local items = {}
          for x = 1, #times do
            local time = times[x]
            local line = ""
            if #timeIndex[time] > 0 then
              for y = 1, #timeIndex[time] do
                local event = timeIndex[time][y]
                if y > 1 then
                  line = line .. " / "
                end
                if event.Type == "Repeating" then
                  line = line .. "®  "
                end
                line = line .. event.Title .. " (" .. event.Category ..")"
              end
            end
            items[x] = line
          end
          lstSchedule.items = items
          lstSchedule:invalidate()
        end
        
        function plannerView:onPushed()
          self.date = calendarView.date
          self:refresh()
          lstSchedule.selected = 13
          lstSchedule.top = 12
      
        end  
      
        function plannerView:refresh()
          local m, d, y = splitDate(self.date)
          self.data = calendarData:getData(m, d, y)
          lblDate.text = date2Text(m, d, y)
          self:fillAllDayEvents()
          self:fillSchedule()
          local categories = settingsManager.eventFilter
          local categoriesHidden = 0
          
          for x = 1, #categories do
            if not categories[x] then
              categoriesHidden = categoriesHidden + 1
            end
          end
          lblFilter.text = "Categories Hidden: " .. categoriesHidden
          self:invalidate()
        end
        
      end
      
      -------------------
      -- Calendar View --
      -------------------
      do 
        local calendarDay = class()
        do 
          function calendarDay:init(dayOfWeek, weekOfMonth, dayOfMonth)
            self.dayOfWeek   = dayOfWeek -- integer, 1-7
            self.weekOfMonth = weekOfMonth
            self.x = 5 + (dayOfWeek - 1) * 44
            self.y = 40 + (weekOfMonth - 1) * 28
            self.dayOfMonth = dayOfMonth
            self.selected = false
          end
      
          function calendarDay:paint(gc)
            local cursorShow = self.selected == true and calendarView.cursorShow
            if cursorShow then
              gc:setColorRGB(0, 0, 100)
              gc:fillRect(self.x, self.y, 44, 28)
              gc:setColorRGB(255, 255, 255)
            else
              gc:setColorRGB(0, 0, 0)
            end
            gc:setFont("sansserif", "b", 10)
            gc:drawString(self.dayOfMonth, self.x + 4, self.y, "top")
            gc:setPen("thin", "smooth")
            gc:setColorRGB(0, 0, 0)
            gc:drawRect(self.x, self.y, 44, 28)
            
            local iconPositions = {}
            iconPositions.Appointment = { x = 32, y = 16 }
            iconPositions.HolyDay     = { x = 19, y = 2 }
            iconPositions.Anniversary = { x = 32, y = 2 }
            iconPositions.Holiday     = { x = 19, y = 16 }
            iconPositions.Repeating   = { x = 6 , y = 16 }
            iconPositions.DueDate     = { x = 6 , y = 16 }
            
            local data = self.eventData
            if data then
              for k, v in pairs(data) do
                local iconType = k
                if k == "Appointment" or k == "Repeating" then
                  for e = 1, #v do
                    local event = v[e]
                    if event.ShowIcon then
                      if type(event.ShowIcon) == "string" then
                        iconType = event.ShowIcon
                        if iconType == "True" then
                          iconType = k
                        end
                      else
                        iconType = k
                      end
                      if iconType ~= "False" then
                        gc:drawImage(eventIcons[iconType], self.x + iconPositions[iconType].x, self.y + iconPositions[iconType].y)
                      end
                    end
                  end
                else
                  gc:drawImage(eventIcons[k], self.x + iconPositions[k].x, self.y + iconPositions[k].y)
                end
              end
              if self.selected then
                calendarView:printEventText(gc, data)
              end
            end
          end
      
          -- Standard Widgets:    
          local butDate = Button {
            position = Position {
              top = "2px", right = "3px"
            },
            pic = calendarIcon,
            style = {
              defaultWidth = 22,
              defaultHeight = 22,
              borderColor = { 100, 0, 0 },
              focusColor = { 0, 0, 255},
              font = {
                size = 9,
                style = "b"
              }
            }
          }
          
          function butDate:onAction()
            local function setDate(date)
              calendarView.date = date
              calendarView:refresh()
            end
            local dateView = SelectDate("Select Date", calendarView.date, setDate)
            gtk.RootScreen:pushScreen(dateView)
            gtk.RootScreen:invalidate()
            calendarView.focusIndex = 0
            self.hasFocus = false
          end
          
          local searchIcon = searchIcon:copy(21, 21)
          local butSearch = Button {
            position = Position {
              top = "2px", right = "30px"
            },
            pic = searchIcon,
            style = {
              defaultWidth = 22,
              defaultHeight = 22,
              borderColor = { 100, 0, 0 },
              focusColor = { 0, 0, 255},
              font = {
                size = 9,
                style = "b"
              }
            }
          }
          function butSearch:onAction()
            calendarView.focusIndex = 0
            self.hasFocus = false
            showSimpleSearchDialog("Search Calendar Data", calendarData.search)
          end
          
          calendarView:addChildren(butDate, butSearch)
          
          function calendarView:enterKey()
            gtk.RootScreen:pushScreen(plannerView)
            gtk.RootScreen:invalidate()
            settingsManager:setLastDate(self.date)
          end
          
          function calendarView:escapeKey()
            timer.start(.5)
            self.date = settingsManager:getLastDate()
            self:refresh()
            self.focusIndex = 0
            butDate.hasFocus = false
            butSearch.hasFocus = false
          end
          
          function calendarDay:contains(x, y)
            if x >= self.x and x <= self.x + 44 and y >= self.y and y <= self.y + 28 then
              return true
            end
            return false
          end
      
          function calendarView:charIn(key)
            local function addEvent(choice)
              if choice == 1 then
                local appointment = {}
                appointment.Date = self.date
                showAppointmentDialog(appointment)
              elseif choice == 2 then
                local anniversary = {}
                anniversary.Date = self.date
                showAnniversaryDialog(anniversary)
              elseif choice == 3 then
                local holyDay = {}
                holyDay.Date = self.date
                showHolyDayDialog(holyDay)
              elseif choice == 4 then
                local holiday = {}
                holiday.Date = self.date
                showHolidayDialog(holiday)
              end
            end
            
            if key == "+" then
              local options = {"Add Appointment", "Add Anniversary", "Add Holy Day", "Add Holiday" }
              local eventChoice = ListBox("Add Event", options, addEvent)
              gtk.RootScreen:pushScreen(eventChoice)
              gtk.RootScreen:invalidate()
              local lstOptions = eventChoice.children[1]
              function lstOptions:onAction()
                local butOK = eventChoice.children[2]
                butOK:onAction()
              end
            elseif key == "1" then
              showAgenda(self.date)
            elseif key == "2" then
              gtk.RootScreen:pushScreen(projectManager)
              gtk.RootScreen:invalidate()
            elseif key == "3" then
              gtk.RootScreen:pushScreen(contactDirectory)
              gtk.RootScreen:invalidate()
            elseif key == "f" then
              settingsManager:setFilter("eventFilter")
            elseif key == "s" then
              showSimpleSearchDialog("Search Calendar Data", calendarData.search) 
            end
          end
          
          function calendarView:printEventText(gc, data)
            local date       = self.date
            local daysTable  = self.daysTable
            local lastDay    = daysTable[#daysTable]
            local x          = 5
            local topLine    = self.topLine
            local scrollText = self.scrollText
            
            gc:setFont("sansserif", "r", 7)
            
            if lastDay.weekOfMonth == 6 then
              x = lastDay.x + 49
            end
            
            local eventList = calendarData:getEventList(data)
            local lineY = 1
            local lastEvent = #eventList
            
            if lastEvent > topLine + 2 then
              lastEvent = topLine + 2
            end
            for i = topLine, lastEvent do
              local line = eventList[i]
              local colors  = {}
              colors.Other  = { 0, 0, 100 }
              colors.High   = { 200, 0, 0 }
              colors.Normal = { 0, 0, 150 }
              colors.Low    = { 200, 160, 200 }
              local color   = colors.Other
              if line.Priority then
                color = colors[line.Priority]
              end
              gc:setColorRGB(unpack(color))
              gc:drawString(gc:textLimit(line.text, 316 - x), x, 192 + 9 * (lineY - 1))
              lineY = lineY + 1
            end
            
            self.timerTick = self.timerTick + 1
            
            if self.timerTick < scrollDelay then
              return 
            else
              self.timerTick = 1
            end
            
            topLine = topLine + 1
            
            if #eventList < topLine + 2 then
              topLine = 1
            end
                    
            self.topLine = topLine
            
          end
        end
      
        function calendarView:refresh()
          local date = self.date
          local m, d, y = splitDate(date)
          calendarData:refresh(m, y)
          self:fillCalendar(m, d, y)
          
          if gtk.RootScreen:peekScreen() == plannerView then
            plannerView:refresh()
          end
          
          timer.start(.5)
          self:invalidate()
        end  
        
        function calendarView:onPushed()
          self.daysTable    = {}
          self.currentGridX = 1
          self.currentGridY = 1
          self.cursorShow   = true
          self.topLine      = 1
          self.timerTick    = 1
          
          self.date = settingsManager:getLastDate()
      
          local month, day, year = splitDate(self.date)
          self:fillCalendar(month, day, year)
          
          timer.start(.5)
        end
      
        function calendarView:selectDay(date)
          local m, d, y = splitDate(date)
          self.topLine = 1
          self.daysTable[d].selected = true
          self.date = date
        end
      
        -- Creates table of "day" objects for the month.
        function calendarView:fillCalendar(month, day, year)
          local dayNum    = 1
          local dayOfWeek = getFirstDay(month, year)
          local totalDays = maxDays(month, year)
          local weekNum   = 1
          local daysTable = {}
          
          for dayNum = 1, totalDays do
            daysTable[dayNum] = calendarDay(dayOfWeek, weekNum, dayNum)
            dayOfWeek = dayOfWeek + 1
            if dayOfWeek == 8 then
              dayOfWeek = 1
              weekNum = weekNum + 1
            end
            if dayNum == day then
              daysTable[dayNum].selected = true
            end
            daysTable[dayNum].eventData = calendarData:getData(month, dayNum, year)
          end
          self.daysTable = daysTable
          
          local categories = settingsManager.eventFilter
          local categoriesHidden = 0
          
          for x = 1, #categories do
            if not categories[x] then
              categoriesHidden = categoriesHidden + 1
            end
          end
          self.categoriesHidden = categoriesHidden
          
        end
        
        function calendarView:timer()
          self.cursorShow = not self.cursorShow
          self:invalidate()
        end
      
        function calendarView:arrowRight()
          local date = self.date
          local m, d, y = splitDate(date)
          self.daysTable[d].selected = false
          
          date = addDays(date, 1)
          local oldMonth = m
          m, d, y = splitDate(date)
          if m  ~= oldMonth then
            self:fillCalendar(m, d, y)
          end
          self:selectDay(date)
        end
      
        function calendarView:arrowDown()
          local date = self.date
          local m, d, y = splitDate(date)
          self.daysTable[d].selected = false
          
          date = addDays(date, 7)
          local oldMonth = m
          m, d, y = splitDate(date)
          if m  ~= oldMonth then
            self:fillCalendar(m, d, y)
          end
          self:selectDay(date)
        end
      
        function calendarView:arrowLeft()
          local date = self.date
          local m, d, y = splitDate(date)
          self.daysTable[d].selected = false
          
          date = subtractDays(date, 1)
          local oldMonth = m
          m, d, y = splitDate(date)
          if m  ~= oldMonth then
            self:fillCalendar(m, d, y)
          end
          self:selectDay(date)
        end
      
        function calendarView:arrowUp()
          local date = self.date
          local m, d, y = splitDate(date)
          self.daysTable[d].selected = false
      
          date = subtractDays(date, 7)
          self.date = date
          local oldMonth = m
          m, d, y = splitDate(date)
          if m  ~= oldMonth then
            self:fillCalendar(m, d, y)
          end
          self:selectDay(date)
        end
        
        function calendarView:draw(gc, x, y, width, height)
          local date = self.date
          local month, day, year = splitDate(date)
          local daysTable = self.daysTable
          
          gc:setColorRGB(0, 0, 100)
          gc:setFont("serif", "b", 15)
          gc:drawString(monthNames[month] .. " " .. year, 13, 1, "top")
      
          if self.categoriesHidden > 0 then
            gc:setFont("sansserif", "b", 6)
            gc:setColorRGB(200, 0, 0)
            gc:drawString("Categories Hidden: " .. self.categoriesHidden, 170, 25)
          end
          
          for dayNum = 1, 7 do
            gc:setColorRGB(0, 0, 100)
            gc:drawRect(5 + (dayNum - 1) * 44, 30, 44, 10)  
            gc:fillRect(5 + (dayNum - 1) * 44, 30, 44, 10)  
            gc:setColorRGB(255, 255, 255)
            gc:setFont("sansserif", "b", 6)
            gc:drawString(dayAbbrev[dayNum], 16 + (dayNum - 1) * 44, 30, "top")
          end
          
          for dayNum = 1, #daysTable do 
            daysTable[dayNum]:paint(gc)
          end
        end  
      
        function calendarView:mouseDown(x, y)
          local daysTable = self.daysTable
          local date = self.date
          
          for dayNum = 1, #daysTable do
            if daysTable[dayNum]:contains(x,y) then
              for x = 1, #daysTable do
                daysTable[x].selected = false
              end
              local m, d, y = splitDate(date)
              d = dayNum
              date = concatDate(m, d, y)
              self:selectDay(date)
              self:invalidate()
              settingsManager:setLastDate(date)
              return
            end
          end
          View.mouseDown(self, x, y)
        end
      
      end
      
      local function showCommDialog(contact, sel)
        local history = contact.History or {}
        local entry   = history[sel] or {}
        local date    = calendarView.date
        
        local position = Position {
          top = "10%", left = "20%"
        }
      
        local title = (sel ~= 0  and "Edit Communication Entry") or "New Communication Entry"
        local dialog = Dialog(title, position, Dimension("59%", "64%"))
        
        local lblDate = Label {
          position = Position {
            top = "29px", left = "5px"
          },
          text = "Date: "
        }
        
        dialog:addChild(lblDate)
        
        local grpDate = DateGroup(
          Position {    
            top = "0px", left = "10px", alignment = {
              {ref = lblDate, side = Position.Sides.Top },
              {ref = lblDate, side = Position.Sides.Right }
            }
          },
          dialog,
          entry.Date or date
        )
      
        local lblType = Label {
          position = Position {
            top = "7px", left = "0px", alignment = {
              { ref = lblDate, side = Position.Sides.Bottom },
              { ref = lblDate, side = Position.Sides.Left }
            }
          },
          text = "Type: "
        }
      
        local drpType = Dropdown {
          position = Position {    
            top = "0px", left = "8px", alignment = {
              {ref = lblType, side = Position.Sides.Top },
              {ref = lblType, side = Position.Sides.Right }
            }
          },
          items = settingsManager.communicationTypes,
          value = entry.Type or settingsManager.communicationTypes[1],
          style = {
            defaultWidth = 130
          }
        }
      
        local lblNotes = Label {
          position = Position {
            top = "7px", left = "0px", alignment = {
              { ref = lblType, side = Position.Sides.Bottom },
              { ref = lblType, side = Position.Sides.Left }
            }
          },
          text = "Notes: "
        }
      
        local txtNotes = Input {
          position = Position {    
            top = "0px", left = "3px", alignment = {
              {ref = lblNotes, side = Position.Sides.Top },
              {ref = lblNotes, side = Position.Sides.Right }
            }
          },
          value = entry.Notes or "",
          style = {
            defaultWidth = 129
          }
        }
      
        local butSave = Button {
          position = Position {
            bottom = "2px", right = "43px"
          },
          text = "Save",
          auto = true
        }
        function butSave:onAction()
          local entry = {}
          entry.Date = grpDate:getValue()
          entry.Type = drpType.value
          entry.Notes = txtNotes.value
          if sel == 0 then
            contact.History = contact.History or {}
            table.insert(contact.History, entry)
          else
            contact.History[sel] = entry
          end
          Contact:save(contact)
          
          local varName = "contacts.n" .. contact.ID
          contact = Contact:get(varName)
          gtk.RootScreen:popScreen()
          local screen = gtk.RootScreen:peekScreen()
          screen:onPushed(contact)
          screen:invalidate()
        end
        
        local butCancel = Button {
          position = Position {
            bottom = "2px", right = "5px", alignment = {
              { ref = butSave, side = Position.Sides.Left }
            }
          },
          text = "Cancel",
          auto = true
        }
        function butCancel:onAction()
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
        end
        
        dialog:addChildren(lblType, drpType, lblNotes, txtNotes, butSave, butCancel)
        dialog.defaultFocus = 9
        gtk.RootScreen:pushScreen(dialog)
        gtk.RootScreen:invalidate()
        
      end
      
      ----------------------------
      -- Contact Directory View --
      ----------------------------
      do 
        local letterTabs = {}
        for x = 1, 26 do
          local tab = string.char(64 + x)
          table.insert(letterTabs, tab)
        end
        table.insert(letterTabs, "#")
          
        local lstTabs = List {
          position = Position {
            top = "2px", left = "2px"
          },
          style = {
            defaultWidth = 35,
            defaultHeight = 207,
            focusColor = { 50, 200, 200 },
            selectColor = { 50, 200, 200 },
            font = {
              style = "b"
            },
          },
          items = letterTabs
        }
        function lstTabs:charIn(key)
          key = string.upper(key) or key
          if key:find("[%d#]") then
            key = "#"
          end
          List.charIn(self, key)
        end
        
        local lstNames = List {
          position = Position {
            top = "2px", left = "38px"
          },
          style = {
            defaultHeight = 97,
            defaultWidth = 276,
            selectColor = { 50, 200, 200 },
            focusColor = { 50, 200, 200 }
          },
          items = {}
        }
      
        local edtContactInfo = Editor {
          position = Position {
            top = "101px", left = "39px"
          },
          style = {
            defaultWidth = 275,
            defaultHeight = 108,
            focusColor = { 50, 200, 200 },
            cursorColor = { 255, 255, 255 }
          },
          readOnly = true,
          value = ""
        }
        function edtContactInfo:escapeKey()
          self.parent:backtabKey()
        end
      
        function lstTabs:change(sel)
          local letter = self.items[sel]
          Contact:getIndex(letter)
          
          lstNames.items = Contact:getNames()
          lstNames.selected = 1
          lstNames.top = 0
          lstNames:invalidate()
          edtContactInfo:setValue("")
        end
      
        function lstTabs:enterKey()
          self.parent:tabKey()
        end
          
        function lstNames:change(sel)
          local contact = Contact.currentIndex[sel - 1]
          if contact then
            contact = Contact:get(contact[2])
            contact = self.parent:formatInfo(contact)
          end
          edtContactInfo:setValue(contact or "")
          edtContactInfo:invalidate()
        end
      
        function lstNames:backspaceKey()
          local sel = self.selected
          local contact = Contact.currentIndex[sel - 1]
          
          local function deleteContact()
            --print(gtk.tools.varDump(contact))
            contact = Contact:get(contact[2])
            Contact:delete(contact)
            Contact:getVarNames()
            sel = lstTabs.selected
            lstTabs:change(sel)
          end
          
          if contact then
            local message = "Delete " .. contact[1] .. "?"
            local confirm = ConfirmationBox("Delete Contact", message, deleteContact)
            gtk.RootScreen:pushScreen(confirm)
            gtk.RootScreen:invalidate()
          
          end
        end
        
        function lstNames:escapeKey()
          gtk.RootScreen:resetFocus(self.parent)
          gtk.RootScreen:invalidate()
        end
      
        function lstNames:enterKey()
          local sel = self.selected
          
          if sel == 1 then
            showContactDialog()
          else
            sel = sel - 1
            local contact = Contact.currentIndex[sel][2]
            contact = Contact:get(contact)
            gtk.RootScreen:pushScreen(contactInfo, contact)
            gtk.RootScreen:invalidate()
          end
        end
          
        contactDirectory.defaultFocus = 1
        contactDirectory:addChildren(lstTabs, lstNames, edtContactInfo)
      
        function contactDirectory:resetView()
          Contact:getVarNames()
          local letter = lstTabs.selected
          letter = lstTabs.items[letter]
          Contact:getIndex(letter)
          
          lstNames.items = Contact:getNames()
          
          local contact = Contact.currentIndex[lstNames.selected - 1]
          if contact then
            contact = Contact:get(contact[2])
            contact = self:formatInfo(contact)
          end
          edtContactInfo:setValue(contact or "")
        end
      
        function contactDirectory:formatInfo(contact)
          if not contact then
            return ""
          end
          
          local text = ""
          
          local function addBuffer(str)
            str = "  " .. str
            str = string.gsub(str, "↵", "↵  ")
            return str
          end
          
          if contact.Address ~= "" then
            text = text .. "ADDRESS:↵" .. addBuffer(contact.Address) .. "↵↵"
          end
      
          if contact.Phone ~= "" then
            text = text .. "PHONE:↵" .. addBuffer(contact.Phone) .. "↵↵"
          end
      
          if contact.Email ~= "" then
            text = text .. "EMAIL / WEB:↵" .. addBuffer(contact.Email)
          end
          
          return text
        end
      
        function contactDirectory:onPopped()
          toolpalette.enable("Options", "Filter...", true)
          View:onPopped()
        end
            
        function contactDirectory:onPushed()
          lstTabs.selected = 1
          lstTabs.top = 0
          lstNames.selected = 1
          lstNames.top = 0
          toolpalette.enable("Options", "Filter...", false)
          self:resetView()
        end
      end
      
      do 
        local lblName = Label {
          position = Position {
            top = "2px", left = "5px"
          },
          text = "",
          style = {
            font = {
              size = 14
            },
            textColor = { 0, 0, 150 }
          }
        }
        
        local lblCategory = Label {
          position = Position {
            top = "30px", left = "5px"
          },
          text = "Category: ",
          style = {
            font = {
              size = 10,
              style = "b"
            },
            textColor = { 50, 200, 200 }
          }
        }
      
        local lblCategoryData = Label {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblCategory, side = Position.Sides.Top },
              { ref = lblCategory, side = Position.Sides.Right }
            }
          },
          text = "",
          style = {
            font = {
              size = 10,
            --  style = "b"
            },
            textColor = { 0, 0, 0 }
          }
        }
      
        local lblDOB = Label {
          position = Position {
            top = "30px", right = "75px"
          },
          text = "D.O.B.: ",
          style = {
            font = {
              size = 10,
              style = "b"
            },
            textColor = { 50, 200, 200 }
          }
        }
      
        local lblDOBdata = Label {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblDOB, side = Position.Sides.Top },
              { ref = lblDOB, side = Position.Sides.Right }
            }
          },
          text = "",
          style = {
            font = {
              size = 10,
            --  style = "b"
            },
            textColor = { 0, 0, 0 }
          }
        }
        
        local lblCommHistory = Label {
          position = Position {
            top = "55px", left = "5px"
          },
          text = "Communication History:",
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = { 50, 200, 200 }
          }
        }
          
        local lstCommHistory = List {
          position = Position {
            top = "1px", left = "0px", alignment = {
              { ref = lblCommHistory, side = Position.Sides.Bottom },
              { ref = lblCommHistory, side = Position.Sides.Left }
            }
          },
          style = {
            selectColor = { 50, 200, 200 },
            font = {
              size = 8
            },
            defaultWidth = 308,
            defaultHeight = 60,
            lineHeight = 10
          },
          items = {},
        }
        function lstCommHistory:onAction()
          local sel = self.selected - 1
          local contact = self.parent.contact    
          showCommDialog(contact, sel)
        end
        function lstCommHistory:backspaceKey()
          local sel = self.selected - 1
          local contact = self.parent.contact
          if sel == 0 then
            return 
          end
          
          local function deleteEntry()
            table.remove(contact.History, sel)
            Contact:save(contact)
            local screen = gtk.RootScreen:peekScreen()
            screen:onPushed(contact)
            screen:invalidate()
          end
          
          local message = "Delete '" .. self.items[sel + 1] .. "'?" 
          dialog = ConfirmationBox("Delete Entry", message, deleteEntry)
          gtk.RootScreen:pushScreen(dialog)
          gtk.RootScreen:invalidate()
        end
        
        local lblNotes = Label {
          position = Position {
            top = "135px", left = "5px"
          },
          text = "Notes:",
          style = {
            font = {
              size = 8,
              style = "b"
            },
            textColor = { 50, 200, 200 }
          }
        }
      
        local edtNotes = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblNotes, side = Position.Sides.Bottom },
              { ref = lblNotes, side = Position.Sides.Left }
            }
          },
          style = {
            cursorColor = { 50, 200, 200 },
            font = {
              size = 8
            },
            defaultWidth = 265,
            defaultHeight = 60,
          },
          value = ""
        }
        function edtNotes:onBlur()
          local contact = self.parent.contact
          contact.Notes = edtNotes.value
          Contact:save(contact)
        end
        
        local butClose = Button {
          position = Position {
            top = "148px", right = "3px"
          },
          text = "Close",
          style = {
            defaultHeight = 17,
            defaultWidth = 40,
            font = {
              size = 8
            }
          }
        }
        function butClose:onAction()
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
        end
        
        local butEdit = Button {
          position = Position {
            top = "4px", right = "3px", alignment = {
              { ref = butClose, side = Position.Sides.Bottom}
            }
          },
          text = "Edit",
          style = {
            defaultHeight = 17,
            defaultWidth = 40,
            font = {
              size = 8
            }
          }
        }
        function butEdit:onAction()
          gtk.RootScreen:popScreen()
          showContactDialog(self.parent.contact)
        end
        
        local butAddBday = Button {
          position = Position {
            top = "4px", right = "3px", alignment = {
              { ref = butEdit, side = Position.Sides.Bottom}
            }
          },
          text = "B-Day",
          style = {
            defaultHeight = 17,
            defaultWidth = 40,
            font = {
              size = 8
            }
          }
        }
        function butAddBday:onAction()
          local contact = self.parent.contact
          local date = contact.DOB
          local m, d = splitDate(date)
          if not m or not d then
            local dialog = MessageBox("ERROR", "There is an error with this date, and a calendar anniversary cannot be created.")
            gtk.RootScreen:pushScreen(dialog)
            gtk.RootScreen:invalidate()
            return 
          end
          local event = {}
          event.Date = date
          event.Title = contact.Name .. "'s Birthday"
          event.Type = "Anniversary"
          calendarData:saveEvent(event)
          calendarView:refresh()
          local dialog = MessageBox("Information", event.Title .. " has been added to th calendar.")
          gtk.RootScreen:pushScreen(dialog)
          gtk.RootScreen:invalidate()
        end
        
        contactInfo.defaultFocus = 7
        
        contactInfo:addChildren(lblName, lblCategory, lblCategoryData, lblDOB, lblDOBdata, lblCommHistory, lstCommHistory, lblNotes, edtNotes, butClose, butEdit, butAddBday)
      
        function contactInfo:onPushed(contact)
          self.contact = contact
          lblName.text = contact.Name or ""
          lblCategoryData.text = contact.Category or ""
          if not contact.DOB  or contact.DOB == "" then
            lblDOB.text = ""
            butAddBday:hide()
          else 
            butAddBday:show()
          end
          lblDOBdata.text = contact.DOB or ""
          edtNotes:setValue(contact.Notes or "")
          
          local items = { "-- Add New Communication --" }
          local history = contact.History or {}
          for x = 1, #history do
            local line = history[x].Date .. " - " .. history[x].Type 
            if history[x].Notes and history[x].Notes ~= "" then
              line = line .. " - " .. history[x].Notes
            end
            table.insert(items, line)
          end
          
          lstCommHistory.items = items
          lstCommHistory.selected = 1
          lstCommHistory.top = 0
        end  
      end
      
      function showContactDialog(contact)
        local position = Position {
          top = "5px", left = "5px"
        }  
        local dimension = Dimension(305, 200)
        local title = contact and "Edit Contact" or "New Contact"
        local contact = contact or {}
          
        local contactDialog = ScrollingDialog(title, position, dimension, 290)
        
        local lblName = Label {
          position = Position {
            top = "5px", left = "3px"
          },
          text = "Name: ",
          style = {
            font = {
             -- size = 10,
            --  style = "b"
            },
           -- textColor = { 50, 200, 200 }
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
            defaultWidth = 230
          },
          value = contact.Name or ""
        }
      
        local lblCategory = Label {
            position = Position {
            top = "30px", left = "3px"
          },
          text = "Category: "
        }
        
        local drpCategory = Dropdown {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblCategory, side = Position.Sides.Top },
              { ref = lblCategory, side = Position.Sides.Right }
            }
          },
          items = settingsManager.contactCategories,
          value = contact.Category or settingsManager.contactCategories[1],
          style = {
            defaultWidth = 100
          }
        }
        
        local lblDOB = Label {
          position = Position {
            top = "0px", left = "5px", alignment = {
              { ref = drpCategory, side = Position.Sides.Top },
              { ref = drpCategory, side = Position.Sides.Right }
            }
          },
          text = "D.O.B.: "
        }
        
        local txtDOB = Input {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblDOB, side = Position.Sides.Top },
              { ref = lblDOB, side = Position.Sides.Right }
            }
          },
          style = {
            defaultWidth = 59
          },
          value = contact.DOB or ""
        }
        
        local lblAddress = Label {
          position = Position {
            top = "54px", left = "5px"
          },
          text = "Address(es):",
          style = {
            font = {
              size = 8
            }
          }
        }
        
        local edtAddress = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblAddress, side = Position.Sides.Bottom },
              { ref = lblAddress, side = Position.Sides.Left }
            }
          },
          style = {
            defaultWidth = 270,
            defaultHeight = 50,
            font = {
              size = 9
            }
          },
          value = contact.Address or ""
        }
      
        local lblPhone = Label {
          position = Position {
            top = "5px", left = "5px", alignment = {
              { ref = edtAddress, side = Position.Sides.Bottom }
            }
          },
          text = "Phone Number(s):",
          style = {
            font = {
              size = 8
            }
          }
        }
        
        local edtPhone = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblPhone, side = Position.Sides.Bottom },
              { ref = lblPhone, side = Position.Sides.Left }
            }
          },
          style = {
            defaultWidth = 270,
            defaultHeight = 35,
            font = {
              size = 9
            }
          },
          value = contact.Phone or ""
        }
      
        local lblEmail = Label {
          position = Position {
            top = "5px", left = "5px", alignment = {
              { ref = edtPhone, side = Position.Sides.Bottom }
            }
          },
          text = "Email and/or Web Site Address(es):",
          style = {
            font = {
              size = 8
            }
          }
        }
        
        local edtEmail = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblEmail, side = Position.Sides.Bottom },
              { ref = lblEmail, side = Position.Sides.Left }
            }
          },
          style = {
            defaultWidth = 270,
            defaultHeight = 35,
            font = {
              size = 9
            }
          },
          value = contact.Email or ""
        }
      
        local lblNotes = Label {
          position = Position {
            top = "5px", left = "5px", alignment = {
              { ref = edtEmail, side = Position.Sides.Bottom }
            }
          },
          text = "Notes:",
          style = {
            font = {
              size = 8
            }
          }
        }
        
        local edtNotes = Editor {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblNotes, side = Position.Sides.Bottom },
              { ref = lblNotes, side = Position.Sides.Left }
            }
          },
          style = {
            defaultWidth = 270,
            defaultHeight = 35,
            font = {
              size = 9
            }
          },
          value = contact.Notes or ""
        }
      
        contactDialog.OK.text = "Save"
        
        function contactDialog.OK:onAction()
          local contactData = {}
          
          contactData.Name     = txtName.value
          contactData.ID       = contact.ID or Contact:getNewID()
          contactData.Address  = edtAddress.value or ""
          contactData.Phone    = edtPhone.value or ""
          contactData.Email    = edtEmail.value or ""
          contactData.Notes    = edtNotes.value or ""
          contactData.DOB      = txtDOB.value or ""
          contactData.Category = drpCategory.value
          
          Contact:save(contactData)
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
          
          local screen = gtk.RootScreen:peekScreen()
          screen:resetView()
        end
      
        function contactDialog.Cancel:onAction()
          gtk.RootScreen:popScreen()
          gtk.RootScreen:invalidate()
        end  
        
        contactDialog:addChildren(lblName, txtName, lblCategory, drpCategory, lblDOB, txtDOB, lblAddress, edtAddress, lblPhone, edtPhone, lblEmail, edtEmail, lblNotes, edtNotes)
        contactDialog.defaultFocus = 5
          
        gtk.RootScreen:pushScreen(contactDialog)
        gtk.RootScreen:invalidate()
      end
      
      --------------------------
      -- Project Manager View --
      --------------------------
      do
        projectManager.defaultFocus = 4
        
        local lblSortBy = Label {
          position = Position {
            top = "2px", left = "5px"
          },
          text = "Sort by: "
        }
        
        local drpSortBy = Dropdown {
          position = Position {
            top = "0px", left = "0px", alignment = {
              { ref = lblSortBy, side = Position.Sides.Top },
              { ref = lblSortBy, side = Position.Sides.Right }
            }
          },
          items = {"Category", "Priority", "Date Started", "Due Date"},
          style = {
            defaultWidth = 120  
          }
        }
        function drpSortBy:onAction()
          self.parent.sortBy = self.value
          self.parent:sortProjects()
          self.parent:saveSettings()
          self.parent:resetView()
        end
        
        local chkHideDone = Checkbox {
          position = Position {
            top = "3px", left = "15px", alignment = {
              { ref = drpSortBy, side = Position.Sides.Right},
              { ref = drpSortBy, side = Position.Sides.Top}
            }
          },
          style = {
            font = {
              size = 9
            },
          },
          text = "Hide Completed"
        }
        function chkHideDone:onAction()
          projectManager.hideDone = self.value
          projectManager:saveSettings()
          projectManager:resetView()
        end
      
        local lstProjects = List {
          position = Position {
            top = "25px", left = "2px"
          },
          style = {
            defaultWidth = 200,
            defaultHeight = 101,
            selectColor = { 200, 180, 180 }
          },
          items = {}
        }
        function lstProjects:change(sel)
          self.selected = sel
          local project = projectManager:getSelectedProject()
          projectManager:showDetails(project)
        end
        function lstProjects:enterKey()
          local project = projectManager:getSelectedProject()
          projectManager:showProjectDialog(project)
        end
        function lstProjects:backspaceKey()
          local sel = self.selected - 1
          if sel < 1 then
            return 
          end
          local project = projectManager:getSelectedProject()
          local taskIDs = projectManager:getTaskIDs(project)
          local message = "Are you sure that you want to delete project '" .. project.Title .. "' and its " .. #taskIDs .. " tasks?"
          local function deleteProject()
            for x = 1, #taskIDs do
              local varName = "tasks.n" .. taskIDs[x]
              math.eval("DelVar " .. varName)
            end
            math.eval("DelVar projects.n" .. project.ID)
            projectManager:resetView()
          end
          local confirm = ConfirmationBox("Delete Project", message, deleteProject)
          gtk.RootScreen:pushScreen(confirm)
          gtk.RootScreen:invalidate()
          
        end
        function lstProjects:drawBackground(gc, x, y, w, h)
          local colors = {}
          local top = self.top
          local lh = self.style.lineHeight
          local num = self.numVisible
          local varIndex = projectManager.projectIndex
          local items = self.items
          local sel = self.selected
      
          colors.High   = { 240, 0, 0 }
          colors.Normal = { 0, 150, 240 }
          colors.Low    = { 200, 160, 200 }
          
          for i = 1, math.min(#items - top, num + 1) do
            local varName = varIndex[i + top - 1]
            if varName then
              local project = projectManager:getProject(varName)
              local priority = project.Priority
              local color = colors[priority]
      
              if i + top == sel then
                self.style.selectColor = color
              elseif sel == 1 then
                self.style.selectColor = { 200, 180, 180 }
              end
              gc:setColorRGB(unpack(color))
              gc:fillRect(x + 2, y + i * lh - lh + 1, 2, lh)
              gc:fillRect(x + w - 17, y + i * lh - lh + 1, 5, lh)
            end      
          end
        end
      
        local lblCategory = Label {
          position = Position {
            top = "0px", left = "5px",
            alignment = {
              { ref = lstProjects, side = Position.Sides.Top },
              { ref = lstProjects, side = Position.Sides.Right },
            }
          },
          text = "",
          style = {
            font = {
              size = 8,
              style = "b"
            }
          }
        }
        
        local lblDate = Label {  -- Show either date started or due date
          position = Position {
            top = "0px", left = "0px",
            alignment = {
              { ref = lblCategory, side = Position.Sides.Bottom },
              { ref = lblCategory, side = Position.Sides.Left },
            }
          },
          text = "",
          style = {
            font = {
              size = 8,
              style = "b"
            }
          }
        }
        
        local lblPriority = Label {
          position = Position {
            top = "0px", left = "0px",
            alignment = {
              { ref = lblDate, side = Position.Sides.Bottom },
              { ref = lblDate, side = Position.Sides.Left },
            }
          },
          text = "",
          style = {
            font = {
              size = 8,
              style = "b"
            }
          }
        }
        
        local lblComplete = Label {
          position = Position {
            top = "0px", left = "0px",
            alignment = {
              { ref = lblPriority, side = Position.Sides.Bottom },
              { ref = lblPriority, side = Position.Sides.Left },
            }
          },
          text = "",
          style = {
            font = {
              size = 8,
              style = "b"
            }
          }
        }
      
        local lblNotes = Label {
          position = Position {
            top = "0px", left = "0px",
            alignment = {
              { ref = lblComplete, side = Position.Sides.Bottom },
              { ref = lblComplete, side = Position.Sides.Left },
            }
          },
          text = "Notes:",
          style = {
            font = {
              size = 8,
              style = "b"
            }
          }
        }
        
        local edtNotes = Editor{
          position = Position {
            top = "0px", left = "0px",
            alignment = {
              { ref = lblNotes, side = Position.Sides.Bottom },
              { ref = lblNotes, side = Position.Sides.Left },
            }
          },
          style = {
            defaultWidth = 108,
            defaultHeight = 36,
            font = {
              size = 7
            }
          }
        }
        function edtNotes:onFocus()
          Editor.onFocus(self)
          self.oldValue = self.value
        end
        function edtNotes:onBlur()
          Editor.onBlur(self)
          local value = self.value
          local oldValue = self.oldValue
          
          if oldValue == value then
            return 
          end
          
          local project = projectManager:getSelectedProject()
          if project then
            project.Notes = value
            projectManager:saveProject(project)
            self.savedProject = true
          else
            self:setValue("")
            self:invalidate()
          end
        end
      
        local lstTasks = List {
          position = Position {
            top = "5px", left = "0px",
            alignment = {
              { ref = lstProjects, side = Position.Sides.Bottom },
              { ref = lstProjects, side = Position.Sides.Left }
            }
          },
          style = {
            font = { 
              size = 8
            },
            defaultWidth = 287,
            defaultHeight = 76,
            lineHeight = 10,
            selectColor = { 200, 180, 180 }
          },
          items = projectManager.tasks
        }
        function lstTasks:onAction()
          projectManager:showTaskDialog()
        end
        function lstTasks:escapeKey()
          self.parent:giveFocusToChildAtIndex(4)
          self.hasFocus = false
          self.top = 0
          self.selected = 1
          self.parent:invalidate()
        end
        function lstTasks:backspaceKey()
          local sel = self.selected
          if #self.items < 2 or sel < 2 then
            return 
          else
            local project = projectManager:getSelectedProject()
            local taskIDs = projectManager:getTaskIDs(project)
            
            local title = self.items[sel]
            local message = "Are you sure that you want to delete task '" .. title .. "' from project '" .. project.Title .. "'?"
            sel = sel - 1
            local function deleteTask(sel)
              local varName = "tasks.n" .. taskIDs[sel]
              math.eval("DelVar " .. varName)
              table.remove(taskIDs, sel)
              project.TaskIDs = table.concat(taskIDs, ";")
              projectManager:saveProject(project)
              projectManager:showDetails(project)
              self.selected = sel
              self:invalidate()
            end
            local confirm = ConfirmationBox("Delete Task", message, deleteTask, sel)
            gtk.RootScreen:pushScreen(confirm)
            gtk.RootScreen:invalidate()
          end
          
        end
        
        local butTaskUp = Button {
          position = Position {
            top = "1px", left = "3px",
            alignment = {
              { ref = lstTasks, side = Position.Sides.Top },
              { ref = lstTasks, side = Position.Sides.Right }
            }
          },
          auto = true,
          style = {
            font = { 
              size = 10,
              style = "b"
            },
            defaultHeight = 25,
          },
          text = "▲"
        }
        function butTaskUp:onFocus()
          if edtNotes.savedProject then
            edtNotes.savedProject = false
            self.parent:resetView()
          end
        end
        function butTaskUp:onAction()
          local project = projectManager:getSelectedProject()
          local items = projectManager:getTaskIDs(project)
          local sel = lstTasks.selected - 1
          local top = lstTasks.top
          if sel < 1 or not project or not items then
            return 
          elseif sel == 1 then
            local temp = items[1]
            table.remove(items, 1)
            table.insert(items, temp)
          else
            local temp = items[sel - 1]
            items[sel - 1] = items[sel]
            items[sel] = temp
          end
          items = projectManager:sortTasks(items)
          project.TaskIDs = table.concat(items, ";")
          projectManager:saveProject(project)
          projectManager:showDetails(project)
          if sel == 1 then
            sel = #items
          else 
            sel = sel - 1
          end
          lstTasks.selected = sel + 1
          if sel <= top then
            top = sel - 1
          elseif sel > top + lstTasks.numVisible then
            top = sel - lstTasks.numVisible + 1
          end
          lstTasks.top = top
          lstTasks:invalidate()
        end
          
        local butTaskDown = Button {
          position = Position {
            bottom = "1px", left = "3px",
            alignment = {
              { ref = lstTasks, side = Position.Sides.Bottom },
              { ref = lstTasks, side = Position.Sides.Right }
            }
          },
          auto = true,
          style = {
            font = { 
              size = 10,
              style = "b"
            },
            defaultHeight = 25,
          },
          text = "▼"
        }
        function butTaskDown:onAction()
          local project = projectManager:getSelectedProject()
          local items = projectManager:getTaskIDs(project)
          local sel = lstTasks.selected - 1
          local top = lstTasks.top
          local numVisible = lstTasks.numVisible
          if sel < 1 or not project or not items then
            return 
          elseif sel == #items then
            local temp = items[#items]
            table.remove(items)
            table.insert(items, 1, temp)
          else
            local temp = items[sel + 1]
            items[sel + 1] = items[sel]
            items[sel] = temp
          end
          items = projectManager:sortTasks(items)
          project.TaskIDs = table.concat(items, ";")
          projectManager:saveProject(project)
          projectManager:showDetails(project)
          if sel == #items then
            sel = 1
          else 
            sel = sel + 1
          end
          lstTasks.selected = sel + 1
          if sel > top + numVisible - 1 then
            top = sel - numVisible + 1
          elseif sel + 1 < top + 1 then
            top = sel - 1
          end
          lstTasks.top = top
          lstTasks:invalidate()
        end
        
        projectManager:addChildren(lblSortBy, drpSortBy, chkHideDone, lstProjects, lblCategory, lblDate, lblPriority, lblComplete, lblNotes, edtNotes, lstTasks, butTaskUp, butTaskDown)
      
        projectManager.tasks = {"-- No project selected --"}
      
        function projectManager:resetView()
          self:loadSettings()
          self:genProjectIndex()
          
          drpSortBy.value = self.sortBy
          chkHideDone.value = self.hideDone
          
          lstProjects.items = self.projectList
          lstProjects.selected = 1
          lstProjects.top = 0
          
          self:showDetails()
          gtk.RootScreen:resetFocus(self)
          
          self:invalidate()
        end
          
        function projectManager:loadSettings()
          self.currentDate = calendarView.date
          self.sortBy = settingsManager.projectSettings[1]
          self.hideDone = settingsManager.projectSettings[2]
        end
        
        function projectManager:saveSettings()
          settingsManager.projectSettings[1] = self.sortBy
          settingsManager.projectSettings[2] = self.hideDone
          settingsManager:saveSettings()
        end
        
        function projectManager:genProjectIndex()
          local list = var.list()
          local projList = {}
          local hideDone = self.hideDone
          local index = Enum(settingsManager.eventCategories)
          local filter = settingsManager.projectFilter
      
          for x = 1, #list do
            local varName = list[x]
            if varName:find("projects.n") then
              local project = self:getProject(varName)
              local i = index[project.Category]
              if not i or filter[i] then
                if hideDone then
                  local done = string.find(self:getPercentDone(project), "100%", 1, true)
                  if not done then
                    table.insert(projList, varName)
                  end
                else
                  table.insert(projList, varName)
                end  
              end
            end
          end
          
          self.projectIndex = projList    
          self:sortProjects()
          self:genProjectList()
        end
      
        function projectManager:sortProjects()
          local sortBy = self.sortBy
          local projectIndex = self.projectIndex
          local keys = Enum({"Category", "Priority", "Date Started", "Due Date"})
          local index = keys[sortBy] + 1
          
          -- Make sorting table
          local sortTable = {}
          for x = 1, #projectIndex do
            local varName = projectIndex[x]
            local project = var.recall(varName)
            local sortValue = project[index] or "12/31/9999"
            table.insert(sortTable, {varName, sortValue})
          end
          
          local function sortNonDate(a, b)
            if a[2] < b[2] then
              return true
            else
              return false
            end
          end
          
          if index ==  keys.Priority + 1 then 
            for x = 1, #sortTable do
              if sortTable[x][2] == "Low" then
                sortTable[x][2] = 3
              elseif sortTable[x][2] == "Normal" then
                sortTable[x][2] = 2
              else 
                sortTable[x][2] = 1
              end
            end
            table.sort(sortTable, sortNonDate)
            projectIndex = sortTable
          elseif index == keys.Category + 1 then
            table.sort(sortTable, sortNonDate)
            projectIndex = sortTable
          else  -- A date field
            local sortA = gtk.tools.date.sortA
            projectIndex = sortA(sortTable, 2)
          end
          
          for x = 1, #projectIndex do
            projectIndex[x] = projectIndex[x][1]
          end
          
          self.projectIndex = projectIndex    
        end
        
        function projectManager:genProjectList()
          local index = self.projectIndex
          local titles = {}
          local hideDone = self.hideDone
          
          for x = 1, #index do
            local varName = index[x]
            local project = self:getProject(varName)
            local done = string.find(self:getPercentDone(project), "100%", 1, true)
            local title = project.Title
            if done and not hideDone then
              title = "✓ " .. title
              table.insert(titles, title)
            elseif not done then
              table.insert(titles, x, title)
            end
      
          end
          
          table.insert(titles, 1, "-- Add New Project --")
          self.projectList = titles
        end
      
        function projectManager:getSelectedProject()
          local sel = lstProjects.selected - 1
          local varName = projectManager.projectIndex[sel]
          local project
          if varName then
            project = projectManager:getProject(varName)
            return project
          else
            return false
          end    
        end
          
        function projectManager:getProject(varName)
          local data = var.recall(varName)
          if not data then
            return false
          end
          local project    = {}
          local projectID  = varName:match("%d+")
          project.ID       = projectID
          project.Title    = data[1]
          project.Category = data[2]
          project.Priority = data[3]
          project.Start    = data[4]
          project.Due      = data[5]
          project.Notes    = data[6]
          project.TaskIDs  = data[7]
          
          return project
        end
      
        function projectManager:saveProject(project)
          local data = {}
          
          if not project.ID then
            local ID = 0
            local test
            repeat
              ID = ID + 1
              test = var.recall("projects.n" .. ID)
            until not test
            project.ID = ID
            reindex = true
          end
          
          local varName = "projects.n" .. project.ID
          
          data[1] = project.Title
          data[2] = project.Category 
          data[3] = project.Priority 
          data[4] = project.Start
          data[5] = project.Due
          data[6] = project.Notes 
          data[7] = project.TaskIDs
          
          var.store(varName, data)
          if project.Due then
            calendarView:refresh()
          end
        end
      
        function projectManager:showDetails(project)
          if project then
            lblCategory.text = "Category: " .. project.Category
            if project.Due then
              lblDate.text = "Due Date: " .. project.Due
            elseif project.Start then 
              lblDate.text = "Started: ".. project.Start
            else
              lblDate.text = "Not started/ on hold"
            end
             
            lblPriority.text = "Priority: " .. project.Priority
            lblComplete.text = "Progress: " .. self:getPercentDone(project)
            edtNotes:setValue(project.Notes)
            lstTasks.items = self:getTaskList(project)
            lstTasks.selected = 1
            lstTasks.top = 0
            lstTasks:invalidate()
          else 
            lblCategory.text = "No project selected"
            lblDate.text = ""
            lblPriority.text = ""
            lblComplete.text = ""
            edtNotes:setValue("")
            lstTasks.items = {}
            lstTasks.selected = 0
            lstTasks.top = 0
            lstTasks:invalidate()
          end
          
        end
        
        function projectManager:getTaskIDs(project)
          local taskIDs = {}
      
          if not project then
            lstTasks:disable()
            return {}
          end
      
          lstTasks:enable()
          for ID in string.gmatch(project.TaskIDs, "%d+") do
            table.insert(taskIDs, ID)
          end
          return taskIDs
        end
        
        function projectManager:getTaskList(project)
          local taskIDs = self:getTaskIDs(project)
          if #taskIDs == 0 then
            return {"-- Add New Task --"}
          end
          
          local tasks = {}
          for n = 1, #taskIDs do
            local varName = "tasks.n" .. taskIDs[n]
            local task = var.recall(varName)
            local title = task[1]
            local done = task[2]
            if done then
              title = "✓  " .. title
            end
            table.insert(tasks, title)
          end
      
          table.insert(tasks, 1, "-- Add New Task --")
          lstTasks:enable()
          return tasks
        end
      
        function projectManager:getPercentDone(project)
          local taskIDs = {}
      
          if not project then
            return "n/a"
          end
          
          if not project.TaskIDs or #project.TaskIDs == 0 then
            return "n/a"
          end
      
          for ID in string.gmatch(project.TaskIDs, "%d+") do
            table.insert(taskIDs, ID)
          end
          
          if #taskIDs == 0 then
            return "0% (No tasks)"
          end
      
          local numDone = 0
          for n = 1, #taskIDs do
            local varName = "tasks.n" .. taskIDs[n]
            local task = var.recall(varName)
            local done = task[2]
            if done then
              numDone = numDone + 1
            end
          end
      
          return tostring(math.floor(numDone / #taskIDs * 100)) .. "% (" .. numDone .. " of " .. #taskIDs .. ")" 
        end
        
        function projectManager:showProjectDialog(project)
          local project = project or {}
          local title = "New Project"
          if project.ID then
            title = "Edit Project"
          end
          
          local position = Position{
            top = "7px", left = "8px"
          }
          local dimension = Dimension("95%", "78%")
          local dialog = Dialog(title, position, dimension)
          
          local lblTitle = Label{
            position = Position{
              top = "29px", left = "5px"
            },
            text = "Title: "
          }
          
          local txtTitle = Input{
            position = Position{
              top = "0px", left = "0px", alignment = {
                {ref = lblTitle, side = Position.Sides.Top},
                {ref = lblTitle, side = Position.Sides.Right}
              }
            },
            value = project.Title or "",
            style = {
              defaultWidth = "86%"
            }
          }
      
          local lblCategory = Label{
            position = Position{
              top = "54px", left = "5px"
            },
            text = "Category: "
          }
      
          local drpCategory = Dropdown{
            position = Position{
              top = "0px", left = "0px", alignment = {
                {ref = lblCategory, side = Position.Sides.Top},
                {ref = lblCategory, side = Position.Sides.Right}
              }
            },
            items = settingsManager.eventCategories,
            value = project.Category or "",
            style = {
              defaultWidth = 100
            }
          }
      
          local lblPriority = Label{
            position = Position{
              top = "54px", left = "174px"
            },
            text = "Priority: "
          }
      
          local drpPriority = Dropdown{
            position = Position{
              top = "0px", left = "0px", alignment = {
                {ref = lblPriority, side = Position.Sides.Top},
                {ref = lblPriority, side = Position.Sides.Right}
              }
            },
            items = {"Normal", "High", "Low"},
            value = project.Priority or "Normal",
            style = {
              defaultListWidth = 68
            }
          }
          
          local chkIncludeStart = Checkbox {
            position = Position {
              top = "79px", left = "5px"
            },
            text = "Incude Start Date",
            value = not (project.ID and not project.Start),
          }  
          
          local lblDateStart = Label {
            position = Position {
              top = "97px", left = "5px"
            },
            text = "Started: "
          }
          
          local lblDateDue = Label {
            position = Position {
              top = "140px", left = "5px"
            },
            text = "Due By: "
          }
      
          dialog:addChildren(lblTitle, txtTitle, lblCategory, drpCategory, lblPriority, drpPriority, chkIncludeStart, lblDateStart, lblDateDue)
          
          local dateStarted = DateGroup(
            Position {    
              top = "0px", left = "10px", alignment = {
                {ref = lblDateStart, side = Position.Sides.Top },
                {ref = lblDateStart, side = Position.Sides.Right }
              }
            },
            dialog,
            project.Start or projectManager.currentDate
          )
      
          local chkIncludeDueDate = Checkbox {
            position = Position {
              top = "122px", left = "5px"
            },
            text = "Incude Due Date",
            value = not (project.ID and not project.Due),
          }  
          
          function chkIncludeStart:onAction()
            if self.value then
              dateStarted:enable()
            else
              dateStarted:disable()
            end
          end
          
          dialog:addChild(chkIncludeDueDate)
          
          local dateDue = DateGroup(
            Position {    
              top = "0px", left = "9px", alignment = {
                {ref = lblDateDue, side = Position.Sides.Top },
                {ref = lblDateDue, side = Position.Sides.Right }
              }
            },
            dialog,
            project.Due or projectManager.currentDate
          )
      
          function chkIncludeDueDate:onAction()
            if self.value then
              dateDue:enable()
            else
              dateDue:disable()
            end
          end
          
          local lblNotes = Label {
            position = Position {
              top = "75px", left = "174px"
            },
            style = {
              font = {
                size = 8
              }
            },
            text = "NOTES:"
          }
          
          local edtNotes = Editor {
            position = Position {
              top = "0px", left = "0px", alignment = {
                { ref = lblNotes, side = Position.Sides.Bottom },
                { ref = lblNotes, side = Position.Sides.Left }
              }
            },
            style = {
              defaultWidth = 123,
              defaultHeight = 42
            },
            value = project.Notes or ""
          }
          
          local cmdSave = Button {
            position = Position {
              bottom = "3px", right = "5px"
            },
            text = "Save",
            auto = true
          }
          function cmdSave:onAction()
            project.Title    = txtTitle.value
            project.Category = drpCategory.value
            project.Priority = drpPriority.value
            project.Notes    = edtNotes.value
            
            if chkIncludeStart.value then
              project.Start = dateStarted:getValue()
              if project.Start ~= projectManager.currentDate then
                projectManager.currentDate = project.Start
                projectManager:saveSettings()
              end
            else
              project.Start = false
            end
            
            if chkIncludeDueDate.value then
              project.Due = dateDue:getValue()
            else 
              project.Due = false
            end
      
            if not project.TaskIDs then
              project.TaskIDs = ""
            end
      
            projectManager:saveProject(project)
            projectManager:resetView()
            gtk.RootScreen:popScreen()
            projectManager:resetView()
          end
          
          local cmdCancel = Button {
            position = Position {
              bottom = "3px", right = "5px", alignment = {
                { ref = cmdSave, side = Position.Sides.Left }
              }
            },
            text = "Cancel",
            auto = true
          }
          function cmdCancel:onAction()
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
          
          dialog:addChildren(lblNotes, edtNotes, cmdSave, cmdCancel)
          dialog.defaultFocus = 2
          
          gtk.RootScreen:pushScreen(dialog)
          
          if not chkIncludeStart.value then
            dateStarted:disable()
          end
          if not chkIncludeDueDate.value then
            dateDue:disable()
          end
          
          gtk.RootScreen:invalidate()
        end
        
        function projectManager:showTaskDialog()
          local project = self:getSelectedProject()
          if not project then
            return 
          end
          
          local taskIDs = self:getTaskIDs(project) or {}
          local selectedTask = lstTasks.selected - 1
          local taskID = taskIDs[selectedTask] or 0
          local varName = "tasks.n" .. taskID
          local task = var.recall(varName)
          local title = "Edit Task"
          if not task then
            task = {}
            title = "New Task"
          end
          
          local position = Position {
            top = "20%", left = "10%"
          }
          local dimension = Dimension("80%", "40%")
          local dialog = Dialog(title, position, dimension)
          
          local lblTitle = Label {
            position = Position {
              top = "30px", left = "5px"
            },
            text = "Task:"
          }
          
          local txtTask = Input {
            position = Position {
              top = "0px", left = "5px", alignment = {
                { ref = lblTitle, side = Position.Sides.Top },
                { ref = lblTitle, side = Position.Sides.Right}
              }
            },
            value = task[1] or "",
            style = {
              defaultWidth = "80%"
            }
          }
          
          local chkDone = Checkbox {
            position = Position {
              top = "10px", left = "0px", alignment = {
                { ref = txtTask, side = Position.Sides.Bottom },
                { ref = txtTask, side = Position.Sides.Left}
              }
            },
            text = "Completed",
            value = task[2] or false
          }
          
          local cmdSave = Button {
            position = Position {
              bottom = "5px", right = "7px"
            },
            text = "Save",
            auto = false,
            style = {
              defaultWidth = 40,
              defaultHeight = 25,
              font = {
                size = 9
              }
            }
          }
          function cmdSave:onAction()
            local title = txtTask.value
            local done = chkDone.value
            local taskID = taskID
            local task = {title, done}
            
            if taskID == 0 then
              local ID = 1
              while var.recall("tasks.n" .. ID) do
                ID = ID + 1
              end
              taskID = ID
              table.insert(taskIDs, taskID)
            end
            
            var.store("tasks.n" .. taskID, task)
            taskIDs = projectManager:sortTasks(taskIDs)
            
            project.TaskIDs = table.concat(taskIDs, ";")
            
            lstTasks.items = projectManager:getTaskList(project)
            lstTasks:invalidate()
            projectManager:saveProject(project)
            projectManager:showDetails(project)
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
          
          local cmdCancel = Button {
            position = Position {
              bottom = "5px", right = "53px"
            },
            text = "Cancel",
            auto = false,
            style = {
              defaultWidth = 49,
              defaultHeight = 25,
              font = {
                size = 9
              }
            }
          }
          function cmdCancel:onAction()
            gtk.RootScreen:popScreen()
            gtk.RootScreen:invalidate()
          end
          
          dialog.defaultFocus = 2
          dialog:addChildren(lblTitle, txtTask, chkDone, cmdSave, cmdCancel)
          
          gtk.RootScreen:pushScreen(dialog)
          gtk.RootScreen:invalidate()
        end
        
        function projectManager:sortTasks(taskIDs)
          if not taskIDs or #taskIDs < 2 then
            return taskIDs
          end
          local sortDone = false
          while not sortDone do
            sortDone = true
            for x = 1, #taskIDs - 1 do
              local varName1 = "tasks.n" .. taskIDs[x]
              local varName2 = "tasks.n" .. taskIDs[x + 1]
              local task1 = var.recall(varName1)
              local task2 = var.recall(varName2)
              if task1[2] and not task2[2] then
                local temp = taskIDs[x]
                taskIDs[x] = taskIDs[x + 1]
                table.remove(taskIDs, x + 1)
                table.insert(taskIDs, temp)
                sortDone = false
              end
            end
          end
          return taskIDs
        end
        
        function projectManager:onPushed()
          self:loadSettings()
          self:resetView()
        end
      end
      
      -----------------------------------
      -- Menu definition and functions --
      -----------------------------------
      function setFilter()
        local currentView = gtk.RootScreen:peekScreen()
        local name = ""
        
        if currentView == calendarView or currentView == plannerView then
          name = "eventFilter"
        elseif currentView == projectManager then
          name = "projectFilter"
        elseif currentView == contactDirectory then
          name = "contactFilter"
        end
        settingsManager:setFilter(name)
      end
      
      local menu = { 
        { "Add New...",
          { "Appointment", function () local event = {} event.Date = calendarView.date showAppointmentDialog(event) end },
          { "Holiday",     function () local event = {} event.Date = calendarView.date showHolidayDialog(event) end },
          { "Holy Day",    showHolyDayDialog },
    { "Anniversary", showAnniversaryDialog },
    { "Project",     function () local project = {}  projectManager:showProjectDialog(project) end},
    { "Contact",     function () showContactDialog() end }
  },
  { "Organizer", 
    { "Calendar", function () gtk.RootScreen:pushScreen(calendarView) gtk.RootScreen:invalidate() end },
    { "Planner",  function () gtk.RootScreen:pushScreen(plannerView) gtk.RootScreen:invalidate() end },
    { "Agenda",   function () showAgenda(calendarView.date) end },
    { "Projects", function () gtk.RootScreen:pushScreen(projectManager) gtk.RootScreen:invalidate() end },
    { "Contacts", function () gtk.RootScreen:pushScreen(contactDirectory) gtk.RootScreen:invalidate() end  },
  },
  { "Tools",
    { "Search Calendar...", function () showSimpleSearchDialog("Search Calendar Data", calendarData.search) end },
    { "Search Contacts...", function () showSearchDialog("Search Contacts", settingsManager.contactCategories, Contact.searchFields, Contact.search) end },
    { "Create 'Letters' Project", showAutoTaskDialog },
  },
  { "Options",
    { "Filter...", setFilter  },
    { "Edit Event Categories", function () settingsManager:editList("eventCategories") end },
    { "Edit Contact Categories", function () settingsManager:editList("contactCategories") end },
    { "Edit Communication Types", function () settingsManager:editList("communicationTypes") end },
    { "Purge Old Events", showPurgeDialog }
  },
  { "Help",
    { "About", function () dialog = MessageBox("About nPlanner 2.0", "nPlanner 2.0 is a complete rewrite from version 1.0...  (Basically because I lost the source code.)  It's pretty good, right?  Written by J. Beaman © 2021 - 2022") gtk.RootScreen:pushScreen(dialog) gtk.RootScreen:invalidate() end }
  }

}
toolpalette.register(menu)

-- Show first View:
gtk.RootScreen:pushScreen(calendarView)
