local VALUE = 0
local COMBO = 1

local isHorus = (LCD_W == 480)
local pageCount = isHorus and 11 or 7
local edit = false
local page = 1
local current = 1
local refreshState = 0
local pageOffset = 0
local pages = {}
local fields = {}
local modifications = {}
local margin = 1
local spacing = 8

local parameters = {
	{ "Stabilizing", COMBO, 0x40, 1, nil, { "ON", "OFF" }, { 1, 0 } },
	{ "Self Check", COMBO, 0x4C, 1, nil, { "Disable", "Enable" }, { 0, 1 } },
	{ "Quick Mode", COMBO, 0x41, 1, nil, { "Disable", "Enable" }, { 0, 1 } },
	{ "WingType", COMBO, 0x41, 2, nil, { "Normal", "Delta", "VTail" }, { 0, 1, 2 } },
	{ "Mounting Type", COMBO, 0x41, 3, nil, { "Horizontal", "Horizontal Reverse", "Vertical", "Vertical Reverse" }, { 0, 1, 2, 3 } },
	{ "CH5 Mode", COMBO, 0x42, 1, nil, { "AIL2", "AUX1" }, { 0, 1 } },
	{ "CH6 Mode", COMBO, 0x42, 2, nil, { "ELE2", "AUX2" }, { 0, 1 } },
	{ "AIL Direction", COMBO, 0x42, 3, nil, { "Normal", "Invers" }, { 0, 255 } },
	{ "ELE Direction", COMBO, 0x43, 1, nil, { "Normal", "Invers" }, { 0, 255 } },
	{ "RUD Direction", COMBO, 0x43, 2, nil, { "Normal", "Invers" }, { 0, 255 } },
	{ "AIL2 Direction", COMBO, 0x43, 3, nil, { "Normal", "Invers" }, { 0, 255 } },
	{ "ELE2 Direction", COMBO, 0x44, 1, nil, { "Normal", "Invers" }, { 0, 255 } },
	{ "AIL Stab Gain", VALUE, 0x44, 2, nil, 0, 200, "%", 0 },
	{ "ELE Stab Gain", VALUE, 0x44, 3, nil, 0, 200, "%", 0 },
	{ "RUD Stab Gain", VALUE, 0x45, 1, nil, 0, 200, "%", 0 },
	{ "AIL Auto 1v1 Gain", VALUE, 0x46, 1, nil, 0, 200, "%", 0 },
	{ "ELE Auto 1v1 Gain", VALUE, 0x46, 2, nil, 0, 200, "%", 0 },
	{ "ELE Hover Gain", VALUE, 0x47, 2, nil, 0, 200, "%", 0 },
	{ "RUD Hover Gain", VALUE, 0x47, 3, nil, 0, 200, "%", 0 },
	{ "AIL Knife Gain", VALUE, 0x48, 1, nil, 0, 200, "%", 0 },
	{ "RUD Knife Gain", VALUE, 0x48, 3, nil, 0, 200, "%", 0 },
	{ "AIL Auto 1v1 Offset", VALUE, 0x49, 1, nil, -20, 20, "%", 0x80 },
	{ "ELE Auto 1v1 offset", VALUE, 0x49, 2, nil, -20, 20, "%", 0x80 },
	{ "ELE Hover Offset", VALUE, 0x4A, 2, nil, -20, 20, "%", 0x80 },
	{ "RUD Hover Offset", VALUE, 0x4A, 3, nil, -20, 20, "%", 0x80 },
	{ "AIL Knife Offset", VALUE, 0x4B, 1, nil, -20, 20, "%", 0x80 },
	{ "RUD Knife Offset", VALUE, 0x4B, 3, nil, -20, 20, "%", 0x80 },
}



-- Change display attribute to current field
local function addField(step)
	local field = fields[current]
	local min, max
	if (field[2] == VALUE) then
		min = field[6]
		max = field[7]
	elseif (field[2] == COMBO) then
		min = 1
		max = #(field[6])
	end
	if (step < 0 and field[5] > min) or (step > 0 and field[5] < max) then
		field[5] = field[5] + step
	end
end

-- Select the next or previous page
local function selectPage(step)
	page = 1 + ((page + step - 1 + #pages) % #pages)
	pageOffset = 0
end

-- Select the next or previous editable field
local function selectField(step)
	current = 1 + ((current + step - 1 + #fields) % #fields)
	if current > pageCount + pageOffset then
		pageOffset = current - pageCount
	elseif current <= pageOffset then
		pageOffset = current - 1
	end
end

local function getNextNilField(offset)
	for offsetIndex = offset or 1, #fields do
		if fields[offsetIndex][5] == nil then
			return fields[offsetIndex], offsetIndex
		end
	end

	return nil, nil
end

local function drawProgressBar()
	local finishedCount = 0

	for index, thisField in ipairs(fields) do
		if thisField[5] ~= nil then
			finishedCount = finishedCount + 1
		end
	end

	if (LCD_W == 480) then
		local width = (300 * finishedCount) / #fields
		lcd.drawRectangle(106, 10, 300, 6)
		lcd.drawFilledRectangle(108, 12, width, 2);
	else
		local width = (60 * finishedCount) / #fields
		lcd.drawRectangle(51, 1, 60, 6)
		lcd.drawFilledRectangle(53, 3, width, 2);
	end
end

local function drawScreenTitle(title, page, pages)
	lcd.drawFilledRectangle(0, 0, LCD_W, 30, TITLE_BGCOLOR)
	lcd.drawText(1, 5, title, MENU_TITLE_COLOR)
	lcd.drawText(LCD_W - 40, 5, page.."/"..pages, MENU_TITLE_COLOR)
end

-- Redraw the current page
local function redrawFieldsPage()
	lcd.clear()

	if isHorus then
		drawScreenTitle("SRX", page, #pages)
	else
		lcd.drawScreenTitle("SRX", page, #pages)
	end

	if getNextNilField() ~= nil then
		drawProgressBar()
	end

	for index = 1, pageCount, 1 do
		local field = fields[pageOffset + index]
		if field == nil then
			break
		end

		local attr = current == (pageOffset + index) and ((edit == true and BLINK or 0) + INVERS) or 0

		lcd.drawText(1, margin + spacing * index, field[1])

		if field[5] == nil then
			lcd.drawText(LCD_W, margin + spacing * index, "---", attr + RIGHT)
		else
			if field[2] == VALUE then
				lcd.drawText(LCD_W, margin + spacing * index, tostring(field[5]) .. field[8] , attr + RIGHT)
			elseif field[2] == COMBO then
				if field[5] > 0 and field[5] <= #(field[6]) then
					lcd.drawText(LCD_W, margin + spacing * index, field[6][field[5]] , attr + RIGHT)
				end
			end
		end
	end
end

local function telemetryRead(field)
	return sportTelemetryPush(0x17, 0x30, 0x0C30, field)
end

local function telemetryWrite(field, value)
	return sportTelemetryPush(0x17, 0x31, 0x0C30, field + value * 256)
end

local telemetryPopTimeout = 0
local function refreshNext()
	if refreshState == 0 then
		local thisField = getNextNilField()
		if #modifications > 0 then
			telemetryWrite(modifications[1][1], modifications[1][2])
			modifications[1] = nil
		elseif thisField ~= nil then
			if telemetryRead(thisField[3]) == true then
				refreshState = 1
				telemetryPopTimeout = getTime() + 80 -- normal delay is 500ms
			end
		end
	elseif refreshState == 1 then
		local physicalId, primId, dataId, value = sportTelemetryPop()
		if primId == 0x32 and dataId == 0x0C30 then
			local fieldId = value % 256
			local refreshCount = 0
			-- Check all the fields
			for fieldIndex, thisField in ipairs(fields) do
				if fieldId == thisField[3] then
					refreshCount = refreshCount + 1
					-- Get local value with sub Id
					local fieldValue = math.floor(value / 2 ^ (thisField[4] * 8)) % 256
					-- Set value with checking field type
					if thisField[2] == COMBO and #thisField == 7 then
						for index = 1, #(thisField[7]), 1 do
							if fieldValue == thisField[7][index] then
								thisField[5] = index
								break
							end
						end
					elseif thisField[2] == VALUE and #thisField == 9 then
						thisField[5] = fieldValue - thisField[9]
					end
				end
				if refreshCount >= 3 then
					break
				end
			end
			refreshState = 0
		elseif getTime() > telemetryPopTimeout then
			refreshState = 0
		end
	end
end

local function getFieldValue(field)
	local value = field[5]
	if value == nil then
		return 0
	end
	if field[2] == COMBO and #field == 7 then
		value = field[7][value]
	elseif field[2] == VALUE and #field == 9 then
		value = value + field[9]
	end
	return value
end

local function updateFieldValue()
	local subIdCount = 0
	local value = 0
	for fieldIndex, thisField in ipairs(fields) do
		if fields[current][3] == thisField[3] then
			subIdCount = subIdCount + 1
			local fieldValue = getFieldValue(thisField)
			for subId = 2, thisField[4] do
				fieldValue = fieldValue * 256
			end
			value = value + fieldValue
		end
		if subIdCount >= 3 then
			break
		end
	end
	modifications[#modifications+1] = { fields[current][3], value }
end


-- Main
local function runFieldsPage(event)
	if (event == EVT_VIRTUAL_EXIT) then -- exit script
		return 2
	elseif (event == EVT_VIRTUAL_ENTER) then -- toggle editing/selecting current field
		if (fields[current][5] ~= nil) then
			edit = not edit
			if (edit == false) then
				updateFieldValue()
			end
		end
	elseif edit then
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			addField(1)
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			addField(-1)
		end
	else
		if event == EVT_VIRTUAL_NEXT then
			selectField(1)
		elseif event == EVT_VIRTUAL_PREV then
			selectField(-1)
		end
	end
	redrawFieldsPage()
	return 0
end


local function runPage(event)
	fields = parameters
	return runFieldsPage(event)
end


-- Init
local function init()
	current, edit, refreshState = 1, false, 0
	modifications = {}

	if LCD_W == 480 then
		margin = 10
		spacing = 20
	end

	pages = {
		runPage,
	}
end


-- Main
local function run(event)
	if event == nil then
		error("Cannot be run as a model script!")
		return 2
	elseif event == EVT_PAGE_BREAK or event == EVT_PAGEDN_FIRST or event == EVT_SHIFT_BREAK then
		selectPage(1)
	elseif event == EVT_PAGE_LONG  or event == EVT_PAGEUP_FIRST or event == EVT_SHIFT_LONG then
		killEvents(event);
		selectPage(-1)
	end

	local result = pages[page](event)
	refreshNext()

	return result
end


return { init=init, run=run }
