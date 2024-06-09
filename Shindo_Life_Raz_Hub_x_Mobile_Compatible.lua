if game.GameId ~= 1511883870 then return end

function getplatform()
	local GuiService = game:GetService("GuiService")
	local UserInputService = game:GetService("UserInputService")
	if (GuiService:IsTenFootInterface()) then
		return "Console"
	elseif (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		--touchscreen computers now have touchenabled so make sure to check for lack of mouse too
		--also, not all phones/tablets have accelerometer and/or gyroscope
		return "Mobile"
	else
		return "Desktop"
		-- return "Mobile"
	end
end

setreadonly = setreadonly or function () end
getgenv = getgenv or function()
	return getfenv()
end
newcclosure = newcclosure or function(f)
	return f
end
local t = table
local table = {}
for key, value in next, t do
	table[key] = value
end

local function create_config()
	local CONFIG_ROOT = 'Raz Hub'
	local library = {}
	local concat, find, insert = table.concat, table.find, table.insert
	
	setreadonly(table, false)
	function table.merge(default, current)
		for key, value in next, default do
			if (typeof(value) ~= typeof(current[key])) then
				current[key] = value
			elseif (typeof(value) == 'table') then
				table.merge(default[key], current[key])
			end
		end
	end
	setreadonly(table, true)

	local function create_metatable(tbl, mt)
		local metatable = setmetatable(tbl, mt)

		-- Synapse X engine can kill themselves.
		if (typeof(metatable) == 'boolean') then
			return tbl
		end

		return metatable
	end

	function library.new(self, path)
		local original_path = path
		if (typeof(path) ~= 'string') then
			path = CONFIG_ROOT
		else
			path = CONFIG_ROOT .. '/' .. path
		end

		if (isfolder and not isfolder(path)) then
			makefolder(path)
		end

		local function encode(tbl)
			return game:GetService("HttpService"):JSONEncode(tbl)
		end

		local function decode(str)
			return game:GetService("HttpService"):JSONDecode(str)
		end

		local function save(path, config)
			local content = {}

			for k,v in next, config do
				local key = tostring(k)
				local vtype = typeof(v)
				local env = getgenv()[vtype]
				if (typeof(env) == 'table' and env.new) then
					pcall(function()
						insert(content, key .. '__cautov' .. vtype .. '=' .. '[' .. tostring(v) .. ']')
					end)
					continue
				end

				if (vtype == 'Enum' or vtype == 'Enums' or vtype == 'EnumItem') then
					v = tostring(v):split('.')
					pcall(function()
						insert(content, key .. '__enum' .. vtype .. '=' .. encode(v))
					end)
					continue
				end

				insert(content, tostring(k) .. '=' .. encode(v))
			end
			
			if writefile then
				writefile(path, concat(content, '\n'))
			end
			
			return concat(content, '\n')
		end

		local sublibrary = {
			configuration = {},
			path = original_path
		}

		function sublibrary.load(self, key, default)
			local data = {}
			local path = path .. '/' .. key

			if (isfile and not isfile(path)) then
				save(path, default)
			end

			local content = readfile and readfile(path):split('\n') or save(path, default):split('\n')

			for _, line in next, content do
				local i = line:find('=')

				if (typeof(i) == 'number') then
					local key = line:sub(1, i-1)
					local auto_i = key:find('__cautov')
					local enum_i = key:find('__enum')
					if (auto_i) then
						if not (pcall(function()
								data[key:sub(1, auto_i-1)] = loadstring(string.format('return %s.new(...)', key:sub(auto_i + 8)))(unpack(decode(line:sub(i+1))))
							end)) then
							data[key:sub(1, auto_i-1)] = default[key:sub(1, auto_i-1)]
						end
					elseif (enum_i) then
						if not (pcall(function()
								data[key:sub(1, enum_i-1)] = loadstring(string.format('return %s', concat(decode(line:sub(i+1)), '.')))()
							end)) then
							data[key:sub(1, enum_i-1)] = default[key:sub(1, enum_i-1)]
						end
					else
						data[line:sub(1, i-1)] = decode(line:sub(i+1))
					end
				end
			end

			table.merge(default, data)

			return create_metatable(data, {
				__index = function(self, key)
					if (key == 'set') then
						return function (self, key, value)
							data[key] = value
							save(path, data)
						end
					end

					if (key == 'get') then
						return function (self, name)
							return data[name]
						end
					end

					if (key == 'reset') then
						return function (self, key)
							data[key] = default[key]
							save(path, data)
						end
					end

					if (key == 'save') then
						return function() end
					end
				end
			})
		end

		return create_metatable(sublibrary, {
			__index = function (self, key)
				if (key == 'create') then
					return function(self, name)
						return library:new((self.path and (self.path .. '/') or '') .. name)
					end
				end
			end
		})
	end

	return library
end

local unsupported_functions = {}
local functions_checked = 0
do
	if (game:IsLoaded() or game.Loaded:Wait()) then end
	local LookingFor = { "Players", "ReplicatedFirst", "ReplicatedStorage", "Lighting" }
	while (not select(1, pcall(function()
			for _, name in next, LookingFor do
				if (not game:GetService(name)) then return false end
			end

			return true
		end))) do task.wait() end

	local functions = {
		identifyexecutor = function()
			function identifyexecutor() return `Roblox{game:GetService("RunService"):IsStudio() and " Studio" or ''}` end
			return true
		end,
		isexecutorclosure = function()
			if ((is_synapse_function or issynapsefunction or issynapseclosure)) then
				getgenv().isexecutorclosure = is_synapse_function or issynapsefunction or issynapseclosure
			end

			getgenv().isourclosure = isexecutorclosure
			return true
		end,

		queue_on_teleport = function()
			if ((syn and rawget(syn, 'queue_on_teleport'))) then
				getgenv().queue_on_teleport = syn.queue_on_teleport
			end

			getgenv().queueonteleport = queue_on_teleport
			return true
		end,

		firesignal = function()
			if (getconnections) then
				firesignal = function (self, ...)
					for _, connection in next, getconnections(self) do
						connection:Fire(...)
					end
				end
			end

			return true
		end,

		getconnections = function()
			-- not wasting my time because going thru getgc or w/e is a waste of time and costs performance
			return true
		end,

		getrenderproperty = function()
			getgenv().getrenderproperty = newcclosure(function(self, property)
				return self[property]
			end)

			return true
		end,

		setrenderproperty = function()
			getgenv().setrenderproperty = newcclosure(function(self, property, value)
				self[property] = value
			end)

			return true
		end,
		fireclickdetector = function()
			return true
		end,
		firetouchinterest = function()
			return true
		end,
		gethui = function()
			return true
		end,
		console = function()
			if (rconsoleprint) then
				if (not console) then
					getgenv().console = {
						log = function(...) rconsoleprint(tostring(...) .. '\n') end,
						warn = function(...) console.log('[WARN] ' .. tostring(...)) end,
						error = function(...) console.log('[ERROR] ' .. tostring(...)) end
					}
				end
			end
			return true
		end
	}
	
	if getgenv then
		for name, func in next, functions do
			functions_checked += 1
			if (not getgenv()[name] and func()) then
				table.insert(unsupported_functions, name)
				print('unsupported')
			end
		end
	end
end

-- Main Variables [[
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CoreGui = gethui and gethui() or (game:GetService("RunService"):IsStudio() and Players.LocalPlayer.PlayerGui) or game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local IsMobile = getplatform() == 'Mobile'

local LocalPlayer; while (not LocalPlayer) do
	LocalPlayer = Players.LocalPlayer
	task.wait()
end

do
	LocalPlayer.Idled:connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end

local Mouse = LocalPlayer:GetMouse()
-- ]]

-- Main Functions [[
local function create_component(value)
	local class_name = rawget(value, "class_name")
	if (class_name) then
		local class = Instance.new(class_name)
		if (class_name == "ScreenGui") then
			if (syn and syn.protect_gui) then
				pcall(syn.protect_gui, class)
			end
		end

		for name, prop in next, value do
			pcall(function()
				class[name] = prop
			end)
		end

		return class
	end

	return nil
end

local function create_rounded(instance, corner_radius)
	create_component({
		class_name = "UICorner",
		CornerRadius = corner_radius,
		Parent = instance
	})
end

local function create_tween(instance, seconds, goal)
	local tween = game:GetService("TweenService"):Create(
	instance,
	TweenInfo.new(seconds, Enum.EasingStyle.Linear),
	goal
	)

	tween:Play()

	return tween
end
-- ]]

ContentProvider:PreloadAsync({
	"rbxassetid://3926305904",
	"rbxassetid://7861818231",
	"rbxassetid://8323804973",
	"rbxassetid://143854825"
})

local uwu = create_component({
	class_name = "Sound",
	SoundId = "rbxassetid://8323804973",
	Volume = 1
})

-- Icons [[
local icon_square = create_component({
	class_name = "ImageLabel",
	Active = true,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,

	Image = "rbxassetid://3926305904",
	ImageRectOffset = Vector2.new(884, 644),
	ImageRectSize = Vector2.new(36, 36),

	Size = UDim2.new(0, 30, 0, 30)
})

local icon_search_button = create_component({
	class_name = "ImageButton",

	Active = true,
	AnchorPoint = Vector2.new(0, .5),
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Position = UDim2.new(1, -40, .5, 0),
	Size = UDim2.new(0, 25, 0, 25),

	Image = "rbxassetid://3926305904",
	ImageRectOffset = Vector2.new(964, 324),
	ImageRectSize = Vector2.new(36, 36),
	ScaleType = Enum.ScaleType.Slice,
	SliceScale = 1
})

local icon_dropdown_symbol = create_component({
	class_name = "ImageLabel",
	-- Props
	Active = true,
	BorderSizePixel = 0,
	BackgroundTransparency = 1,
	Size = UDim2.new(0, 25, 0, 25),
	Rotation = 90,
	Image = "rbxassetid://3926305904",
	ImageRectOffset = Vector2.new(564, 284),
	ImageRectSize = Vector2.new(36, 36),
	ImageColor3 = Color3.fromRGB(255, 255, 255)
})

local icon_checkmark = create_component({
	class_name = "ImageLabel",
	Active = true,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,

	Image = "rbxassetid://3926305904",
	ImageRectOffset = Vector2.new(312, 4),
	ImageRectSize = Vector2.new(24, 24),
	ImageColor3 = Color3.fromRGB(255, 255, 255),

	Size = UDim2.new(0, 20, 0, 20)
})
-- ]]

do
	for _, v in next, { 'KHR UI', 'KHR Notification UI', 'KHR Loader UI', 'KHR Mobile UI' } do
		while (CoreGui:FindFirstChild(v)) do
			CoreGui[v]:Destroy()
			task.wait()
		end
	end
end

-- GUI [[
local main_gui = create_component({
	class_name = "ScreenGui",
	Name = "KHR UI",
	IgnoreGuiInset = true,
	Parent = CoreGui,
	ZIndex = 2
})

local mobile_main_gui = create_component({
	class_name = "ScreenGui",
	Name = "KHR Mobile UI",
	IgnoreGuiInset = true,
	Parent = CoreGui,
	ZIndex = 3
})

local loader_gui = create_component({
	class_name = "ScreenGui",
	Name = "KHR Loader UI",
	IgnoreGuiInset = true,
	Parent = CoreGui,
	ZIndex = 4
})

local notification_gui = create_component({
	class_name = "ScreenGui",
	Name = "KHR Notification UI",
	IgnoreGuiInset = true,
	Parent = CoreGui,
	ZIndex = 5
})
local is_running = true
task.spawn(function()
	while (main_gui:GetPropertyChangedSignal("Parent"):Wait() == CoreGui) do end
	is_running = false
end)

local Library = {
	config = create_config()
}

setmetatable(Library, {
	__index = function (self, key)
		if (tostring(key):lower() == "gui")
		then
			return main_gui
		end

		if (tostring(key):lower() == "running")
		then
			return is_running
		end

		return rawget(self, key)
	end;
})

local config = Library.config:new():load("library.ini", {
	ui_size = '500x325',
	hover = false,
	keybind = Enum.KeyCode.LeftControl
})

local mobile_initialized = false

function Library:Create(name, hide_background)
	hide_background = hide_background == true
	task.spawn(function()
		uwu.Parent = main_gui
		uwu:Play()
		uwu.Ended:Wait()
		uwu:Destroy()
	end)
	-- local default_main_window_size = UDim2.new(0, 500, 0, 325)
	local ui_size = config.ui_size:split('x')
	local default_main_window_size = UDim2.new(0, tonumber(ui_size[1]), 0, tonumber(ui_size[2]))
	local exec_name = (getexecutor or getexecutorname or getidentityexecutor or identifyexecutor or function() return "Unknown" end)()

	local center = workspace.CurrentCamera.ViewportSize/2

	local main_window = create_component({
		class_name = "Frame",

		Active = true,
		-- BackgroundColor3 = Color3.fromRGB(33, 37, 46),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = .2,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Name = "MainWindow",
		Parent = main_gui,
		Size = default_main_window_size,
		Position = UDim2.new(0, center.X - (default_main_window_size.X.Offset/2), 0, center.Y - (default_main_window_size.Y.Offset/2))
	})

	do
		-- local f = Instance.new('Frame')
		-- f.BorderSizePixel = 0
		-- f.Size = UDim2.new(1, 10, 1, 10)
		-- f.Position = UDim2.new(0, -5, 0, -5)
		-- f.BackgroundColor3 = Color3.new(1,1,1)
		-- f.BackgroundTransparency = .5
		-- f.Parent = main_window
		-- f.ZIndex = -3
		local f = Instance.new('UIStroke', main_window)
		f.Color = Color3.new(1, 1, 1)
		f.Thickness = 5
		f.Transparency = 0.5
		f.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local ug = Instance.new('UIGradient', f)
		ug.Enabled = true

		ug.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex('7474bf')),
			ColorSequenceKeypoint.new(1, Color3.fromHex('348ac7'))
		})

		ug.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0)
		})

		create_rounded(f, UDim.new(0, 8))
		task.spawn(function()
			while (Library.running) do
				create_tween(ug, 10, {
					Rotation = 360,
				}).Completed:Wait()
				ug.Rotation = 0
			end
		end)
	end

	Library.Window = main_window
	Library.window = main_window

	local is_enabled = true

	create_rounded(main_window, UDim.new(0, 8))

	-- local main_window_back_border = main_window:Clone()
	-- main_window_back_border.AnchorPoint = Vector2.new(1, 1)
	-- main_window_back_border.Position = UDim2.new(1, 0, 1, 0)
	-- main_window_back_border.Size = UDim2.new(1, 0, 1, 0)
	-- main_window_back_border.ZIndex = -1
	-- -- main_window_back_border.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	-- main_window_back_border.Parent = main_window

	local BLUR = create_component({
		class_name = "ImageLabel",
		-- Props
		Active = true,
		Image = "rbxassetid://143854825",
		ImageColor3 = Color3.new(.01, .01, .01),
		ImageTransparency = 1,
		BackgroundColor3 = Color3.new(),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 100, 1, 100),
		ImageRectSize = Vector2.new(1, 1),
		BorderSizePixel = 0,
		ZIndex = -5,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		Parent = main_gui
	})

	local function do_animation()
		pcall(function()
			main_window.Visible = is_enabled

			if (hide_background) then
				BLUR.Visible = false
				return
			end
			create_tween(BLUR, .5, {
				BackgroundTransparency = is_enabled and .25 or 1,
				ImageTransparency = is_enabled and 0 or 1
			}).Completed:Wait()

			-- create_tween(main_window_back_border, .25, {
			-- 	Position = is_enabled and UDim2.new(1, 5, 1, 5) or UDim2.new(1, 0, 1, 0),
			-- 	Size = is_enabled and UDim2.new(1, 10, 1, 10) or UDim2.new(1, 0, 1, 0)
			-- }).Completed:Wait()

			BLUR.Active = is_enabled
		end)
	end

	task.spawn(do_animation)

	local dbdfb = false
	game:GetService("UserInputService").InputBegan:Connect(function (input)
		if (input.KeyCode == config.keybind and not dbdfb) then
			dbdfb = true
			-- main_window.Visible = not main_window.Visible
			is_enabled = not is_enabled
			do_animation()
			dbdfb = false
		end
	end)

	if (not mobile_initialized) then
		local button = create_component({
			class_name = 'TextButton',
			-- Properties
			AnchorPoint = Vector2.new(1, .5),
			Parent = mobile_main_gui,
			Text = 'Show/Hide',
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(.995, 0, .5, 0),
			Size = UDim2.new(0, 80, 0, 30),
			-- Visible = IsMobile,
			ZIndex = 999
		})

		local function on_touch()
			if (dbdfb) then return end
			dbdfb = true
			-- main_window.Visible = not main_window.Visible
			is_enabled = not is_enabled
			do_animation()
			dbdfb = false
		end

		button.MouseButton1Click:Connect(on_touch)
		button.TouchTap:Connect(on_touch)
	end

	-- titles
	do
		local top_bar = create_component({
			class_name = "Frame",

			Active = true,
			BackgroundTransparency = 1,
			-- BackgroundTransparency = .8,
			-- BackgroundColor3 = Color3.fromRGB(57, 65, 81),
			BackgroundColor3 = Color3.fromRGB(),
			BorderSizePixel = 0,
			Parent = main_window,
			-- Size = UDim2.new(1, 0, 0, 30)
			Size = UDim2.new(1, 0, 0, 25)
		})

		create_rounded(top_bar, UDim.new(0, 8))

		-- create_component({
		-- 	class_name = "Frame",

		-- 	Active = true,
		-- 	BackgroundColor3 = main_window.BackgroundColor3,
		-- 	BorderSizePixel = 0,
		-- 	ClipsDescendants = true,
		-- 	Parent = top_bar,
		-- 	Size = UDim2.new(1, 0, 0, 20),
		-- 	Position = UDim2.new(0, 0, 0, 25)
		-- })

		create_component({
			class_name = "TextLabel",
			Parent = main_window,

			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			RichText = true,
			Text = ("<b>Raz Hub</b> - <b>%s</b>"):format(tostring(name)),
			Size = UDim2.new(0, 50, 0, 20),
			Position = UDim2.new(0, 10, 0, 3),
			TextColor3 = Color3.fromRGB(200, 200, 200),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left
		})

		create_component({
			class_name = "Frame",
			Parent = main_window,

			BackgroundTransparency = .5,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			Position = UDim2.new(0, 0, 0, 24),
			Size = UDim2.new(1, 0, 0, 2)
		})
	end

	local main_page = create_component({
		class_name = "Frame",
		Active = false,

		BackgroundTransparency = 1,
		BorderSizePixel = 0,

		Size = UDim2.new(1, -10, 1, -35),
		Position = UDim2.new(0, 5, 0, 30),

		Parent = main_window,
		ZIndex = 0
	})

	local tab_section = create_component({
		class_name = "Frame",
		Active = true,

		-- BackgroundColor3 = Color3.fromRGB(33, 37, 46),
		-- BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		ClipsDescendants = true,
		-- BackgroundTransparency = 0,
		BackgroundTransparency = .2,
		BorderSizePixel = 0,

		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),

		Parent = create_component({
			class_name = "Frame",
			Active = true,

			BackgroundTransparency = 1,
			BorderSizePixel = 0,

			Size = UDim2.new(1, -10, 1, -35),
			Position = UDim2.new(0, 5, 0, 30),

			Parent = main_window
		}),
		ZIndex = 1
	})

	local tab_container = create_component({
		class_name = "Frame",
		Active = true,

		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0, 0, 0, 5),
		Size = UDim2.new(1, 0, 1, -10),
		Parent = tab_section
	})

	local tab_ui_list_layout = create_component({
		class_name = "UIListLayout",
		-- Props
		Parent = tab_container,
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 2),
		SortOrder = Enum.SortOrder.LayoutOrder
	})

	local tab_button = nil
	local tab_page = nil
	local tab_opened = false

	-- tab sections
	do
		local tab_hitbox = create_component({
			class_name = "Frame",
			Active = true,

			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 13, 1, -30),
			Position = UDim2.new(0, 0, 0, 30),

			Parent = main_window
		})

		local exec_label = create_component({
			class_name = "TextLabel",
			Parent = main_window,

			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = exec_name,
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 3),
			TextColor3 = Color3.fromRGB(200, 200, 200),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right
		})

		do
			if (isfile and not isfile('discord-icon.png')) then
				writefile('discord-icon.png', game:HttpGet('https://clipartcraft.com/images/discord-logo-transparent-better.png'))
			end
		end

		local icon_img = (getcustomasset or getsynasset) and (getcustomasset or getsynasset)('discord-icon.png') or '11529437967'
		local icon = create_component({
			class_name = 'ImageButton',
			-- Props
			BackgroundTransparency = 1,
			-- Image = '11529437967', -- 11529437916
			-- Image = 'rbxassetid://9754913075',
			Image = icon_img,
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(1, (-exec_label.TextBounds.X + -35), 0, 3),
			Parent = main_window
		})

		icon.MouseButton1Click:Connect(function()
			pcall(Library.discord.invite, Library.discord.invite, 'kTVRpqAg3m')
			pcall(setclipboard, 'https://discord.gg/kTVRpqAg3m')
		end)

		local tab_button = create_component({
			class_name = "ImageButton",
			Active = true,

			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "rbxassetid://3926305904",
			ImageRectOffset = Vector2.new(964, 964),
			ImageRectSize = Vector2.new(36, 36),
			Size = UDim2.new(0, 20, 0, 20),
			Parent = main_window,
			Position = UDim2.new(1, -25, 0, 3)
		})

		task.spawn(function()
			local changed = not config.hover
			while (Library.running) do
				if (config.hover ~= changed) then
					changed = not changed
					tab_button.Visible = not config.hover
					exec_label.Position = UDim2.new(0, (tab_button.Visible and -10 or 10), 0, 3)
					icon.Position = UDim2.new(1, -exec_label.TextBounds.X + (tab_button.Visible and -55 or -35), 0, 3)
				end
				wait()
			end
		end)

		local debounce = false

		local function onTabHover(...)
			local is_button = #({...}) == 0
			-- if (debounce or tab_opened or (not config.hover and not is_button)) then return end
			if (debounce or tab_opened) then return end
			debounce = true
			tab_opened = true
			create_tween(tab_section, 0.05, { Size = UDim2.new(0, 150, 1, 0) })
			-- create_tween(tab_hitbox, 0.05, { Size = UDim2.new(0, 150, .8, 19) })
			create_tween(tab_hitbox, 0.05, { Size = UDim2.new(1, 0, 1, -35) }).Completed:Wait()
			task.wait(.25)
			debounce = false
		end

		-- local function onTabLeave()
		-- 	if (debounce or not tab_opened) then return end
		-- 	debounce = true
		-- 	tab_opened = false
		-- 	create_tween(tab_section, 0.05, { Size = UDim2.new(0, 0, 1, 0) })
		-- 	create_tween(tab_hitbox, 0.05, { Size = UDim2.new(0, 13, 1, -35) }).Completed:Wait()
		-- 	task.wait(.25)
		-- 	debounce = false
		-- end

		tab_button.MouseButton1Click:Connect(onTabHover)
		tab_hitbox.MouseEnter:Connect(onTabHover)

		tab_section.MouseLeave:Connect(function()
			if (debounce or not tab_opened) then return end
			debounce = true
			tab_opened = false
			create_tween(tab_section, 0.05, { Size = UDim2.new(0, 0, 1, 0) })
			create_tween(tab_hitbox, 0.05, { Size = UDim2.new(0, 13, 1, -35) }).Completed:Wait()
			task.wait(.25)
			debounce = false
		end)
	end

	do
		-- Drag
		do
			local Camera = workspace.CurrentCamera
			local Stepped = game:GetService("RunService").Stepped
			local is_dragging = false

			local function get_bounds (v2)
				local absolute_size = main_window.AbsoluteSize

				-- local left_bounds = (Camera.ViewportSize.Y - absolute_size.Y) - 35
				local left_bounds = (Camera.ViewportSize.Y - absolute_size.Y)
				local right_bounds = (Camera.ViewportSize.X - absolute_size.X)

				local x = v2.X
				local y = v2.Y

				return ((right_bounds < x and right_bounds) or (x <= 0 and 0) or x),
				((left_bounds < y and left_bounds) or (y <= 0 and 0) or y)
			end

			main_window.InputBegan:Connect(function(input)
				local inset = GuiService:GetGuiInset()
				if (input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					local absolute_position = main_window.AbsolutePosition
					local position = Vector2.new(Mouse.X - absolute_position.X, Mouse.Y - absolute_position.Y)
					if (position.Y > 25) then return end
					local last_position = nil
					is_dragging = true

					while (Library.running and is_dragging)
					do
						local new_absolute_position = main_window.AbsolutePosition
						local x, y = get_bounds(Vector2.new(Mouse.X-position.X,(Mouse.Y-position.Y + inset.Y)))

						if (not last_position)
						then
							last_position = Vector2.new(x, y)
						end

						if (not (new_absolute_position.X == x and new_absolute_position.Y == y) and (Vector2.new(Mouse.X, Mouse.Y ) - last_position).Magnitude > 0)
						then
							create_tween(main_window, 0.05, { Position = UDim2.new(0, x, 0, y) })
							last_position = Vector2.new(Mouse.X, Mouse.Y)
						end

						Stepped:Wait()
					end
				end
			end)

			main_window.InputEnded:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.Focus or input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					is_dragging = false
				end
			end)

			-- task.spawn(function()
			-- 	while (true) do
			-- 		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Wait()
			-- 		local size = workspace.CurrentCamera.ViewportSize
			-- 		if (not Library.running) then return end
			-- 		local absolute_position = (size - main_window.AbsolutePosition) - main_window.AbsoluteSize
			-- 		local x, y = get_bounds(main_window.AbsolutePosition)
			-- 		if (x ~= 0 or y ~= 0) then
			-- 			main_window.Position = UDim2.new(0, x or absolute_position.X, 0, y or absolute_position.Y)
			-- 		end
			-- 	end
			-- end)
		end
	end

	local function create_components(page)
		local Modules = {}

		local function create_container()
			return create_component({
				class_name = "Frame",
				Active = true,
				BorderSizePixel = 0,
				BackgroundTransparency = .8,
				BackgroundColor3 = Color3.fromRGB(),
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0, 30),
				Parent = page
			})
		end

		function Modules:AddLabel(content)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			return function (new_text)
				label.Text = tostring(new_text)
			end
		end

		function Modules:AddSplitLabel(c1,c2)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(c1),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(.5, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local label2 = create_component({
				class_name = "TextLabel",

				AnchorPoint = Vector2.new(.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(c1),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(.5, -20, 1, 0),
				Position = UDim2.new(.73, 10, 0, 0)
			})

			return (function (new_text) label.Text = tostring(new_text) end), (function (new_text) label2.Text = tostring(new_text) end)
		end

		function Modules:AddButton(content, description, cb)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local desc = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(description or ""),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -25, 1, 0),
				Position = UDim2.new(0, 15, 0, 0)
			})

			if (description) then
				-- label.RichText = true
				-- label.Text ..= '\n<i>' .. tostring(description) .. '</i>'
				label.Size = UDim2.new(1, -20, .5, 5)
				desc.Position = UDim2.new(0, 15, 0, 15)
				desc.Size = UDim2.new(1, -25, .5, 0)
			end

			local ins = create_component({
				class_name = "Frame",
				-- Props
				AnchorPoint = Vector2.new(.5, .5),
				BorderSizePixel = 0,
				-- Size = UDim2.new(0, 10, 0, 10),
				Size = UDim2.new(0, 0, 0, 0),
				Parent = container,
				BackgroundTransparency = .5,
				BackgroundColor3 = Color3.fromRGB(95, 103, 110),
				Visible = false
			})

			create_rounded(ins, UDim.new(1, 1))

			container.InputBegan:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
					ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
					ins.Visible = true
					container.BackgroundTransparency = .75
				end
			end)

			container.InputChanged:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
					ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
				end
			end)

			container.InputEnded:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.Focus or input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					ins.Visible = false
					container.BackgroundTransparency = .8
				elseif (input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					task.spawn(function()
						local old = ins:Clone()
						old.Parent = container

						create_tween(old, 1, {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 500, 1, 500)
						})

						task.wait(1)
						old:Destroy()
					end)

					task.spawn(typeof(cb) == "function" and cb or function() end)
				end
			end)
		end

		function Modules:AddToggle(content, toggle, cb)
			local container = create_container()

			create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local ins = create_component({
				class_name = "Frame",
				-- Props
				AnchorPoint = Vector2.new(.5, .5),
				BorderSizePixel = 0,
				-- Size = UDim2.new(0, 10, 0, 10),
				Size = UDim2.new(0, 0, 0, 0),
				Parent = container,
				BackgroundTransparency = .5,
				BackgroundColor3 = Color3.fromRGB(95, 103, 110),
				Visible = false
			})

			local square = create_component({
				class_name = "Frame",

				Active = true,
				Parent = container,
				ClipsDescendants = true,
				BorderSizePixel = 0,
				BackgroundTransparency = .8,
				BackgroundColor3 = Color3.fromRGB(),
				AnchorPoint = Vector2.new(0, .5),
				Position = UDim2.new(1, -30, .5, 0),
				Size = UDim2.new(0, 20, 0, 20)
			})

			local checkmark = icon_checkmark:Clone()
			checkmark.Position = UDim2.new(.5, 0, .5, 0)
			checkmark.AnchorPoint = Vector2.new(.5, .5)
			checkmark.ImageColor3 = Color3.fromRGB(255, 255, 255)
			checkmark.Parent = square

			checkmark.Visible = toggle

			create_rounded(ins, UDim.new(1, 1))
			create_rounded(square, UDim.new(0, 6))

			container.InputBegan:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
					ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
					ins.Visible = true
					container.BackgroundTransparency = .75
				end
			end)

			container.InputChanged:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
					ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
				end
			end)

			container.InputEnded:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.Focus or input.UserInputType == Enum.UserInputType.MouseMovement)
				then
					ins.Visible = false
					container.BackgroundTransparency = .8
				elseif (input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					task.spawn(function()
						local old = ins:Clone()
						old.Parent = container

						create_tween(old, 1, {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 500, 1, 500)
						})

						task.wait(1)
						old:Destroy()
					end)

					toggle = not toggle
					checkmark.Visible = toggle
					task.spawn(typeof(cb) == "function" and cb or function() end, toggle)
				end
			end)

			local function call(t)
				toggle = not (not t)
				checkmark.Visible = toggle
				task.spawn(typeof(cb) == "function" and cb or function() end, toggle)
			end

			call(toggle)

			return call
		end

		function Modules:AddTextBox(content, default, cb)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local textbox = create_component({
				class_name = "TextBox",
				-- Props
				AnchorPoint = Vector2.new(0, .5),
				AutoButtonColor = false,
				ClipsDescendants = true,
				BackgroundTransparency = .8,
				BackgroundColor3 = Color3.fromRGB(),
				BorderSizePixel = 0,
				Parent = container,
				Size = UDim2.new(0, -100, .6, 0),
				Position = UDim2.new(1, -10, .5, 0),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderText = '...',
				Text = default or "",
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
			})

			textbox.Focused:Connect(function()
				if (tab_opened) then return end
				-- create_tween(textbox, .05, { Size = UDim2.new(0, -200, .6, 0) })
			end)

			textbox:GetPropertyChangedSignal("Text"):Connect(function()
				textbox.Size = UDim2.new(0, -(math.min(math.max(textbox.TextBounds.X, 30) + 10, 300)), .6, 0)
			end)

			textbox.FocusLost:Connect(function()
				if (tab_opened) then return end
				-- create_tween(textbox, .05, { Size = UDim2.new(0, -100, .6, 0) })

				task.spawn(cb, textbox.Text)
			end)
		end

		local function create_dropdown_modules(f, is_multi, cb)
			local Modules = {}
			local toggles = {}
			local calls = {}

			function Modules:Add(text, toggle)
				toggle = not (not toggle)
				toggles[text] = toggle

				local container = create_container()
				container.Name = tostring(text)
				container.Parent = f

				create_component({
					class_name = "TextLabel",

					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Parent = container,
					Font = Enum.Font.GothamMedium,
					TextSize = 12,
					Text = tostring(text),
					TextColor3 = Color3.fromRGB(200, 200, 200),
					TextXAlignment = Enum.TextXAlignment.Left,

					Size = UDim2.new(1, -20, 1, 0),
					Position = UDim2.new(0, 10, 0, 0)
				})

				local ins = create_component({
					class_name = "Frame",
					-- Props
					AnchorPoint = Vector2.new(.5, .5),
					BorderSizePixel = 0,
					-- Size = UDim2.new(0, 10, 0, 10),
					Size = UDim2.new(0, 0, 0, 0),
					Parent = container,
					BackgroundTransparency = .5,
					BackgroundColor3 = Color3.fromRGB(95, 103, 110),
					Visible = false
				})

				local square = create_component({
					class_name = "Frame",

					Active = true,
					Parent = is_multi and container or nil,
					ClipsDescendants = true,
					BorderSizePixel = 0,
					BackgroundTransparency = .8,
					BackgroundColor3 = Color3.fromRGB(),
					AnchorPoint = Vector2.new(0, .5),
					Position = UDim2.new(1, -30, .5, 0),
					Size = UDim2.new(0, 20, 0, 20)
				})

				local checkmark = icon_checkmark:Clone()
				checkmark.Position = UDim2.new(.5, 0, .5, 0)
				checkmark.AnchorPoint = Vector2.new(.5, .5)
				checkmark.ImageColor3 = Color3.fromRGB(255, 255, 255)
				checkmark.Parent = square

				checkmark.Visible = toggle

				create_rounded(ins, UDim.new(1, 1))
				create_rounded(square, UDim.new(0, 6))

				container.InputBegan:Connect(function(input)
					if (tab_opened) then return end
					if (input.UserInputType == Enum.UserInputType.MouseMovement)
					then
						local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
						ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
						ins.Visible = true
						container.BackgroundTransparency = .75
					end
				end)

				container.InputChanged:Connect(function(input)
					if (tab_opened) then return end
					if (input.UserInputType == Enum.UserInputType.MouseMovement)
					then
						local Position = (Vector2.new(Mouse.X,Mouse.Y)-container.AbsolutePosition)
						ins.Position = UDim2.new(0, Position.X, 0, Position.Y)
					end
				end)

				container.InputEnded:Connect(function(input)
					if (tab_opened) then return end
					if (input.UserInputType == Enum.UserInputType.Focus or input.UserInputType == Enum.UserInputType.MouseMovement)
					then
						ins.Visible = false
						container.BackgroundTransparency = .8
					elseif (input.UserInputType == Enum.UserInputType.MouseButton1)
					then
						task.spawn(function()
							local old = ins:Clone()
							old.Parent = container

							create_tween(old, 1, {
								BackgroundTransparency = 1,
								Size = UDim2.new(1, 500, 1, 500)
							})

							task.wait(1)
							old:Destroy()
						end)

						toggle = not toggle
						toggles[text] = toggle
						checkmark.Visible = toggle
						task.spawn(typeof(cb) == "function" and cb or function() end, text, toggle)
					end
				end)

				calls[text] = function(t)
					toggle = not (not t)
					toggles[text] = not (not t)
					checkmark.Visible = not (not t)
					task.spawn(typeof(cb) == "function" and cb or function() end, text, not (not t))
				end

				return container
			end

			function Modules:Delete(text)
				if (f:FindFirstChild(tostring(text))) then
					f[tostring(text)]:Destroy()
					toggles[text] = false

					if (is_multi) then
						task.spawn(typeof(cb) == "function" and cb or function() end, text, false)
					end
				end
			end

			function Modules:Set(text, toggle)
				local call = calls[text]

				if (call) then
					call(toggle)
				end
			end

			function Modules:List()
				local list = {}

				for name, bool in next, calls do
					if (not is_multi)
					then
						table.insert(list, name)
					else
						list[name] = bool
					end
				end

				return list
			end

			return Modules
		end

		function Modules:AddDropdown(content, default, is_multi, cb)
			local is_opened = false
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 0, 30),
				Position = UDim2.new(0, 10, 0, 0)
			})

			if (not is_multi) then
				label.RichText = true
				label.Text = ('%s\n <i>%s</i>'):format(tostring(content), tostring(default))
			end

			local dropdown_container = create_component({
				class_name = "ScrollingFrame",

				Active = true,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -10, 0, 240 - 34),
				Position = UDim2.new(0, 5, 0, 35),
				ScrollBarThickness = 0,

				Parent = container
			})

			local UIListLayout = create_component({
				class_name = "UIListLayout",
				-- Props
				Parent = dropdown_container,
				Padding = UDim.new(0, 5),
				VerticalAlignment = 1,
				HorizontalAlignment = 1,
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.Name
			})

			do
				UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					dropdown_container.CanvasSize = UDim2.new(1, -15, 0, UIListLayout.AbsoluteContentSize.Y)
					create_tween(container, 0, { Size = UDim2.new(1, 0, 0, is_opened and math.min(240, (34 + UIListLayout.AbsoluteContentSize.Y) + 10) or 30) })
				end)
			end

			local dropdown_icon = icon_dropdown_symbol:clone()
			dropdown_icon.AnchorPoint = Vector2.new(0, .5)
			dropdown_icon.Position = UDim2.new(1, -20, .5, 0)
			dropdown_icon.Parent = label

			local search_button = icon_search_button:clone()
			search_button.Parent = label

			local search_box = create_component({
				class_name = "TextBox",
				-- Props
				AnchorPoint = Vector2.new(0, .5),
				AutoButtonColor = false,
				ClipsDescendants = true,
				BackgroundTransparency = .8,
				BackgroundColor3 = Color3.fromRGB(),
				BorderSizePixel = 0,
				Parent = label,
				Size = UDim2.new(0, 0, 0, 20),
				Position = UDim2.new(1, -45, .5, 0),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderText = '...',
				Text = '',
				Visible = false,
				Font = Enum.Font.GothamMedium,
				TextSize = 12
			})

			local search_action = false
			local search_closed = true
			local function OnTBClicked()
				if (tab_opened) then return end
				if (not search_action) then
					search_action = true
					search_closed = not search_closed

					if (not search_closed) then
						search_box.Visible = true
					end

					create_tween(search_box, .05, {
						Size = UDim2.new(0, search_closed and 0 or -150,0,20)
					}).Completed:Wait()

					if (search_closed) then
						search_box.Visible = false
					end

					search_action = false
				end
			end

			search_button.MouseButton1Click:Connect(OnTBClicked)

			search_box.Changed:Connect(function()
				if (tab_opened) then return end
				for i,v in next, dropdown_container:GetChildren() do
					if (v:IsA("Frame")) then
						if (search_box.Text == '' or v.Name:lower():find(search_box.Text:lower()) ~= nil) then
							v.Visible = true
						else
							v.Visible = false
						end
					end
				end
			end)

			label.InputBegan:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					is_opened = not is_opened
					create_tween(dropdown_icon, .2, { Rotation = is_opened and 0 or 90 })
					-- print(UIListLayout.AbsoluteContentSize.Y)
					-- print(math.min(240, (34 + UIListLayout.AbsoluteContentSize.Y) + 10))
					create_tween(container, .2, { Size = UDim2.new(1, 0, 0, is_opened and math.min(240, (34 + UIListLayout.AbsoluteContentSize.Y) + 5) or 30) })
				end
			end)

			return create_dropdown_modules(dropdown_container, is_multi, function(option, toggle)
				default = option
				if (not is_multi) then
					is_opened = false
					create_tween(dropdown_icon, 0.2, { Rotation = is_opened and 0 or 90 })
					create_tween(container, 0.2, { Size = UDim2.new(1, 0, 0, is_opened and math.min(240, (34 + UIListLayout.AbsoluteContentSize.Y) + 5) or 30) })
					label.Text = ('%s\n <i>%s</i>'):format(tostring(content), tostring(default))
				end

				task.spawn(cb, default, toggle)
			end)
		end

		function Modules:AddKeybind(content, key, cb)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, 0),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local textbox = create_component({
				class_name = "TextBox",
				-- Props
				AnchorPoint = Vector2.new(0, .5),
				AutoButtonColor = false,
				ClipsDescendants = true,
				BackgroundTransparency = .8,
				BackgroundColor3 = Color3.fromRGB(),
				BorderSizePixel = 0,
				Parent = container,
				Size = UDim2.new(0, -100, .6, 0),
				Position = UDim2.new(1, -10, .5, 0),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderColor3 = Color3.fromRGB(200, 200, 200),
				PlaceholderText = '...',
				Text = tostring(key and key.Name or ""),
				Font = Enum.Font.GothamMedium,
				TextSize = 12
			})

			local focus_lost = true
			local connection;
			local key_value = key
			textbox.Focused:Connect(function()
				if (not focus_lost) then return end
				focus_lost = false
				task.wait()
				if (connection) then return end
				connection = UserInputService.InputBegan:Connect(function(input)
					if (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Focus and input.UserInputType ~= Enum.UserInputType.MouseWheel) then
						connection:Disconnect()
						key = ((input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode) or input.UserInputType).Name
						textbox.Text = key
						textbox:ReleaseFocus()
						key_value = (input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode) or input.UserInputType
						task.spawn(cb, key_value)
						focus_lost = true
						connection = nil
					end
				end)
			end)

			if (typeof(key) ~= "string") then
				pcall(function()
					key = key.Name
				end)
			end

			UserInputService.InputBegan:Connect(function(input, processing)
				if (not Library.running or processing) then return end
				if (focus_lost) then
					if (input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name == key or input.UserInputType.Name == key) then
						task.spawn(cb, key_value)
					end
				end
			end)
		end

		function Modules:AddSubsection(name)
			local container = create_container()

			local label = create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				RichText = true,
				Text = ('<b>%s</b>'):format(name),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 0, 30),
				Position = UDim2.new(0, 10, 0, 0)
			})

			create_component({
				class_name = "ImageLabel",
				Active = false,
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, .5),
				Position = UDim2.new(1, -25, .5, -2),
				Size = UDim2.new(0, 25, 0, 25),
				Image = "rbxassetid://3926305904",
				ImageRectOffset = Vector2.new(84, 204),
				ImageRectSize = Vector2.new(36, 36),
				Parent = label
			})

			local page = create_component({
				-- class_name = "ScrollingFrame",
				class_name = "Frame",

				Active = true,
				AnchorPoint = Vector2.new(.5, 0),
				BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(),
				BackgroundTransparency = .8,
				Size = UDim2.new(1, -20, 0, 0),
				Position = UDim2.new(.5, 0, 0, 30),
				Parent = container,
				Visible = true,
				ScrollBarThickness = 0
			})

			local page_ui_list_layout = create_component({
				class_name = "UIListLayout",
				-- Props
				Parent = page,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder
			})

			local is_opened = false

			page_ui_list_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				-- page.CanvasSize = UDim2.new(1, -15 + page.Size.X.Offset, 0, page_ui_list_layout.AbsoluteContentSize.Y)
				if (is_opened) then
					create_tween(page, 0, { Size = UDim2.new(1, -20, 0, is_opened and page_ui_list_layout.AbsoluteContentSize.Y or 0)})
					create_tween(container, 0, { Size = UDim2.new(1, 0, 0, is_opened and (page_ui_list_layout.AbsoluteContentSize.Y + 35) or 30) })
				end
			end)

			label.InputBegan:Connect(function(input)
				if (tab_opened) then return end
				if (input.UserInputType == Enum.UserInputType.MouseButton1)
				then
					is_opened = not is_opened
					-- container.Size = UDim2.new(1, 0, 0, page_ui_list_layout.AbsoluteContentSize.Y + 20)
					-- create_tween(page, .2, { Size = UDim2.new(1, -20, 0, is_opened and ((234 - 35)) or 0)})
					create_tween(page, .2, { Size = UDim2.new(1, -20, 0, is_opened and page_ui_list_layout.AbsoluteContentSize.Y or 0)})
					-- create_tween(container, .2, { Size = UDim2.new(1, 0, 0, is_opened and 234 or 30) })
					create_tween(container, .2, { Size = UDim2.new(1, 0, 0, is_opened and (page_ui_list_layout.AbsoluteContentSize.Y + 35) or 30) })
				end
			end)

			return create_components(page)
		end

		function Modules:AddSlider(content, def, min, max, cb)
			local container = create_container()
			local absolute_value = max - min

			create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 1, -8),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local counter = create_component({
				class_name = "TextBox",
				-- Props
				BackgroundColor3 = Color3.fromRGB(),
				BackgroundTransparency = .8,
				BorderSizePixel = 0,
				Text = tostring(def),
				Size = UDim2.new(0, -50, 0, 16),
				Position = UDim2.new(1, -10, 0, 3),
				Parent = container,
				TextColor3 = Color3.fromRGB(180, 180, 180),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
			})

			-- create_component({
			-- 	class_name = "TextLabel",
			-- 	-- Props
			-- 	BackgroundTransparency = 1,
			-- 	BorderSizePixel = 0,
			-- 	Text = '%',
			-- 	Size = UDim2.new(1, 0, 0, 15);
			-- 	Position = UDim2.new(0, -15, 0, 3),
			-- 	Parent = container,
			-- 	TextColor3 = Color3.fromRGB(180, 180, 180),
			-- 	TextXAlignment = Enum.TextXAlignment.Right,
			-- 	TextSize = 10
			-- })

			local slider_container = create_component({
				class_name = "TextButton",
				-- Props
				AnchorPoint = Vector2.new(0, 0),
				Active = true,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				BackgroundTransparency = .95,
				BackgroundColor3 = Color3.new(1,1,1),
				-- Size = UDim2.new(0, 400, 0, 8),
				Size = UDim2.new(1, -60, 0, 8),
				Position = UDim2.new(0, 50, 0, 20),
				Text = "",
				Parent = container,
			})

			local pointer = create_component({
				class_name = "Frame",
				-- Props
				AnchorPoint = Vector2.new(.5, 0),
				BorderSizePixel = 0,
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromRGB(200, 200, 200),
				Size = UDim2.new(0, 8, 0, 8),
				Position = UDim2.new(0, 0, 0, 0),
				Parent = slider_container
			})

			create_rounded(slider_container, UDim.new(1, 0))
			create_rounded(pointer, UDim.new(1, 0))

			pointer.Position = UDim2.new(
				0,
				math.clamp(
					(
						def / absolute_value
							* slider_container.AbsoluteSize.X
						- min/absolute_value
							* slider_container.AbsoluteSize.X
					),
					0,
					slider_container.AbsoluteSize.X
				),
				0,
				0
			)

			local mousedown = false
			local GuiInset = game:GetService("GuiService"):GetGuiInset()

			local function on_change(property)
				pcall(function()
					local n = tonumber(counter.Text)
					if (typeof(n) == "number" and (typeof(property) == "boolean" or (property == "Text" and not UserInputService:GetFocusedTextBox()))) then
						if (n > max or n < min) then
							counter.Text = tostring(math.min(math.max(math.floor(n), min), max))
							return;
						end

						def = n

						create_tween(pointer, .05, { Position = UDim2.new(
							0,
							math.clamp(
								(
									(n / absolute_value)
										* slider_container.AbsoluteSize.X
									- (min/absolute_value)
										* slider_container.AbsoluteSize.X
								),
								0,
								slider_container.AbsoluteSize.X
							),
							0,
							0
							) })

						if (typeof(cb) == "function") then
							cb(n)
						end
					elseif (not property or (property == "Text" and not UserInputService:GetFocusedTextBox())) then
						counter.Text = tostring(def)
					end
				end)
			end

			counter.FocusLost:Connect(on_change)
			counter.Changed:Connect(on_change)

			local mb1 = Enum.UserInputType.MouseButton1

			slider_container.MouseButton1Down:Connect(function(_input)
				if (not mousedown and not tab_opened) then
					mousedown = true

					local curr = 0

					while (mousedown and Library.running) do
						local X = (Mouse.X - slider_container.AbsolutePosition.X) + GuiInset.X
						local num = math.floor(math.clamp(X/(slider_container.AbsoluteSize.X) * absolute_value + min, min, max))

						if (curr ~= num) then
							curr = num
							counter.Text = tostring(num)
						end

						RunService.Stepped:Wait()
					end

					mousedown = false
				end
			end)

			slider_container.InputEnded:Connect(function(_input)
				if (_input.UserInputType == mb1) then
					mousedown = false
				end
			end)

			slider_container.MouseButton1Up:Connect(function(_input)
				mousedown = false
			end)
		end

		function Modules:AddColorPicker(content, default, cb)
			local container = create_container()

			-- container.Size = UDim2.new(1, 0, 0, 265)

			local debounce = false
			local closed = true
			container.InputBegan:Connect(function(input)
				if (not debounce and input.UserInputType == Enum.UserInputType.MouseButton1) then
					if (-(container.AbsolutePosition.Y - Mouse.Y) <= 30) then
						debounce = true
						closed = not closed

						create_tween(container, .2, {
							Size = UDim2.new(1, 0, 0, closed and 30 or 265)
						}).Completed:Wait()
						debounce = false
					end
				end
			end)

			create_component({
				class_name = "TextLabel",

				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Text = tostring(content),
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextXAlignment = Enum.TextXAlignment.Left,

				Size = UDim2.new(1, -20, 0, 30),
				Position = UDim2.new(0, 10, 0, 0)
			})

			local picker_container = create_component({
				class_name = "Frame",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = container,
				Position = UDim2.new(0, 10, 0, 35),
				Size = UDim2.new(1, -20, 0, 220)
			})

			local hue_frame = create_component({
				class_name = "Frame",
				BackgroundColor3 = Color3.new(1,1,1),
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(0, .5),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 200, 0, 200),
				Parent = picker_container,
				Position = UDim2.new(0, 10, .5, 0)
			})

			local tint_frame = create_component({
				class_name = "Frame",
				AnchorPoint = Vector2.new(0, .5),
				BackgroundColor3 = Color3.fromHSV(({Color3.toHSV(default)})[1], 1, 1),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 200, 0, 200),
				Parent = picker_container,
				Position = UDim2.new(0, 10, .5, 0)
			})

			local shade_frame = create_component({
				class_name = "Frame",
				BackgroundColor3 = Color3.new(),
				AnchorPoint = Vector2.new(0, .5),
				BorderSizePixel = 0,
				Size = UDim2.new(0, 200, 0, 200),
				Parent = picker_container,
				Position = UDim2.new(0, 10, .5, 0)
			})

			create_component({
				class_name = "UIGradient",
				Color = ColorSequence.new{
					ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
					ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
				},
				Rotation = 270,
				Parent = shade_frame,
				Transparency = NumberSequence.new{
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1)
				}
			})

			create_component({
				class_name = "UIGradient",
				-- Color = ColorSequence.new{
				-- 	ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
				-- 	ColorSequenceKeypoint.new(1, Color3.new(1,1,1))
				-- },
				Rotation = 180,
				Parent = tint_frame,
				Transparency = NumberSequence.new{
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1)
				}
			})

			local r_text = create_component({
				class_name = "TextLabel",
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = .8,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 40, 0, 20),
				Position = UDim2.new(1, -40, 0, 10),
				Parent = picker_container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.new(1,1,1),
				Text = tostring(math.floor(default.R * 255))
			})

			do
				local text = r_text:Clone()
				text.Parent = picker_container
				text.Text = "Red"
				text.Size = UDim2.new(0, 60, 0, 20)
				text.Position = UDim2.new(1, -110, 0, 10)
			end

			local g_text = create_component({
				class_name = "TextLabel",
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = .8,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 40, 0, 20),
				Position = UDim2.new(1, -40, 0, 45),
				Parent = picker_container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.new(1,1,1),
				Text = tostring(math.floor(default.G * 255))
			})

			do
				local text = g_text:Clone()
				text.Parent = picker_container
				text.Text = "Green"
				text.Size = UDim2.new(0, 60, 0, 20)
				text.Position = UDim2.new(1, -110, 0, 45)
			end

			local b_text = create_component({
				class_name = "TextLabel",
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = .8,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 40, 0, 20),
				Position = UDim2.new(1, -40, 0, 80),
				Parent = picker_container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.new(1,1,1),
				Text = tostring(math.floor(default.B * 255))
			})

			do
				local text = b_text:Clone()
				text.Parent = picker_container
				text.Text = "Blue"
				text.Size = UDim2.new(0, 60, 0, 20)
				text.Position = UDim2.new(1, -110, 0, 80)
			end

			local hex_format = ('%02X%02X%02X')

			local hex_text = create_component({
				class_name = "TextLabel",
				BackgroundColor3 = Color3.new(),
				BackgroundTransparency = .8,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 65, 0, 20),
				Position = UDim2.new(1, -65, 0, 115),
				Parent = picker_container,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.new(1,1,1),
				Text = '#' .. hex_format:format(tonumber(r_text.Text), tonumber(g_text.Text), tonumber(b_text.Text))
			})

			do
				local text = b_text:Clone()
				text.Parent = picker_container
				text.Text = "Hex"
				text.Size = UDim2.new(0, 40, 0, 20)
				text.Position = UDim2.new(1, -110, 0, 115)
			end

			local color_preview = create_component({
				class_name = "Frame",

				Active = true,
				BackgroundColor3 = default,
				BorderSizePixel = 0,
				Parent = container,
				Size = UDim2.new(0, 110, 0, 20),
				-- Position = UDim2.new(1, -120, 0, 115)
				Position = UDim2.new(1, -120, 0, 5)
			})

			local hue_bar = create_component({
				class_name = "Frame",
				AnchorPoint = Vector2.new(0, .5),
				BackgroundColor3 = Color3.new(1,1,1),
				BackgroundTransparency = 0,
				Parent = picker_container,
				BorderSizePixel = 0,
				Size = UDim2.new(0, 30, 0, 200),
				Position = UDim2.new(0, 240, .5, 0)
			})

			local colorseq = {}
			for i=0,1,.1 do
				table.insert(colorseq, ColorSequenceKeypoint.new(i, Color3.fromHSV(i, 1, 1)))
			end

			create_component({
				class_name = "UIGradient",
				Color = ColorSequence.new(colorseq),
				Rotation = 90,
				Parent = hue_bar
			})

			local Stepped = game:GetService("RunService").Stepped
			local h,s,v = Color3.toHSV(default)
			local inset = GuiService:GetGuiInset()
			do
				local pointer = icon_dropdown_symbol:Clone()
				pointer.Parent = hue_bar
				pointer.Position = UDim2.new(1, 0, ({Color3.toHSV(default)})[1], 0)
				local is_mouse_down = false
				hue_bar.InputBegan:Connect(function(input)
					if (input.UserInputType == Enum.UserInputType.MouseButton1) then
						is_mouse_down = true

						local old = {
							r = default.R,
							g = default.G,
							b = default.B
						}

						while (Library.running and is_mouse_down) do
							local new_h = math.clamp(Mouse.Y - hue_bar.AbsolutePosition.Y, 0, hue_bar.AbsoluteSize.Y) / hue_bar.AbsoluteSize.Y
							if (new_h ~= h) then
								h = new_h
								create_tween(pointer, .05, { Position = UDim2.new(1, 0, h, -12) })
							end
							default = Color3.fromHSV(h,s,v)
							if (old.r ~= default.R or old.g ~= default.G or old.b ~= default.B) then
								create_tween(pointer, .05, { Position = UDim2.new(1, 0, h, -12) })
								old = {
									r = default.R,
									g = default.G,
									b = default.B
								}
								r_text.Text = tostring(math.floor(old.r * 255))
								g_text.Text = tostring(math.floor(old.g * 255))
								b_text.Text = tostring(math.floor(old.b * 255))
								tint_frame.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
								color_preview.BackgroundColor3 = Color3.fromHSV(h,s,v)
								hex_text.Text = '#' .. hex_format:format(tonumber(r_text.Text), tonumber(g_text.Text), tonumber(b_text.Text))
								task.spawn(cb, default)
							end
							Stepped:Wait()
						end
					end
				end)

				hue_bar.InputEnded:Connect(function(input)
					if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Focus) then
						is_mouse_down = false
					end
				end)
			end

			do
				local is_mouse_down = false
				hue_frame.InputBegan:Connect(function(input)
					if (input.UserInputType == Enum.UserInputType.MouseButton1) then
						is_mouse_down = true
						local absolute_size = hue_frame.AbsoluteSize

						local old = {
							r = default.R,
							g = default.G,
							b = default.B
						}

						while (Library.running and is_mouse_down) do
							local absolute_position = hue_frame.AbsolutePosition
							s,v = math.clamp(Mouse.X - absolute_position.X, 0, absolute_size.X) / absolute_size.X, 1 - math.clamp(Mouse.Y - absolute_position.Y, 0, absolute_size.Y) / absolute_size.Y
							default = Color3.fromHSV(h,s,v)
							if (old.r ~= default.R or old.g ~= default.G or old.b ~= default.B) then
								old = {
									r = default.R,
									g = default.G,
									b = default.B
								}
								r_text.Text = tostring(math.floor(old.r * 255))
								g_text.Text = tostring(math.floor(old.g * 255))
								b_text.Text = tostring(math.floor(old.b * 255))
								hex_text.Text = '#' .. hex_format:format(tonumber(r_text.Text), tonumber(g_text.Text), tonumber(b_text.Text))
								color_preview.BackgroundColor3 = Color3.fromHSV(h,s,v)

								task.spawn(cb, default)
							end

							Stepped:Wait()
						end
					end
				end)

				hue_frame.InputEnded:Connect(function(input)
					if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Focus) then
						is_mouse_down = false
					end
				end)
			end
		end

		return Modules
	end

	local Modules = {}

	local page_count = 0
	local tab_settings = nil

	function Modules:AddPage(tab_name)
		local page = create_component({
			class_name = "ScrollingFrame",

			Active = true,
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = main_page,
			Visible = tab_page == nil and tab_name ~= "UI Settings",
			ScrollBarThickness = 0
		})

		local page_ui_list_layout = create_component({
			class_name = "UIListLayout",
			-- Props
			Parent = page,
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder
		})

		page_ui_list_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			page.CanvasSize = UDim2.new(1, -15 + page.Size.X.Offset, 0, page_ui_list_layout.AbsoluteContentSize.Y)
		end)

		local btn = create_component({
			class_name = "TextButton",

			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(20, 20, 20),
			BackgroundTransparency = .1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -10, 1, 0),
			Position = UDim2.new(0, 5, 0, 0),
			-- Parent = tab_section,
			Parent = create_component({
				class_name = "Frame",
				BorderSizePixel = 0,
				BackgroundTransparency = 1,
				Parent = tab_container,
				Size = UDim2.new(1, 0, 0, 24)
			}),
			Text = ''
		})

		create_component({
			class_name = 'TextLabel',

			-- Properties
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = tab_name,
			TextColor3 = Color3.fromRGB(180, 180, 180),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			Parent = btn
		})

		btn.MouseButton1Click:Connect(function()
			if (tab_page)
			then
				tab_button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				tab_button.BackgroundTransparency = .1
				tab_page.Visible = false
			end

			page.Visible = true
			tab_page = page
			tab_button = btn
			tab_button.BackgroundTransparency = 0
			tab_button.BackgroundColor3 = Color3.fromRGB(48, 55, 79)
		end)

		if (not tab_page and tab_name ~= "UI Settings") then
			tab_page = page
			tab_button = btn
			tab_button.BackgroundColor3 = Color3.fromRGB(48, 55, 79)
			tab_button.BackgroundTransparency = 0
		else
			if (tab_name == "UI Settings") then
				tab_settings = btn
			end
			-- btn.BackgroundColor3 = Color3.fromRGB(41, 45, 59)
			btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			btn.BackgroundTransparency = .1
		end

		if (tab_settings) then
			tab_settings.Parent.Parent = nil
			tab_settings.Parent.Parent = tab_container
		end

		page_count += 1;

		if (page_count >= 9)
		then
			tab_ui_list_layout.VerticalAlignment = Enum.VerticalAlignment.Center
		end

		return create_components(page)
	end

	do
		local ui_settings_page = Modules:AddPage("UI Settings")
		do
			-- local ui_sizes = {
			-- 	"470x270",
			-- 	"470x337",
			-- 	"600x270",
			-- 	"600x337"
			-- }

			ui_settings_page:AddKeybind("UI Show/Hide Keybind", config.keybind, function (key)
				task.wait()
				config:set("keybind", key)
			end)

			if IsMobile then
				config:set('hover', false)
			end

			-- if not IsMobile then
			-- 	ui_settings_page:AddToggle("Hover On Left", config.hover, function (t)
			-- 		config:set("hover", t)
			-- 	end)
			-- end

			local function resize_ui()
				create_tween(main_window, .25, {
					Size = default_main_window_size,
				})

				create_tween(main_page, .25, {
					Size = UDim2.new(1, -10, 0, (tonumber(ui_size[2]) - 35))
				})
			end

			ui_settings_page:AddSlider("Width", default_main_window_size.Width.Offset, 470, 800, function(n)
				ui_size[1] = tostring(n)
				default_main_window_size = UDim2.new(0, tonumber(ui_size[1]), 0, tonumber(ui_size[2]))
				config:set("ui_size", ('%sx%s'):format(ui_size[1], ui_size[2]))
				resize_ui()
			end)

			ui_settings_page:AddSlider("Height", default_main_window_size.Height.Offset, 270, 800, function(n)
				ui_size[2] = tostring(n)
				default_main_window_size = UDim2.new(0, tonumber(ui_size[1]), 0, tonumber(ui_size[2]))
				config:set("ui_size", ('%sx%s'):format(ui_size[1], ui_size[2]))
				resize_ui()
			end)

			main_page.Size = UDim2.new(1, -10, 0, (main_window.AbsoluteSize.Y - 35))
		end
	end

	return Modules
end

do
	local notifications = {}

	function Library:Notify(title, content, duration)
		title = type(title) ~= "nil" and tostring(title) or tostring("Untitled; Line: " .. debug.getinfo(2).currentline)
		content = type(content) ~= "nil" and tostring(content) or tostring("Untitled; Line: " .. debug.getinfo(2).currentline)

		local count = #notifications

		local holder = create_component({
			class_name = "Frame",
			-- Props
			Active = true,
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Parent = notification_gui,
			Size = UDim2.new(0, 300, 0, 100),
			Position = UDim2.new(1, 300, 1, -(((count) * 105) + 10))
		})

		create_component({
			class_name = "TextLabel",
			-- Props
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = holder,
			Size = UDim2.new(1, -10, 0, 20),
			Position = UDim2.new(0, 10, 0, 5),
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			RichText = true,
			Text = "<b>" .. title .. "</b>",
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextXAlignment = Enum.TextXAlignment.Left
		})

		create_component({
			class_name = "Frame",
			-- Props
			Active = true,
			-- BackgroundColor3 = Color3.fromRGB(44, 49, 66),
			BackgroundTransparency = .8,
			BackgroundColor3 = Color3.new(.5, .5, .5),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 2),
			Position = UDim2.new(0, 0, 0, 25),
			Parent = holder
		})

		create_component({
			class_name = "TextLabel",
			-- Props
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -20, 1, -30),
			Position = UDim2.new(0, 10, 0, 30),
			Text = content,
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			Parent = holder,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top
		})

		notifications[#notifications + 1] = holder

		create_rounded(holder, UDim.new(0, 6))

		create_tween(holder, .25, {
			Position = UDim2.new(1, -10, 1, -(((count) * 105) + 10))
		})

		local M = {}
		function M:Dismiss()
			if (table.find(notifications, holder) == nil) then return end
			create_tween(holder, .05, {
				-- Position = UDim2.new(1, 500, 1, -(((table.find(notifications, holder) - 1) * 105) + 10))
				Size = UDim2.new(0, 0, 0, 0)
			})

			holder:ClearAllChildren()

			table.remove(notifications, table.find(notifications, holder))

			for index, instance in next, notifications do
				create_tween(instance, .25, {
					Position = UDim2.new(1, -5, 1, -(((index - 1) * 105) + 10))
				})
			end

			wait(.5)

			holder:Destroy()
		end

		if (duration) then
			task.delay(duration, M.Dismiss)
		else
			create_component({
				class_name = "TextButton",
				-- Props
				Active = true,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamMedium,
				TextSize = 18,
				Parent = holder,
				Text = "×",
				TextColor3 = Color3.fromRGB(180, 180, 180),
				Size = UDim2.new(0, 20, 0, 20),
				Position = UDim2.new(1, -25, 0, 3)
			}).MouseButton1Click:Connect(M.Dismiss)
		end

		return M
	end

	function Library:Verification(content, seconds, callback)
		local MainFrame = create_component({
			class_name = "Frame",
			-- Properties
			AnchorPoint = Vector2.new(.5, .5),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(33, 37, 46),
			Parent = notification_gui,
			Position = UDim2.new(.5, 0, .5, 0),
			Size = UDim2.new(0, 300, 0, 100),
		})

		create_rounded(MainFrame, UDim.new(0, 5))

		local YesButton = create_component({
			class_name = "TextButton",
			-- Properties
			Parent = MainFrame,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(0, 255, 0),
			BackgroundTransparency = .8,
			Position = UDim2.new(0, 10, 1, -35),
			Size = UDim2.new(.5, -50, 0, 25),
			Text = "",
		})

		create_component({
			class_name = "ImageLabel",
			-- Properties
			Active = true,
			Parent = YesButton,
			AnchorPoint = Vector2.new(.5, .5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(.5, 0, .5, 0),
			Size = UDim2.new(0, 20, 0, 20),

			Image = "rbxassetid://3926305904",
			ImageRectOffset = Vector2.new(284, 924),
			ImageRectSize = Vector2.new(36, 36),
			ScaleType = Enum.ScaleType.Slice,
		})

		create_rounded(YesButton, UDim.new(0, 5))

		local NoButton = create_component({
			class_name = "TextButton",
			-- Properties
			Parent = MainFrame,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(255, 0, 0),
			BackgroundTransparency = .8,
			Position = UDim2.new(1, -110, 1, -35),
			Size = UDim2.new(.5, -50, 0, 25),
			Text = ""
		})

		create_component({
			class_name = "ImageLabel",
			-- Properties
			Parent = NoButton,
			AnchorPoint = Vector2.new(.5, .5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(.5, 0, .5, 0),
			Size = UDim2.new(0, 20, 0, 20),

			Image = "rbxassetid://3926305904",
			ImageRectOffset = Vector2.new(4, 4),
			ImageRectSize = Vector2.new(24, 24),
			ScaleType = Enum.ScaleType.Slice,
		})

		create_rounded(NoButton, UDim.new(0, 5))

		local Line = create_component({
			class_name = "Frame",
			-- Properties
			Parent = create_component({
				class_name = "Frame",
				-- Properties
				Parent = MainFrame,
				Position = UDim2.new(0, 10, 1, -7),
				Size = UDim2.new(1, -20, 0, 5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0
			}),
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, 5)
		})

		create_rounded(create_component({
			class_name = "TextLabel",
			-- Properties
			Active = true,
			BackgroundColor3 = Color3.fromRGB(),
			BackgroundTransparency = .8,
			Size = UDim2.new(1, -10, 1, -50),
			Position = UDim2.new(0, 5, 0, 5),
			Parent = MainFrame,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextWrapped = true,
			Text = tostring(content)
		}), UDim.new(0, 5))

		create_rounded(Line, UDim.new(0, 5))

		local can_break = false

		task.spawn(function()
			NoButton.MouseButton1Click:Wait()
			can_break = true
			callback(false, true)
		end)

		task.spawn(function()
			YesButton.MouseButton1Click:Wait()
			can_break = true
			callback(true, false)
		end)

		task.delay(seconds, function()
			can_break = true
		end)

		local t = tick()
		while (Library.running) do
			if (can_break) then break end
			Line.Size = UDim2.new(math.max(0, (seconds - (tick()-t)))/seconds, 0, 0, 5)
			task.wait()
		end

		MainFrame:Destroy()
	end
end

function Library:Loader()
	local Modules = {}
	local loading = true
	local center = workspace.CurrentCamera.ViewportSize/2
	-- local default_main_window_size = UDim2.new(0, 400, 0, 100)
	local default_main_window_size = UDim2.new(0, 400, 0, 100)

	local main_window = create_component({
		class_name = "Frame",

		Active = true,
		BackgroundColor3 = Color3.fromRGB(33, 37, 46),
		BackgroundTransparency = .2,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Name = "MainWindow",
		Parent = loader_gui,
		Size = UDim2.new(),
		-- Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.new(0, center.X, 0, center.Y)
	})

	do
		local f = Instance.new('UIStroke', main_window)
		f.Color = Color3.new(1, 1, 1)
		f.Thickness = 5
		f.Transparency = 0.5
		f.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local ug = Instance.new('UIGradient', f)
		ug.Enabled = true

		ug.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex('7474bf')),
			ColorSequenceKeypoint.new(1, Color3.fromHex('348ac7'))
		})

		ug.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 1),
			NumberSequenceKeypoint.new(0.8, 1),
			NumberSequenceKeypoint.new(1, 0)
		})

		create_rounded(f, UDim.new(0, 8))
		task.spawn(function()
			while (Library.running and main_window:IsDescendantOf(game)) do
				create_tween(ug, 10, {
					Rotation = 360,
				}).Completed:Wait()
				ug.Rotation = 0
			end
			-- rconsolename('Krnl')
			-- rconsoleinfo('yay!')
		end)
	end

	create_rounded(main_window, UDim.new(0, 6))

	local title = create_component({
		class_name = "TextLabel",

		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "Title",
		Parent = main_window,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 0, 5),
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local credits = create_component({
		class_name = "TextLabel",

		Active = true,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "Credits",
		Parent = main_window,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 1, -25),
		TextXAlignment = Enum.TextXAlignment.Right
	})

	-- create_tween(main_window, .5, {
	-- 	Size = default_main_window_size,
	-- 	Position = UDim2.new(0, center.X - (default_main_window_size.X.Offset/2), 0, center.Y - (default_main_window_size.Y.Offset/2))
	-- }).Completed:Wait()

	create_tween(main_window, .5, {
		Size = default_main_window_size,
		Position = UDim2.new(0, center.X - (default_main_window_size.X.Offset/2), 0, center.Y - (default_main_window_size.Y.Offset/2))
	}).Completed:Wait()

	title.Text = "Raz Hub"
	credits.Text = "Developed by Razzles"

	local dot = create_component({
		class_name = "Frame",

		Active = true,
		BackgroundTransparency = .25,
		BackgroundColor3 = Color3.new(1,1,1),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 5, 0, 5),
		Position = UDim2.new(1, -30, 0, 20),
		Parent = main_window
	})

	create_rounded(dot, UDim.new(1, 0))

	local dot2 = dot:Clone()
	dot2.Position = UDim2.new(1, -40, 0, 20)

	local dot3 = dot:Clone()
	dot3.Position = UDim2.new(1, -50, 0, 20)

	dot2.Parent = main_window
	dot3.Parent = main_window

	local frame = create_component({
		class_name = "Frame",

		Active = true,
		AnchorPoint = Vector2.new(0, .5),
		BackgroundTransparency = .85,
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.new(0, 10, .5, 0),
		Parent = main_window
	})

	local message = create_component({
		class_name = "TextLabel",

		Active = true,
		AnchorPoint = Vector2.new(0, .5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "Message",
		Parent = main_window,
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Size = UDim2.new(1, -30, 0, 50),
		Position = UDim2.new(0, 20, .5, 0),
		TextXAlignment = Enum.TextXAlignment.Left
	})

	local loop_done = false
	task.spawn(function()
		local seq = {
			{ dot3, UDim2.new(1, -50, 0, 10) },
			{ dot2, UDim2.new(1, -50, 0, 20) },
			{ dot, UDim2.new(1, -40, 0, 20) },
			{ dot3, UDim2.new(1, -40, 0, 10) },
			{ dot2, UDim2.new(1, -50, 0, 10) },
			{ dot, UDim2.new(1, -50, 0, 20) },
			{ dot3, UDim2.new(1, -30, 0, 10) },
			{ dot2, UDim2.new(1, -40, 0, 10) },
			{ dot, UDim2.new(1, -50, 0, 10) },
			{ dot3, UDim2.new(1, -30, 0, 20) },
			{ dot2, UDim2.new(1, -30, 0, 10) },
			{ dot, UDim2.new(1, -40, 0, 10) },
			{ dot3, UDim2.new(1, -40, 0, 20) },
			{ dot2, UDim2.new(1, -30, 0, 20) },
			{ dot, UDim2.new(1, -30, 0, 10) },
			{ dot3, UDim2.new(1, -50, 0, 20) },
			{ dot2, UDim2.new(1, -40, 0, 20) },
			{ dot, UDim2.new(1, -30, 0, 20) },
		}

		while (Library.running and loading) do
			local i = 0
			for _, data in pairs(seq) do
				create_tween(data[1], .5, {
					Position = data[2]
				})

				i += 1;

				if (i == 3) then i = 0; task.wait(1) end
				if (not (Library.running and loading)) then break end
				task.wait(.2)
			end
		end

		loop_done = true
	end)

	function Modules:done()
		loading = false
		local center = workspace.CurrentCamera.ViewportSize/2

		while (not loop_done) do task.wait() end

		title.Text = ""
		credits.Text = ""

		dot:Destroy()
		dot2:Destroy()
		dot3:Destroy()
		message:Destroy()
		frame:Destroy()

		create_tween(main_window, .5, {
			Size = UDim2.new(),
			Position = UDim2.new(0, center.X, 0, center.Y)
		}).Completed:Wait()

		main_window:Destroy()
	end

	function Modules:set(text)
		message.Text = tostring(text)
	end

	return Modules
end

--  if (#unsupported_functions ~= 0) then
--  	task.delay(0.1, function()
--  		Library:Notify(("Executor is %s UNC supported"):format((functions_checked - #unsupported_functions) >= math.ceil(functions_checked / 2) and "mostly" or "barely"), "Unsupported functions has been either added for compatibility or missing.", 5)
-- 	end)
-- 	Library:Notify(" ", table.concat(unsupported_functions, ", "))
--  end
-- getgenv().Library = Library
-- runkhr()
-- loader:set("yo")
-- rconsoleinfo(tostring(Library.running))

-- local lib = Library:Create("???", true)
-- lib:AddPage('test')
-- task.wait(10)
-- local loader = Library:Loader()
-- loader:set('Lorem ipsum dolor sit amet...')
-- task.wait(5)
-- loader:done()
-- do
-- 	local ESPs = {
-- 		Chams = false;
-- 		Names = false;
-- 		Quads = false;
-- 		Tracers = false;
-- 		TeamCheck = false;

-- 		Connections = {};
-- 		Library = nil; -- ESPs.Library = lib

-- 		Color = Color3.fromRGB(113, 139, 233);
-- 		DefaultColor = Color3.fromRGB(113, 139, 233);

-- 		Rainbow = false;
-- 		TracersPlacement = "Center";
-- 	}

-- 	local Aimbot = {
-- 		Enabled = false,
-- 		Key = Enum.UserInputType.MouseButton2,
-- 		Sensitivity = 25/100,
-- 		Target = "HumanoidRootPart",
-- 		TeamCheck = false,
-- 		WallCheck = false
-- 	}

-- 	local FOV = {
-- 		Enabled = false,
-- 		Size = 200,
-- 		ShowPlayer = false
-- 	}

-- local Window = Library:Create("Anime Defenders")

-- local Client = Window:AddPage("Client")
-- 	local u_esps, u_aimbot, u_fov = ESPs, Aimbot, FOV

-- 	u_esps.Library = Library

-- 	local esps_tab = Window:AddPage("ESPs")
-- 	do
-- 		for i,v in pairs({"Names", "Chams", "Quads", "Tracers"}) do
-- 			esps_tab:AddToggle(v, false, function(t)
-- 				u_esps[table.concat(v:split(' '), '')] = t
-- 			end)
-- 		end

-- 		local esps_settings = esps_tab:AddSubsection("Settings")
-- 		do
-- 			esps_settings:AddToggle("Rainbow Color", false, function(t)
-- 				u_esps.Rainbow = t
-- 			end)

-- 			esps_settings:AddColorPicker("ESPs Color Picker", ESPs.DefaultColor, function(color)
-- 				u_esps.DefaultColor = color
-- 			end)

-- 			esps_settings:AddToggle("Tracers to the bottom of Root Part", false, function(t)
-- 				u_esps.TracersPlacement = t and "Bottom" or "Center"
-- 			end)

-- 			esps_settings:AddToggle("Team Check", false, function(t)
-- 				u_esps.TeamCheck = t
-- 			end)
-- 		end
-- 	end

-- 	local fov_tab = Window:AddPage("FOV")
-- 	do
-- 		for i,v in pairs({"Enabled", "Show Player"}) do
-- 			fov_tab:AddToggle(v, false, function(t)
-- 				u_fov[table.concat(v:split(' '), '')] = t
-- 			end)
-- 		end

-- 		fov_tab:AddSlider("Size", 200, 100, 1000, function(n)
-- 			u_fov.Size = n
-- 		end)
-- 	end

-- 	local aimbot_tab = Window:AddPage("Aimbot")
-- 	do
-- 		aimbot_tab:AddToggle("Enabled", false, function(t)
-- 			u_aimbot.Enabled = t
-- 		end)

-- 		aimbot_tab:AddSlider("Sensitivity", 25, 0, 100, function(n)
-- 			u_aimbot.Sensitivity = math.floor(n/100)
-- 		end)

-- 		aimbot_tab:AddKeybind("Key", Enum.UserInputType.MouseButton2, function(key)
-- 			u_aimbot.Key = key
-- 		end)

-- 		do
-- 			local aimbot = aimbot_tab:AddDropdown("Aim Target", u_aimbot.Target, false, function(option)
-- 				u_aimbot.Target = option
-- 			end)

-- 			aimbot:Add("HumanoidRootPart")
-- 			aimbot:Add("Head")
-- 		end

-- 		aimbot_tab:AddToggle("Team Check", false, function(t)
-- 			u_aimbot.TeamCheck = t
-- 		end)

-- 		aimbot_tab:AddToggle("Wall Check", false, function(t)
-- 			u_aimbot.WallCheck = t
-- 		end)
-- 	end
-- end

-- return Library

-- setting up functions for testing when not obfuscated
if not LPH_OBFUSCATED then  -- set these if not obfuscated so your script can run without obfuscation for when you are testing
    LPH_NO_VIRTUALIZE = function(...) return (...) end;
    LPH_JIT_MAX = function(...) return (...) end;
    LPH_JIT_ULTRA = function(...) return (...) end;
end

LPH_NO_VIRTUALIZE(function()
if (game:IsLoaded() or game.Loaded:Wait()) then end
local is_testing = false

-- _G.KHR_DEBUG = false
_G.KHR_DEBUGLEVEL = 0
local console_opened = false
getgenv().print_debug = function (level, ...)
	if (not _G.KHR_DEBUG or _G.KHR_DEBUGLEVEL ~= level) then return end
	local response = ""

	for i,v in next, {...} do
		if (response ~= "") then response ..= " " end
		response ..= tostring(v)
	end

	if (not rconsoleinfo and rconsolecreate and rconsoleprint) then
		getgenv().rconsoleinfo = function(s)
			rconsolecreate()
			rconsoleprint(('[*]: %s\n'):format(s))
		end
	end
	if (rconsoleinfo) then
		if (not console_opened) then
			if (rconsolename) then
				console_opened = true
				rconsolename('Raz Hub - Debug')
			end
		end
		rconsoleprint("[KHR | DEBUG]: " .. response .. '\n')
	end
end

getgenv().debug_idx = 1
getgenv().print_idx = function()
	print_debug(0, 'debug pos', debug_idx)
	debug_idx += 1
end

print_debug(0, 'Starting the script initialization...')

do
	-- Synapse X Auto Execute fixes
	local loading = true
	while loading do
		pcall(function()
			if game:GetService("CoreGui") then
				if game:GetService("ReplicatedStorage") then
					if game:GetService("Players").LocalPlayer then
						if game.Loaded and game:IsLoaded() then
							loading = false
						end
					end
				end
			end
		end)

		wait()
	end
end
print_debug(0)

--// PRIORITY VARIABLES //--
local automation_farm_toggle;
local af_toggle;
local is_farming = false;
local scroll_claiming = false
local is_doing_nocooldown = false
local force_spam = false
local use_spam = false
local places = {}
local scroll_drops = {
	boss = {},
	dungeon = {},
	normal = {}
}

--// CONFIGURATIONS //--
local script_settings = {}
local client_settings = {}

--// VARIABLES //--
local services = {
	players = game:GetService("Players"),
	marketplaceservice = game:GetService("MarketplaceService"),
	teleportservice = game:GetService("TeleportService"),
	userinputservice = game:GetService("UserInputService"),
	runservice = game:GetService("RunService"),
	virtualuser = game:GetService("VirtualUser"),
	virtualinputmanager = game:GetService("VirtualInputManager")
}
services.replicatedstorage = game:GetService("ReplicatedStorage")
print_debug(0)

local fakehealth = Instance.new("IntValue")
	fakehealth.Name = "fakehealth"
	fakehealth.Value = 9e9

local lp; while (not lp) do lp = services.players.LocalPlayer; task.wait() end;
local mouse = lp:GetMouse()
local camera = workspace.CurrentCamera
local gamepasses = {
	akatsuki = false,
	genkaibag = false,
	privateservers = false,
	genkai3 = false,
	genkai4 = false,
	element3 = false,
	element4 = false
}
local concat, find, insert, remove = table.concat, table.find, table.insert, table.remove
local cframe_lookat = CFrame.lookAt
local floor = math.floor
local JSON; do
	JSON = {}

	local HttpService = game:GetService("HttpService")

	function JSON:parse(content)
		return HttpService.JSONDecode(HttpService, content)
	end

	function JSON:stringify(object)
		return HttpService.JSONEncode(HttpService, object)
	end
end

print_debug(0)
local function update_gp()
	local gp = lp:WaitForChild("gamepasses", 5)
	if (gp) then
		for key, bool in next, gamepasses do
			gamepasses[key] = gp:FindFirstChild(key) ~= nil
		end
	end
end

local isnetworkowner = function (__name, __part)
	local char = lp.Character
	local part = char and char:FindFirstChild(__name)
	if (part) then
		return gethiddenproperty(part, "NetworkOwnerV3") == gethiddenproperty(__part, "NetworkOwnerV3")
	end

	return false
end

local nv3 = Vector3.new()
local function set_cframe(part, cf)
	part.RotVelocity = nv3
	part.Velocity = nv3

	part.CFrame = cf
end

local is_lg_premium = true
print_debug(0)

print_debug(0)
Library.GUI.Enabled = false
local Loader = Library:Loader()
Loader:set("Initializing cores...")
print_debug(0)

local function look_at (target)
	camera.CFrame = cframe_lookat(camera.CFrame.p, target.Position)
end

local message_posted = nil

local track = nil
local track_v3 = nil

task.spawn(function()
	local check = false
	while (Library.running) do
		local npc = track
		local root = npc and npc:FindFirstChild('HumanoidRootPart')
		if (root) then
			local v3, iv = camera:WorldToScreenPoint(root.Position)

			track_v3 = v3
		else
			track_v3 = nil
		end

		if (check ~= is_farming) then
			if (af_toggle and automation_farm_toggle) then
				af_toggle(is_farming)
				automation_farm_toggle(is_farming)
				check = is_farming
			end
		end
		task.wait()
	end
end)

local last_text = {}
local queued = {}
local chat_frame_path = { "PlayerGui", "Chat", "Frame" }
local chat_frame_textbox_path = { "PlayerGui", "Chat", "Frame", "ChatBarParentFrame", "Frame", "BoxFrame", "Frame", "ChatBar" }

local function say (content)
	if (not Library.running) then return end
	print_debug(0, ('say(%s)'):format(JSON:stringify(content)))
	print_debug(0, tostring(debug.traceback()))

	if (typeof(last_text[content]) == "number") then
		if ((tick()-last_text[content]) < 2) then
			return task.wait()
		end
	end

	-- synapse x can go kill themselves
	pcall(function()
		local cbf;
		for _, name in next, chat_frame_path do
			cbf = (cbf or lp):FindFirstChild(name)
			if (not cbf) then return end
		end
	
		local cb;
		for _, name in next, chat_frame_textbox_path do
			cb = (cb or lp):FindFirstChild(name)
			if (not cb) then return end
		end

		last_text[content] = tick()

		if (not cb:IsFocused()) then
			print_debug(0, 'Focusing chat')
			cbf.Visible = true
			cb:CaptureFocus()
			print_debug(0, 'Chat focused')
		end
		
		if (Library.running and cb:IsFocused() and cb.Text:len() == 0) then
			print_debug(0, 'Awaiting for processed input events')
			-- VIM:WaitForInputEventsProcessed()
			print_debug(0, 'Virtually type content:', tostring(content))
			services.virtualinputmanager:SendTextInputCharacterEvent(tostring(content), cb)
			print_debug(0, 'Awaiting for processed input events')
			services.virtualinputmanager:WaitForInputEventsProcessed()
		end

		if (Library.running and cb:IsFocused() and cb.Text:len() ~= 0) then
			print_debug(0, 'Virtually press enter')
			services.virtualuser:SetKeyDown(Enum.KeyCode.KeypadEnter.Value)
			print_debug(0, 'Virtually release enter')
			services.virtualuser:SetKeyUp(Enum.KeyCode.KeypadEnter.Value)
			print_debug(0, 'Awaiting for processed input events')
			task.wait(.5)
		end
	end)
end

print_idx()

do
	print_idx()
	task.spawn(function()
		local old_table_insert = hookfunction(insert, (function(self, ...)
			if (type(self) ~= "table") then return end
			local args = {...}
			
			if (not checkcaller()) then
				local char = lp.Character
				local root = char and char:FindFirstChild('HumanoidRootPart')
				if (root and #args >= 1 and typeof(args[1]) == 'Vector3' and args[1] == root.Position) then
					print_debug(0, 'reverted table state')
					remove(self, 1)
				end
			end
		
			return shared.table_insert(self, ...)
		end))

		local getidentity = getthreadcontext or getthreadcontext or syn_context_get or function() return 7 end
		local setidentity = setthreadcontext or setthreadcontext or syn_context_set or function(...) end
		
		shared.table_insert = shared.table_insert or old_table_insert

		while (Library.running) do
			local CCoff = workspace:FindFirstChild("CCoff")
			local VC = workspace:FindFirstChild("VC")
			local cra = VC and VC:FindFirstChild("cra")

			if (CCoff) then
				print_debug(0, 'CCoff removed')
				CCoff:Destroy()
			end

			if (cra) then
				print_debug(0, 'cra removed')
				cra:Destroy()
			end

			task.wait(.3)
		end
	end)
	print_idx()
	task.wait(2)
end
local main_menu = game:GetService("CoreGui"):WaitForChild('RobloxGui')
while (tostring(main_menu) ~= 'SettingsShield' and tostring(main_menu) ~= 'SettingsClippingShield') do
	local instance = main_menu:FindFirstChild('SettingsShield') or main_menu:FindFirstChild('SettingsClippingShield')
	if (instance) then
		main_menu = instance;
	end
	wait()
end
local Window = Library:Create("Shindo Life Nigga")
local config = Library.config
local webhook_main;do
	local request = syn and syn.request or request or http_request

	local webhook = {}

	function webhook:setUrl(url)
		self.url = url
		if (({self.url:find("https://")})[1] == 1) then
			webhook:setAvatar()
		end
	end

	function webhook:setAvatar()
		pcall(function()
			request({
				Url = self.url,
				Method = "PATCH",
				Headers = {
					["Content-Type"] = "application/json"
				},
				Body = game:GetService("HttpService"):JSONEncode({
					name = "Raz Hub Logger",
					avatar = "data:image/jpeg;base64,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HMEmdpzm66amQBTqdd4x84iGohKMM8vGI4NtKyMRIB7X00EsBIlhAY7EagOm5JSJn0jjvqaAmnFC5lznTZMDhZ3mJ9b0ohQbQZnfbx/3GUYIACMmaDo9Mz0QgIUDtGYesM+3MxB4ZbY+sKb6QAs3KOsTOOJb/tgVDTZl886BQKTi4i55fHrm5DYJrj/nx10lySlYMTG3SfnRR1orFgtPf9GoDSK6ELd4WOs86SYDoTjn46b86ktTkG/vDgc9tEhJjonr2Mi1jTMgECZcMzBGeurmU3AO1Y9++qaLXJmHE745466GxkkrztS/zRSmoAJDY6Rveoc17SmZDa/86QaZTAmIkU3CogjvogDGJmcOd+849dQUQYkUL2/Z466cAsQqWkSYen9xA2gB3WZmcuByZ1uDLF9T/sVBWlaVlysN2aiJ86YAR2YniH2uPnTlSLZg8x+31kZNIWdjiTrWmGcZU90zL/3RAssUwY7cVxHroAE2hDE585mb/wBcqDBuiNb4wY0mbZSUu4TOgKOCGqwxFngzjSkowhQlVUZ5376rWZIEYYiBfZnTIiQV2ndq69u2hFRCLVyzPFTtoORC8H13jD352VjCkAumer6cajMojjArEtVAxEdNtSxBSUN9eN86FVAglZl03X10FkBtLgjPt+jSgWQOCXt3/cOAC5tnb9186ZIyAhzDGFz+40SkQoUc3JRNRBzqiUGlb9CfTL41IcEmUoRPbfTMitpEmRx0j/M40oYAiUDEzmN8enfQeEmTlz5zogSswbt9I/bc6kwqrEqUO7tN/wB0SawnYwPPmIf81AUEiWuerY586RAgzTAjFVt+4idaQM8H7G3GoAryIGFJSZeefFaJIYJsRwMv+akKRRQsR3X9u6mDWuIqG59v+40A0CYJ1b74OnxMgMQJWZLoMR+zolzBpOXrv405JBQQNpW66ufwDQEGIN4i3zPXOhSjZMDGcPjzpSQAhcnnn10IAEYUifVzH7rpmYKYLn3cbc9d5DClKkLBj++PJqKNASZ356XtqUxTM3khrfedKYscciosI8vEmiChcjBNLXf886HaaCTRCecd9NCLIBRsT9QdPfTgqDIoeV2r11UUCBZk3nvxWV0gukomJrPUzOW86u2IzbmVtO8P6ppYF6RMx0++miERunCRdhvj29YDNlQz13doue751UhgL87educagUPl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"
				})
			})
		end)
	end

	function webhook:send(title, content, footer)
		if (request and ({self.url:find("https://")})[1] == 1) then
			pcall(function()
				webhook:setAvatar()
				request({
					Url = self.url,
					Method = "POST",
					Headers = {
						["Content-Type"] = "application/json"
					},
					Body = game:GetService("HttpService"):JSONEncode({
						embeds = {
							{
								["title"] = title,
								["description"] = tostring(content),
								color = 0x4db6ac,
								footer = {
									text = ("Raz Hub • %s"):format(footer or "Logger")
								}
							}
						}
					})
				})
			end)
		end
	end

	webhook_main = webhook
end
webhook_main:setUrl('')
local webhook_config = config:new("Webhook")
local webhook_settings = webhook_config:load("webhook.ini", {
	url = ""
})

config = config:new("Shindo Life")
if (not isfolder('Raz Hub/Shindo Life/codes')) then makefolder('Raz Hub/Shindo Life/codes') end
local codes = {}

Loader:set("Initializing places...")
do
	local results;
	while (not results) do
		pcall(function()
			results = game:GetService("HttpService"):JSONDecode(game:HttpGet(string.format('https://develop.roblox.com/v1/universes/%s/places?sortOrder=Asc&limit=100', tostring(game.GameId)))).data
		end)
	
		task.wait()
	end

	for i,v in next, results do
		if (v.name:find('^(%[RPG%])') == 1 or v.name:find('^(%[EVENT%])') == 1 or v.name:find('^(%[PvE%])') == 1) then
			places[tostring(v.id)] = v.name
		else
			print_debug(0, '[TELEPORT GENERATOR]', 'Invalid place name...', v.name)
		end
	end
end

update_gp()
task.spawn(function()
	while (Library.running) do
		update_gp()
		task.wait(5)
	end
end)

local function create_page(name, data, callback)
	-- local t = tick()
	print_debug(0, "Initializing page:", name)
	Loader:set(string.format("Initializing %s...", name))
	callback(Window:AddPage(name), typeof(data.name) == 'string' and config:load(data.name .. '.ini', data.default) or nil)
	-- warn(name, tick()-t)
end

-- Library.GUI.Enabled = true

if (game.PlaceId == 7524809704 and is_lg_premium) then
	create_page("Dungeons", {
		name = "dungeons",
		default = {
			enabled = false,
			location = "[Training Grounds]",
			difficulty = "easy"
		}
	}, function(tab, config)
		local BossTab = lp:WaitForChild("PlayerGui"):WaitForChild("teleport"):WaitForChild("serverframe"):WaitForChild("top"):WaitForChild("BossTab")
		local can_continue = false
		local yes, no = false, false
	
		local function run()
			local tab = nil
	
			for i = 1, #BossTab:GetChildren(), 1 do
				local t = BossTab:FindFirstChild(tostring(i))
				local play = t and t:FindFirstChild("play")
				-- if (t and play and play.Text == "PLAY") then
				if (t and play) then
					if (t.icon.lvl.Text == config.location) then
						tab = t
					end
				end
			end
	
			if (tab) then
				if firesignal then
					firesignal(tab.play.MouseButton1Down)
				elseif getconnections then
					getconnections(tab.play.MouseButton1Down)[1]:Fire()
				end
			end
		end
	
		if (config.enabled) then
			Library:Verification("Would you like to stop the dungeon autofarm?", 5, function(y, n)
				yes = y
				no = n
			end)
	
			if (not yes) then
				no = true
				run()
			end
	
			if (yes) then
				config:set('enabled', false)
			end
		end
	
		tab:AddToggle("Enabled", config.enabled, function(t)
			config:set('enabled', t)
	
			while (Library.running and config.enabled) do
				run()
				task.wait()
			end
		end)
	
		-- tab:AddToggle("Progressive autofarm", dungeon.do_all, function(t)
		-- 	dungeon.do_all = t
		-- 	config:save()
		-- end)
	
		local diff = tab:AddDropdown("Select Difficulty", config.difficulty or "easy", false, function(option)
			config:set('difficulty', option)
		end)
	
		diff:Add("easy")
		diff:Add("medium")
		diff:Add("hard")
	
		local dropdown = tab:AddDropdown("Select Dungeon", config.location, false, function(option)
			config:set('location', option)
		end)
	
		for _, v in next, BossTab:GetChildren() do
			if (v.play.Text:find("PLAY")) then
				dropdown:Add(v.icon.lvl.Text)
			end
		end
	end)
end

if (game.PlaceId == 4616652839) then
	create_page("Auto Spins", {
		name = "autospins",
		default = {
			auto_rejoin = false,
			auto_save_on_claim = false,
			auto_rejoin_on_spins_check = false,
			spins_check_size = 20,
			kgs = {
				spins = {},
				selected = {}
			},
			elements = {
				spins = {},
				selected = {}
			}
		}
	}, function(tab, config)
		-- Loader:set('Creating and initializing rc shop...')
		local startevent = lp:WaitForChild('startevent')
		local statz = lp:WaitForChild('statz')
		local _spins = statz:WaitForChild('spins')
		local cached_spins = _spins.Value + 0
		local genkais, elements; do
			genkais = Instance.new("Folder")
			elements = Instance.new("Folder")
			local buffer = 0
			local max_buffer = 5
			local rare_kgs = workspace:FindFirstChild("RAREKGS")
			
			for i,v in next, game:GetService("ReplicatedStorage"):WaitForChild("alljutsu"):GetChildren() do
				local limited = nil
				if (rare_kgs) then
					limited = rare_kgs:FindFirstChild(v.Name)
				end
			
				if (limited) then
					local release = limited:FindFirstChild("release")
					if (release and typeof(release) == "Instance" and release:IsA("BoolValue") and not release.Value) then
						continue
					end
				end
				if (v:FindFirstChild("KG") or (v:FindFirstChild("ss") and v.ss:FindFirstChild("kg"))) then
			
					v:Clone().Parent = genkais
				elseif (v:FindFirstChild("ELEMENT")) then
					v:Clone().Parent = elements
				end
			
				if (buffer >= max_buffer) then
					buffer = 0
					task.wait()
				end
			
				buffer += 1
			end
		end
		local blocked = false
		local force_save = false

		task.spawn(function()
			while (Library.running) do
				if (_spins.Value > cached_spins or force_save) then
					if (is_lg_premium) then
						print_debug(0, '[DEBUG | AUTOSPIN]', 'BLOCKING SPIN EXECUTION AND REJOINING')
						blocked = true
						startevent:FireServer("band", "\0")
						startevent:FireServer("band", "eye")
						startevent:FireServer("band", "Eye")
						startevent:FireServer("rpgteleport", game.PlaceId)
						services.teleportservice:Teleport(game.PlaceId)
					end
				end

				task.wait()
			end
		end)

		local rollback = function(teleport)
			if (not is_lg_premium) then return end
			for i=0, 10 do
				startevent:FireServer('band', '\128')
			end
			if (teleport) then
				services.teleportservice:Teleport(game.PlaceId)
			end
		end

		local set_slot = function(key, value)
			startevent:FireServer('kgbag', key, value)
		end

		local get_slot = function(key)
			local value = lp.statz.main[key].Value

			return value ~= '' and value or nil
		end

		local save = function()
			queue_on_teleport(string.format('game:GetService("TeleportService"):Teleport(%s)', tostring(game.PlaceId)))
		end

		local function load_rcshop()
			--[[
				RELL COIN CUSTOM SHOP
			]]

			do
				lp.PlayerScripts:WaitForChild('Character')
				local setupbigshop, setuplimitedshop; while (not (setupbigshop and setuplimitedshop)) do
					setupbigshop = getfenv(getsenv(lp.PlayerScripts.Character).scangui).setupbigshop
					setuplimitedshop = getfenv(getsenv(lp.PlayerScripts.Character).scangui).setuplimitedshop
					task.wait()
				end
				
				local main = lp.PlayerGui:WaitForChild("Main")
				local shop_items = main:WaitForChild("RYOshop"):WaitForChild("ShopItems")
				main:WaitForChild("RYOshop"):WaitForChild("Shoplimited").Visible = false
				shop_items:WaitForChild('bg1').Visible = false
				shop_items:WaitForChild('bg2').Visible = false
				shop_items:WaitForChild('bg3').Visible = false
				shop_items:WaitForChild('bg4').Visible = false
				local bigshop = shop_items:WaitForChild("bigshop")
				local limitedshop = shop_items:WaitForChild("limitedshop")
				local actualshop = shop_items:FindFirstChild('bigshop_khr') or bigshop:Clone()
				local actuallimitedshop = shop_items:FindFirstChild("limitedshop_khr") or limitedshop:Clone()

				actualshop.Parent = shop_items
				actualshop.Name = 'bigshop_khr'
				actualshop.Visible = true

				actuallimitedshop.Parent = shop_items
				actuallimitedshop.Name = 'limitedshop_khr'
				actuallimitedshop.Visible = false

				limitedshop.Visible = false
				bigshop.Visible = false
				local rcshop_label = Instance.new('ImageLabel')
				do
					rcshop_label.Image = 'rbxassetid://3108304521'
					rcshop_label.ImageColor3 = Color3.fromRGB(170, 204, 255)
					rcshop_label.ClipsDescendants = true
					rcshop_label.BackgroundColor3 = Color3.fromRGB(57, 69, 86)
					rcshop_label.BorderColor3 = Color3.new()
					rcshop_label.BorderSizePixel = 1
					rcshop_label.Size = UDim2.new(0, 150, 0, 150)
					rcshop_label.ZIndex = 10
				
					local item = Instance.new('ImageLabel')
					item.BackgroundColor3 = Color3.fromRGB(115, 144, 179)
					item.BackgroundTransparency = 1
					item.ImageColor3 = Color3.new(1, 1, 1)
					item.Name = 'item'
					item.Visible = true
					item.Parent = rcshop_label
					item.ZIndex = 12
				
					local purchase = Instance.new('TextButton')
					purchase.AnchorPoint = Vector2.new(.5, .5)
					purchase.Name = 'purchase'
					purchase.Text = 'BUY'
					purchase.Parent = rcshop_label
					purchase.BackgroundColor3 = Color3.fromRGB(99, 99, 99)
					purchase.TextColor3 = Color3.new(1, 1, 1)
					purchase.TextScaled = true
					purchase.Font = Enum.Font.SourceSans
					purchase.TextSize = 14
					purchase.BackgroundTransparency = 0
					purchase.BorderSizePixel = 0
					purchase.Visible = true
					purchase.Size = UDim2.new(0, 120, 0, 20)
					purchase.Position = UDim2.new(.5, 0, .85, 0)
					purchase.ZIndex = 14
				end

				local prices = {'price1', 'price2', 'price3'}

				local function getprice(instance)
					for _, price in next, prices do
						local p = instance:FindFirstChild('ryoshop')
						local p2 = instance:FindFirstChild(price)
				
						if (p) then return p end
						if (p2) then
							return p2.ryo2
						end
					end
				end
							
				local column = 1
				local row = 0
				local buying = false
				local function create_rell_item(instance, parent)
					local label = rcshop_label:Clone()
					label.Name = instance.Name
					label.item.AnchorPoint = Vector2.new(.5, .5)
					label.item.Position = UDim2.new(.5, 0, .5, 0)
					label.item.Image = instance.img:IsA('Decal') and instance.img.Texture or 'rbxassetid://' .. instance.img.Value
					label.item.Size = UDim2.new(1, -25, 1, -25)
					label.Parent = parent
					label.Position = UDim2.new(0.01 + 0.16 * (column - 1), 0, 0.001 + 0.016999999999999998 * row, 0)
					label.purchase.Text = (lp.statz.unlocked:FindFirstChild(instance.Name) or lp.statz.genkailevel:FindFirstChild(instance.Name)) and 'OWNED' or ('BUY - %s$RC'):format(tostring(getprice(instance).Value))
					label.purchase.MouseButton1Click:Connect(function()
						if (buying or label.purchase.Text == 'OWNED') then
							return
						end

						buying = true
						Library:Verification(('Would you like to purchase %s for %s RELLCOIN?'):format(instance.Name, tostring(getprice(instance).Value)), 5, function(y, n)
							if (y) then
								local key = parent == actualshop and 'rellcoinshop' or 'buyrcgenkai'
								local object = key == 'rellcoinshop' and {
									className = 'Folder',
									ClassName = 'Folder',
									Name = instance.Name,
									ryoshop = {
										Value = getprice(instance).Value,
										Name = 'ryoshop',
										ClassName = 'IntValue',
										className = 'IntValue'
									}
								} or instance
								startevent:FireServer(key, instance)
							end
						end)
						buying = false

					end)
					column += 1
					if (column >= 7) then
						column = 1
						row += 1
					end
					
					return label
				end
				
				actualshop:ClearAllChildren()
				actuallimitedshop:ClearAllChildren()

				getfenv(getsenv(lp.PlayerScripts.Character).scangui).setupbigshop = function()
					for i,v in next, lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop_khr"):GetChildren() do
						if (lp.statz.unlocked:FindFirstChild(v.Name)) then
							v.purchase.Text = 'OWNED'
						end
					end

					for i,v in next, lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop_khr"):GetChildren() do
						if (lp.statz.genkailevel:FindFirstChild(v.Name)) then
							v.purchase.Text = 'OWNED'
						end
					end
				end

				getfenv(getsenv(lp.PlayerScripts.Character).scangui).setuplimitedshop = function()
					for i,v in next, lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop_khr"):GetChildren() do
						if (lp.statz.unlocked:FindFirstChild(v.Name)) then
							v.purchase.Text = 'OWNED'
						end
					end

					for i,v in next, lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop_khr"):GetChildren() do
						if (lp.statz.genkailevel:FindFirstChild(v.Name)) then
							v.purchase.Text = 'OWNED'
						end
					end
				end
				
				local buffer = 0
				local max_buffer = (1024 * 8)

				local rsdescendants = services.replicatedstorage:GetDescendants()
				for _, descendant in next, rsdescendants do
					if (descendant.Parent.Name ~= 'acc' and descendant.Name == 'ryoshop' and descendant:IsA('IntValue') and descendant.Parent:FindFirstChild('img')) then
						create_rell_item(descendant.Parent, actualshop)
					end

					buffer += 1
					if (buffer > max_buffer) then
						buffer = 0
						task.wait()
					end
				end

				column = 1
				row = 0

				for _, descendant in next, rsdescendants do
					if (descendant.Name == 'limited' and descendant:IsDescendantOf(services.replicatedstorage.alljutsu)) then
						create_rell_item(descendant.Parent, actuallimitedshop)
					end

					buffer += 1
					if (buffer > max_buffer) then
						buffer = 0
						task.wait()
					end
				end

				for _, connection in next, getconnections(shop_items.HB.limited.MouseButton1Down) do
					hookfunction(connection.Function, function(...)
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop_khr").Visible = false
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop").Visible = false
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop_khr").Visible = true
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop").Visible = false
					end)
				end
		
				for _, connection in next, getconnections(shop_items.HB.rellcloak.MouseButton1Down) do
					hookfunction(connection.Function, function(...)
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop_khr").Visible = true
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("bigshop").Visible = false
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop_khr").Visible = false
						lp.PlayerGui:WaitForChild("Main"):WaitForChild("RYOshop"):WaitForChild("ShopItems"):WaitForChild("limitedshop").Visible = false
					end)
				end
			end
		end

		local initialized_rc = false
		tab:AddButton('Initialize custom rellcoin shop', nil, function()
			if (not initialized_rc) then
				initialized_rc = true
				load_rcshop()
			end
		end)

		-- tab:AddToggle('Inf Rell Coin', false, function(t)
		-- 	shared.inf_rc = t
		-- end)

		tab:AddButton("Click to rejoin (non-rollback data)", nil, function()
			if (is_lg_premium) then
				game:GetService("Players").LocalPlayer.startevent:FireServer("band", "\128")
			end
			game:GetService("TeleportService"):Teleport(game.PlaceId)
		end)

		tab:AddButton("Click to rejoin (rollback data)", nil, function()
			while (true) do
				rollback(true)
				task.wait()
			end
		end)

		;(function(tab)
			tab:AddToggle("Auto Rejoin", config.auto_rejoin, function(t)
				config:set("auto_rejoin", t)
			end)

			tab:AddToggle("Spins Count Rejoin", config.auto_rejoin_on_spins_check, function(t)
				config:set("auto_rejoin_on_spins_check", t)
			end)

			tab:AddSlider("Spins Count", config.spins_check_size, 0, 1000, function(n)
				config:set("spins_check_size", n)
			end)

			tab:AddToggle("Uncheck On Claim", config._uncheck, function(t)
				config:set('_uncheck', t)
			end)

			tab:AddToggle("Save & Rejoin On Claim (gamble feature)", config._save, function(t)
				config:set('_save', t)
			end)
		end)(tab:AddSubsection("Main"))

		local subsection = {
			elements = tab:AddSubsection("Elements"),
			kgs = tab:AddSubsection("KGs")
		}

		local function create_toggle(key, section)
			local object_key = key .. 's'
			local object = config[object_key]
			local spin_key = key
			local statz_key = key == 'kg' and 'genkai' or 'element'

			local selection = section:AddDropdown('Selection', nil, true, function(option)
				local name = option:split('] - ')[1]:sub(2)
				local index = find(object.selected, name)
				if (index ~= nil) then
					remove(object.selected, index)
				else
					insert(object.selected, name)
				end

				config:set(object_key, object)
			end)

			local names = {}
			local realnames = {}
			for i,v in next, (key == 'kg' and genkais or elements):GetChildren() do
				local realname = v:FindFirstChild("realname") or v:FindFirstChild("REALNAME")
				local exists = find(object.selected, v.Name) ~= nil
				selection:Add(string.format('[%s] - %s', v.Name, realname.Value), exists)
				if (exists) then
					insert(names, v.Name)
				end
				realnames[v.Name] = realname.Value
			end

			object.selected = names

			local spins = {}
			for i=1, 4 do
				if (i <= 2 or gamepasses[statz_key .. i]) then
					spins[i] = section:AddToggle('Spin ' .. i, object.spins[i], function(t)
						object.spins[i] = t
						config:set(object_key, object)
					end)
				end
			end

			local function get_slots()
				local got = {}
				local found = 0
				local spinning = #object.selected
				for i=1,4 do
					local value = get_slot(spin_key .. i)
					if (typeof(value) == 'string' and not got[value] and find(object.selected, value)) then
						got[value] = i
						found += 1
						spinning -= 1
					end
				end

				return spinning, got
			end

			task.spawn(function()
				local notified = {}
				while (Library.running and not blocked) do
					if (webhook_config.webhook) then
						for idx, bool in next, object.spins do
							if (typeof(notified[idx]) == 'nil') then
								notified[idx] = true
							end
							
							local spinning, slots = get_slots()

							if (slots and bool and not blocked) then
								local value = get_slot(spin_key .. idx)
								if (typeof(value) == 'string' and slots[value] == idx) then
									if (config._uncheck) then
										spins[idx](false)
										object.spins[idx] = false
										config:set(object_key, object)
									end

									if (not notified[idx]) then
										notified[idx] = true

										webhook_main:send('Auto Spin', ('Found %s **`[%s] - %s`** at **`slot %s`**'):format(statz_key, realnames[value], value, tostring(idx)), 'Shindo Life • REWRITE')

										if (config._save) then
											webhook_main:send('Auto Spin', 'Rejoining to attempt a force save...', 'Shindo Life • REWRITE')
											blocked = true
											force_save = true
										end
									end
									continue
								end

								notified[idx] = false

								if (spinning > 0) then
									if (gamepasses.genkaibag) then
										local found = false

										for _, name in next, object.selected do
											if (typeof(slots[name]) == 'nil') then
												if (statz.genkailevel:FindFirstChild(name)) then
													set_slot((key == 'kg' and 'kg' or 'e') .. idx, name)
													found = true
													break
												end
											end
										end

										if (found) then continue end
									end

									if (_spins.Value <= 0 or (config.auto_rejoin_on_spins_check and _spins.Value <= config.spins_check_size and cached_spins > config.spins_check_size)) then
										if (cached_spins > 0) then
											print_debug(0, 'Attempting a full rollback on rejoin...')
											rollback(true)
										end
										continue
									end

									startevent:FireServer('spin', key .. idx)
								end
							end
						end
					end
					task.wait()
				end
			end)
		end

		local check_spin_prompted = false

		local function prompt_spin(object)
			if (not check_spin_prompted) then
				for index, boolean in next, object.spins do
					if (boolean) then
						check_spin_prompted = true
						Library:Verification("Would you like to stop autospinning?", 5, function(y,n)
							if (y) then
								for _, o in next, { config.elements, config.kgs } do
									for idx, _ in next, o.spins do
										o.spins[idx] = false
									end
									config:set('elements', config.elements)
									config:set('kgs', config.kgs)
								end
							end
						end)
						break
					end
				end
			end
		end

		prompt_spin(config.elements)
		prompt_spin(config.kgs)

		create_toggle('element', subsection.elements)
		create_toggle('kg', subsection.kgs)
	end)
end

local init_fm = function () end

create_page("Client", {
	name = "client",
	default = {
		ws = {
			enabled = false,
			value = 16
		},
		jp = {
			enabled = false,
			value = 50
		},
		inf_mode = false,
		remove_effects = false,
		semi_godmode = false,
		points = {
			point = 1,
			selected = {}
		},
		show_cursor = true
	}
}, function(tab, config)
	client_settings = config
	local connections = {}

	-- incase of nil ig
	local integrities = {}
	local projectileparent;
	local clienteffects;
	local ignore_particles_name = { 'charge', 'modeup', 'hitsaber', 'rain', 'bodyeffect', 'smokeeffect', 'blockbreak', 'parryeffect', 'defend', 'ParticleEmitter', 'block', 'flicker' }
	local function descendant_check(descendant)
		if (game.PlaceId == 4616652839) then return end
		projectileparent = projectileparent or workspace:FindFirstChild("projectileparent")
		clienteffects = clienteffects or workspace:FindFirstChild('ClientEffects')
		if (not (Library.running and config.remove_effects)) then return end
		if (clienteffects and clienteffects:IsAncestorOf(descendant)) then
			task.wait(.1)
			descendant:Destroy()
			return;
		end

		if (projectileparent and projectileparent:IsAncestorOf(descendant)) then
			task.wait(.1)
			descendant:Destroy()
			return;
		end
	end

	task.spawn(function()
		insert(connections, workspace:WaitForChild("ClientEffects").DescendantAdded:Connect(descendant_check))

		while (Library.running) do task.wait() end
		for _, connection in next, connections do
			connection:Disconnect()
		end
	end)

	tab:AddToggle('Show Cursor', config.show_cursor, function(t)
		config:set('show_cursor', t)

		while (Library.running and config.show_cursor) do
			services.userinputservice.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.ForceShow
			task.wait()
		end

		services.userinputservice.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.ForceHide
	end)

	local kg_moves_section = tab:AddSubsection("KG Move Setter (VBN)")
	do
		local kg_moves = {}
		local selected_instance;
		local moves_dropdown = kg_moves_section:AddDropdown('Selected Move', nil, false, function(option)
			selected_instance = kg_moves[option]
		end)

		for _, key in next, ('vbn'):split('') do
			kg_moves_section:AddButton(('Set to %s'):format(key:upper()), ('This will set the selected kg move to %s'):format(key:upper()), function()
				if (selected_instance) then
					lp.startevent:FireServer('equipjutsu', key, selected_instance)
				end
			end)
		end

		task.spawn(function()
			while (Library.running) do
				-- go through all of the folders
				for _, folder in next, services.replicatedstorage:WaitForChild('alljutsu'):GetChildren() do
					if (folder:FindFirstChild('KG')) then -- if it is a KG then go through the KG's folder
						for _, instance in next, folder:GetChildren() do
							if (instance:IsA('ModuleScript')) then
								local order = instance:FindFirstChild('ORDER')
				
								if (order and order:IsA('IntValue') and not instance:FindFirstChild('form')) then
									local rn = instance:FindFirstChild('REALNAME')
									if (lp:WaitForChild('statz'):WaitForChild('unlocked'):FindFirstChild(instance.Name) and rn and not kg_moves[rn.Value]) then
										kg_moves[rn.Value] = instance
										moves_dropdown:Add(rn.Value)
									end
								end
							end
						end
					end
				end

				lp:WaitForChild('statz'):WaitForChild('unlocked').ChildAdded:Wait()
			end
		end)
	end

	local el_moves_section = tab:AddSubsection("Element Move Setter (VBN)")
	do
		local el_moves = {}
		local selected_instance;
		local moves_dropdown = el_moves_section:AddDropdown('Selected Move', nil, false, function(option)
			selected_instance = el_moves[option]
		end)

		for _, key in next, ('vbn'):split('') do
			el_moves_section:AddButton(('Set to %s'):format(key:upper()), ('This will set the selected element move to %s'):format(key:upper()), function()
				if (selected_instance) then
					lp.startevent:FireServer('equipjutsu', key, selected_instance)
				end
			end)
		end

		task.spawn(function()
			while (Library.running) do
				-- go through all of the folders
				for _, folder in next, services.replicatedstorage:WaitForChild('alljutsu'):GetChildren() do
					if (folder:FindFirstChild('ELEMENT')) then -- if it is a KG then go through the KG's folder
						for _, instance in next, folder:GetChildren() do
							if (instance:IsA('ModuleScript')) then
								local order = instance:FindFirstChild('ORDER')
				
								if (order and order:IsA('IntValue') and not instance:FindFirstChild('form')) then
									local rn = instance:FindFirstChild('REALNAME')
									if (lp:WaitForChild('statz'):WaitForChild('unlocked'):FindFirstChild(instance.Name) and rn and not el_moves[rn.Value]) then
										el_moves[rn.Value] = instance
										moves_dropdown:Add(rn.Value)
									end
								end
							end
						end
					end
				end

				lp:WaitForChild('statz'):WaitForChild('unlocked').ChildAdded:Wait()
			end
		end)
	end

	local stats_section = tab:AddSubsection("Player Stats")
	do
		local Upgrades = {}
		local Points = stats_section:AddLabel("Points: 0", false)
		task.spawn(function()
			local mastery = lp:WaitForChild("statz"):WaitForChild("mastery")
			while (Library.running) do
				Points("Points: " .. tostring(mastery.points.Value))
				task.wait()
			end
		end)

		stats_section:AddSlider("Add Points Count", config.points.point, 1, 1000, function(n)
			config.points.point = n
			config:set('points', config.points)
		end)

		for _, label in next, { "Chakra", "Ninjutsu", "Taijutsu", "Health" } do
			stats_section:AddToggle("Upgrade " .. label, config.points.selected[label], function(t)
				local mastery = lp:WaitForChild("statz"):WaitForChild("mastery")
	
				config.points.selected[label] = t
				config:set('points', config.points)
				local integrity = {}
				Upgrades[label] = t and integrity or false
				while (Library.running) do
					if (mastery.points.Value == 0) then
						mastery.points:GetPropertyChangedSignal("Value"):Wait()
					end

					if (Upgrades[label] ~= integrity) then
						break
					end
					
					lp.startevent:FireServer("addstat", label:lower(), config.points.point)
					task.wait()
				end
			end)
		end
	end

	local movement_section = tab:AddSubsection("Movement")
	do
		local ws_modifier = movement_section:AddSubsection("WalkSpeed Modifier")
		do
			ws_modifier:AddToggle("Enabled", config.ws.enabled, function(t)
				config.ws.enabled = t
				config:set('ws', config.ws)
			end)

			ws_modifier:AddSlider("Value", config.ws.value, 16, 1000, function(n)
				config.ws.value = n
				config:set('ws', config.ws)
			end)
		end

		local jp_modifier = movement_section:AddSubsection("JumpPower Modifier")
		do
			jp_modifier:AddToggle("Enabled", config.jp.enabled, function(t)
				config.jp.enabled = t
				config:set('jp', config.jp)
			end)

			jp_modifier:AddSlider("Value", config.jp.value, 50, 1000, function(n)
				config.jp.value = n
				config:set('jp', config.jp)
			end)
		end
	end

	tab:AddToggle("Remove Effects", config.remove_effects, function(t)
		config:set('remove_effects', t)

		if (game.PlaceId == 4616652839) then return end
		if (t) then
			task.spawn(function()
				for _, descendant in next, workspace:GetDescendants() do
					if (descendant.ClassName == "ParticleEmitter") then
						task.spawn(descendant_check, descendant)
					end
				end
			end)
		end
	end)

	tab:AddToggle("Infinite Mode", config.inf_mode, function(t)
		if (not t and config.inf_mode) then
			local c = lp.Character
			if (c) then
				c:BreakJoints()
			end
		end

		config:set('inf_mode', t)
	end)

	tab:AddToggle("Semi-Godmode", config.semi_godmode, function(t)
		config:set('semi_godmode', t)
	end)

	init_im = function()
		if (not Library.running or not config.inf_mode) then return end
		local char = lp.Character
		local combat = char and char:FindFirstChild('combat')
		local mode = combat and combat:FindFirstChild('mode')
		if (mode) then
			print_debug(0, 'triggering inf mode')
			while (script_settings.no_cooldown and script_settings.no_cooldown.top_priority) do
				if (lp.Character and lp.Character:FindFirstChild("zombify")) then
					break
				end
				task.wait()
			end
			print_debug(0, 'triggering inf mode v2')
			mode:Clone().Parent = combat
			wait(1)
			mode:Destroy()
			lp.CharacterRemoving:Wait()
		end
	end
end)

if (game.PlaceId == 7524811367) then
	create_page("Automation", {
		name = "dungeons",
		default = {
			enabled = false,
			location = "[Training Grounds]",
			difficulty = "easy"
		}
	}, function(page, config)
		task.spawn(function()
			while (Library.running) do
				local npc = track
				if (npc and npc.Parent == workspace:FindFirstChild('npc')) then
					local players = game:GetService("Players")
					local char = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
					local sroot = char and char:FindFirstChild("HumanoidRootPart")
					local shead = char and char:FindFirstChild("Head")
					local root = npc and npc:FindFirstChild("HumanoidRootPart")
					local head = npc and npc:FindFirstChild("Head")
					if (sroot and shead and root and head and script_settings.autofarm) then
						look_at(root)
						set_cframe(sroot, root.CFrame * CFrame.new(0, script_settings.autofarm.height, script_settings.autofarm.distance))
						if (update) then
							update:FireServer('fixmouse', root.CFrame)
						end

						local combat = char:FindFirstChild('combat')
						local update = combat and combat:FindFirstChild('update')
						if (script_settings and script_settings.spam_keys and not script_settings.spam_keys.enabled) then
							if (update) then
								update:FireServer('mouse1', true)
							end
						else
							use_spam = true
							force_spam = true
							print_debug(0, 'Running auto-track and triggering spam keys...')
						end
					end
				else
					use_spam = false
					force_spam = false
					track = nil
				end

				task.wait()
			end
		end)

		page:AddToggle("Enabled", config.enabled, function(t)
			config:set('enabled', t)

			local old_pos;
			while (Library.running and config.enabled) do
				task.wait()
				local char = lp.Character or lp.CharacterAdded:Wait()
				local root = char and char:FindFirstChild('HumanoidRootPart')
				if (scroll_claiming or not root) then continue end
				old_pos = old_pos or root.CFrame

				if (scroll_claiming) then continue end
				for _, npc in next, workspace.npc:GetChildren() do
					if (npc:IsA("Model") and string.find(npc.Name, 'npc') == 1) then
						local fakehealth = npc:FindFirstChild('fakehealth')
						local humanoid = npc:FindFirstChildOfClass('Humanoid')
						local eroot = npc:FindFirstChild('HumanoidRootPart')
						if (npc:FindFirstChild("loadedin") and fakehealth and humanoid and eroot) then
							if (eroot.Position.Y < -1000) then
								npc:Destroy()
								continue
							else
								if (not track) then
									track = npc
									print_debug(1, 'Tracking', npc, '...')
								end
							end
						end
					end
				end
			end

			track = nil
			if (old_pos) then
				pcall(function()
					lp.Character.HumanoidRootPart.CFrame = old_pos
				end)
			end
		end)
	end)
elseif (game.PlaceId ~= 7524809704) then
	create_page('Automation', {
		name = "autofarm",
		default = {
			enabled = false,
			selected = {},
			cancel_timer = 60
		}
	}, function(tab, config)
		task.spawn(function()
			while (Library.running) do
				local npc = track
				if (npc and npc.Parent == workspace:FindFirstChild('npc') and not scroll_claiming) then
					local players = game:GetService("Players")
					local char = players.LocalPlayer.Character or players.LocalPlayer.CharacterAdded:Wait()
					local sroot = char and char:FindFirstChild("HumanoidRootPart")
					local shead = char and char:FindFirstChild("Head")
					local root = npc and npc:FindFirstChild("HumanoidRootPart")
					local head = npc and npc:FindFirstChild("Head")
					local rest = npc and npc:FindFirstChild('rest')
					if (sroot and shead and root and head and script_settings.autofarm) then
						look_at(root)
						set_cframe(sroot, root.CFrame * CFrame.new(0, script_settings.autofarm.height, script_settings.autofarm.distance))
						if (not (rest and rest.Value)) then
							if (update) then
								update:FireServer('fixmouse', root.CFrame)
							end

							if (script_settings and script_settings.spam_keys and not script_settings.spam_keys.enabled) then
								local combat = char:FindFirstChild('combat')
								local update = combat and combat:FindFirstChild('update')
								
								if (update) then
									update:FireServer('mouse1', true)
								end
							else
								use_spam = true
								force_spam = true
								print_debug(0, 'Running auto-track and triggering spam keys...')
							end
						end
					end
				else
					use_spam = false
					force_spam = false
					track = nil
				end

				task.wait()
			end
		end)

		task.spawn(function()
			local name = places[tostring(game.PlaceId)] or places[game.PlaceId]
			local npcs = {
				connections = {},
				entities = {},
				types = {}
			};
			local currentmission;
			local missiontypes;
			local currentmissions;
			if (not (name and name:find('^(%[EVENT%])'))) then
				if (not lp.Character) then
					lp.CharacterAdded:Wait()
				end

				do
					local lvlrequirement, statz;
					task.spawn(function()
						local GlobalFunctionsModule = game:GetService("ReplicatedStorage"):WaitForChild("GlobalFunctions")
						local Success, GlobalFunctions;
						local function requireGlobFunc()
							Success, GlobalFunctions = pcall(require, GlobalFunctionsModule)
							
							return typeof(GlobalFunctions) == "table"
						end
					
						while (not requireGlobFunc()) do task.wait(.5) end
					
						lvlrequirement = (GlobalFunctions.lvlrequirement or function() return {} end)()
						while (tostring(statz) ~= 'lvl') do
							local s = lp:FindFirstChild("statz")
							if (s and s:FindFirstChild("lvl")) then
								statz = s:FindFirstChild("lvl")
							end
							task.wait()
						end
	
						while (Library.running) do task.wait(1) end
						pcall(function() npcs:disconnect_all() end)
					end)
				
					local missiongivers = workspace:FindFirstChild("missiongivers")
					missiontypes = workspace:FindFirstChild("missiontypes")
					missiontypes = missiontypes and missiontypes:WaitForChild("getspawns")
					missiontypes = missiontypes and missiontypes:WaitForChild(tostring(game.PlaceId))
	
					if (missiontypes) then
						for _, folder in next, missiontypes:GetChildren() do
							insert(npcs.types, folder.Name)
						end
					end
	
					local function watch(child)
						task.spawn(function()
							if (npcs.update) then
								npcs:update()
							end
							local Head = child:WaitForChild("Head")
							local givemission = Head:WaitForChild("givemission")
							local Talk = child:WaitForChild("Talk")
							local mobname = Talk:WaitForChild("mobname")
							local typ = Talk:WaitForChild("typ")
	
							for _, instance in next, { mobname, typ } do
								insert(npcs.connections, instance:GetPropertyChangedSignal("Value"):Connect(function()
									if (npcs.update) then
										print_debug(0, instance.Name, 'triggered')
										npcs:update()
									end
								end))
							end
	
							insert(npcs.connections, givemission:GetPropertyChangedSignal("Enabled"):Connect(function()
								if (npcs.update) then
									print_debug(0, 'givemission triggered')
									npcs:update()
								end
							end))
						end)
					end
	
					if (missiongivers) then
						insert(npcs.connections, missiongivers.ChildAdded:Connect(function(child)
							if (child:IsA("Model") and find(npcs.entities, child) == nil) then
								insert(npcs.entities, child)
								watch(child)
							end
						end))
						
						insert(npcs.connections, missiongivers.ChildRemoved:Connect(function(child)
							if (find(npcs.entities, child) ~= nil) then
								remove(npcs.entities, find(npcs.entities, child))
								if (npcs.update) then
									npcs:update()
								end
							end
						end))
						
						for _, npc in next, missiongivers:GetChildren() do
							if (npc:IsA("Model") and find(npcs.entities, npc) == nil) then
								insert(npcs.entities, npc)
								watch(npc)
							end
						end
					end
					
					function npcs:get(key)
						local entities = {}
					
						for _, npc in next, npcs.entities do
							-- print_debug(0, 'got entity', _)
							if (npc:FindFirstChild("CLIENTTALK") and npc:FindFirstChild("Talk") and npc:FindFirstChild("Head") and lvlrequirement and statz) then
								local Head = npc.Head
								local Talk = npc.Talk
								local typ = Talk and Talk:FindFirstChild("typ")
								local mobname = Talk and Talk:FindFirstChild("mobname")
								local givemission = Head and Head:FindFirstChild("givemission")
								
								-- print_debug(0, 'npcs:get(', key, ')')
								if (typ and mobname and givemission and (typ.Value == "halloweenevent" or typ.Value == key) and givemission.Enabled) then
									if (typeof(lvlrequirement[mobname.Value]) ~= "number" or lvlrequirement[mobname.Value] <= statz.lvl.Value) then
										local HumanoidRootPart = npc:FindFirstChild("HumanoidRootPart")
					
										if (HumanoidRootPart and HumanoidRootPart.Position.Y > 100) then
											insert(entities, npc)
										end
									end
								end
							end
						end
					
						return entities
					end
					
					local boss_mission_cached = false
					local boss_mission_cache = {}
					
					function npcs:get_boss_missions()
						if (not boss_mission_cached) then
							boss_mission_cached = true
					
							for i,v in next, workspace:GetChildren() do
								if (v:FindFirstChild("MAINSCRIPT") and v:FindFirstChild("missions") and #v:GetChildren() == 2) then
									for _, object in next, v.missions:GetChildren() do
										if (#object:GetChildren() >= 2) then
											local position = object:FindFirstChild("position")
											local missiongiver = object:FindFirstChild("missiongiver")
					
											if (position and missiongiver) then
												boss_mission_cache[object.Name] = {
													pos = position,
													npc = missiongiver
												}
											end
										end
									end
								end
							end
						end
					
						return boss_mission_cache
					end
					
					function npcs:disconnect_all()
						for _, connection in next, npcs.connections do
							connection:Disconnect()
						end
					end
				end
	
				if (#npcs.types > 0) then
					local missions_section = tab:AddSubsection("Missions")
					do
						local missions_label = {}
						local keys = {
							mobs = 'defeat',
							groceries = 'grocerybag',
							deliver = 'envelope'
						}
						print_debug(0, 'Total npc types count', #npcs.types)
						local i = 1
						while (i <= #npcs.types) do
							print_debug(0, 'old', i)
							local m1 = npcs.types[i]
							local m2 = npcs.types[i + 1]
							local label_1, label_2 = missions_section:AddSplitLabel("")
							if (m1) then
								missions_label[m1] = label_1
								label_1(m1)
							end
							if (m2) then
								missions_label[m2] = label_2
								label_2(m2)
							end
							i += 2
							print_debug(0, 'new', i)
						end
	
						function npcs:update()
							print_debug(0, 'npcs:update()')
							for key, label in next, missions_label do
								print_debug(0, 'npcs:update()', key, #npcs:get(keys[tostring(key)] or tostring(key)))
								label(key .. ': ' .. #npcs:get(keys[tostring(key)] or tostring(key)) .. ' missions')
							end
						end
	
						npcs:update()
					end
				end
				
				currentmission = lp:WaitForChild('currentmission')
				missiontypes = workspace:FindFirstChild("missiontypes")
				currentmissions = missiontypes and missiontypes:FindFirstChild("currentmissions")
			end

			local farm_section = tab:AddSubsection("Auto Farm")
			do

				if (not (name and name:find('^(%[EVENT%])'))) then
					if (missiontypes and currentmissions) then
						local elapsed_label = farm_section:AddLabel('Mission cancels in x seconds')
						farm_section:AddSlider('Auto Cancel (for quests)', config.cancel_timer, 30, 360, function(n)
							config:set('cancel_timer', n)
						end)
			
						do
							task.spawn(function()
								local last = 0
								while (Library.running) do
									if (currentmission.Value) then
										if (last == 0) then
											last = tick()
										end
			
										local mob = track
										if (mob and mob.Parent == workspace.npc) then
											-- in this case, we ignore boss for timers
											if (mob:FindFirstChild("megaboss") or mob:FindFirstChild("bossdrop")) then
												last = tick()
												elapsed_label('Mission cancels in x seconds')
												task.wait()
												continue
											end
										end
			
										local duration = config.cancel_timer - floor(tick()-last)
			
										if (duration < 0) then
											last = 0
											say('!cancel')
											task.wait(1)
										else
											elapsed_label(string.format('Mission cancels in %s seconds', tostring(duration)))
										end
									else
										last = 0
										elapsed_label('Mission cancels in x seconds')
									end
			
									task.wait()
								end
							end)
						end
					end
			
					local quests_dropdown;
					for idx, name in next, npcs.types do
						if (not quests_dropdown) then
							quests_dropdown = farm_section:AddDropdown('Quest Selection', nil, true, function (option, toggled)
								config.selected[option] = toggled
								config:set('selected', config.selected)
							end)
						end
			
						quests_dropdown:Add(name, config.selected[name])
					end
			
					local bosses_dropdown;
					for name, object in next, npcs:get_boss_missions() do
						if (not bosses_dropdown) then
							bosses_dropdown = farm_section:AddDropdown("Boss Selection", nil, true, function(option, toggled)
								config.selected[option] = toggled
								config:set('selected', config.selected)
							end)
						end
			
						bosses_dropdown:Add(name, config.selected[name])
					end

					local idx = 0
					local bck;
					automation_farm_toggle = farm_section:AddToggle("Enabled", config.enabled, function(t)
						config:set('enabled', t)
						is_farming = t

						local old_pos;
						while (Library.running and config.enabled) do
							task.wait()
							local char = lp.Character or lp.CharacterAdded:Wait()
							local root = char and char:FindFirstChild('HumanoidRootPart')
							if (scroll_claiming or not root) then continue end
							old_pos = old_pos or root.CFrame

							if (not currentmission.Value) then
								set_cframe(root, CFrame.new(root.Position.X, 99999, root.Position.Z))
								if (scroll_claiming) then task.wait() continue end
								local is_claiming = false
								for name, object in next, npcs:get_boss_missions() do
									if (not config.selected[name]) then continue end
									local entity = object.npc
									local cancel = false
									task.delay(5, function() cancel = true end)

									local old_cf = root.CFrame
									while (not cancel and not entity.Talk.accepted.Value and entity.Talk.cooldown.Value <= 0) do
										if (scroll_claiming) then task.wait() continue end
										if (currentmission.Value) then break end
										is_claiming = true

										set_cframe(root, CFrame.new(entity.HumanoidRootPart.Position) * CFrame.new(0, -15, 0))

										entity.CLIENTTALK:FireServer()
										entity.CLIENTTALK:FireServer("accept")

										task.wait(0.5)
									end

									set_cframe(root, old_cf)

									if (currentmission.Value) then break end
								end

								do
									if (is_claiming) then
										local t = tick()
										while (Library.running) do
											if (currentmission.Value or ((tick()-t) > 1)) then break end
											task.wait()
										end

										is_claiming = false
									end
								end

								if (not currentmission.Value) then
									for _, key in next, npcs.types do
										if (scroll_claiming) then break end
										if (config.selected[key]) then
											local k = ((key == "mobs" and "defeat") or (key == "groceries" and "grocerybag") or (key == "deliver" and "envelope") or key)
											local entity = npcs:get(k)[1]

											if (entity) then
												local givemission = entity:FindFirstChild("Head") and entity.Head:FindFirstChild("givemission")
												local cancel = false
												task.delay(5, function() cancel = true end)

												local getting_quest = false

												while (Library.running and not cancel and givemission and givemission.Enabled and givemission:IsDescendantOf(workspace)) do
													if (scroll_claiming) then task.wait() continue end
													if (currentmission.Value) then break end
													is_claiming = true

													set_cframe(root, CFrame.new(entity.HumanoidRootPart.Position) * CFrame.new(0, -15, 0))

													if (not getting_quest) then
														getting_quest = true
														task.spawn(function()
															entity.CLIENTTALK:FireServer()
															entity.CLIENTTALK:FireServer("accept")

															task.wait(1)
															getting_quest = false
														end)
													end

													task.wait()
												end

												local talk = entity:FindFirstChild("Talk")
												local typ = talk and talk:FindFirstChild("typ")

												if (typ and typ.Value ~= k) then
													while (lp.currentmission.Value) do
														say("!cancel")
														task.wait()
													end
												end
											end

											if (currentmission.Value) then break end
										end
									end
								end

								if (scroll_claiming) then continue end

								do
									if (is_claiming) then
										local t = tick()
										while (Library.running) do
											if (currentmission.Value or ((tick()-t) > 1)) then break end
											task.wait()
										end

										is_claiming = false
									end
								end
							end

							if (currentmission.Value) then
								local flagged = false
								local part;
								local target = currentmission.Value and currentmission.Value:FindFirstChild("target")
								if (not part and target and target.Value) then
									part = target.Value
								end

								for _, npc in next, workspace.npc:GetChildren() do
									if (part and npc:IsA("Model") and string.find(npc.Name, 'npc') == 1) then
										local fakehealth = npc:FindFirstChild('fakehealth')
										local humanoid = npc:FindFirstChildOfClass('Humanoid')
										local eroot = npc:FindFirstChild('HumanoidRootPart')
										local enemy = npc:FindFirstChild('enemy', true)
										if (npc:FindFirstChild("loadedin") and fakehealth and humanoid and eroot) then
											if (eroot.Position.Y < -1000) then
												npc:Destroy()
												continue
											else
												humanoid.Health = 0
												if ((enemy and enemy:IsA("BillboardGui") and enemy.Enabled) or (eroot.Position - part.Position).magnitude < 500) then
													-- print_debug(0, 'Killing real npc')
													if (fakehealth.Value < 0) then
														if (flagged) then
															say('!cancel')
															break
														end
														task.wait(1)
														flagged = true
													end
													if (not track) then
														track = npc
														print_debug(0, 'Tracking', npc, '...')
													end
												end
											end
										end
									end
								end
							end
						end

						track = nil
						if (old_pos) then
							pcall(function()
								lp.Character.HumanoidRootPart.CFrame = old_pos
							end)
						end
						if (currentmission.Value) then
							say('!cancel')
						end
					end)
				else
					farm_section:AddToggle("Enabled", config.enabled, function(t)
						config:set('enabled', t)

						local old_pos;
						while (Library.running and config.enabled) do
							task.wait()
							local char = lp.Character or lp.CharacterAdded:Wait()
							local root = char and char:FindFirstChild('HumanoidRootPart')
							if (scroll_claiming or not root) then continue end
							old_pos = old_pos or root.CFrame

							if (scroll_claiming) then continue end
							for _, npc in next, workspace.npc:GetChildren() do
								if (npc:IsA("Model") and string.find(npc.Name, 'npc') == 1) then
									local fakehealth = npc:FindFirstChild('fakehealth')
									local humanoid = npc:FindFirstChildOfClass('Humanoid')
									local eroot = npc:FindFirstChild('HumanoidRootPart')
									local tmb = npc:FindFirstChild('timemegaboss', true)
									local team = npc:FindFirstChild('Team')
									if (fakehealth and fakehealth.Value <= 0) then
										if (track == npc) then
											track = nil
										end

										continue
									end

									if (npc:FindFirstChild("loadedin") and fakehealth and humanoid and eroot and tmb) then
										if (eroot.Position.Y < -1000) then
											npc:Destroy()
											continue
										elseif (not track) then
											if (team and team:IsA('StringValue')) then
												if (lp.Team and lp.Team.Name == team.Value) then
													continue
												end
											end
											track = npc
											print_debug(1, 'Tracking', npc, '...')
										end
									end
								end
							end
						end

						track = nil
						if (old_pos) then
							pcall(function()
								lp.Character.HumanoidRootPart.CFrame = old_pos
							end)
						end
					end)
				end
			end
		end)
	end)
end

local teleports_config;
local privateCodes = {}
create_page("Teleports", {
	name = "teleports",
	default = {
		use_codes = false
	}
}, function (tab, config)
	teleports_config = config
	local public_section = tab:AddSubsection("Public")
	local private_section = tab:AddSubsection("Private")
	do
		
		local function sort(tbl)
			local keys = {}
			for key in pairs(tbl) do
				table.insert(keys, key)
			end
			
			table.sort(keys, function(a, b)
				return tbl[a] < tbl[b]
			end)
			
			return keys
		end

		local opts = {
			private = false,
			hooked = false
		}

		task.spawn(function()
			do
				use_server_creator_gamepass = public_section:AddToggle("Use Server Creator Gamepass", not config.use_codes, function(t)
					config:set('use_codes', not t)
				end)

				for i,v in ipairs(sort(places)) do
					public_section:AddButton(places[v], nil, function()
						lp.startevent:FireServer(not config.use_codes and 'createprivateserver' or 'rpgteleport', tonumber(v))
					end)
				end
			end

			do					
				local sh = 'Solaris - SL'
				local bh = 'Bruh Life 2'
				local khr = 'Raz Hub/Shindo Life/codes'

				local function getCodes(dir, id)
					local path = dir .. '/' .. id .. '.txt'

					if (isfile(path)) then
						return JSON:parse(readfile(path))
					end
				end
				
				if (not isfolder(khr)) then
					makefolder(khr)
				end

				local note = {}

				for id, name in next,sort(places) do
					id = name
					name = places[id]
					local shCodes = getCodes(sh, id)
					local bhCodes = getCodes(bh, id)
					
					local codes = {}

					for _, code in next, shCodes or {} do
						insert(codes, code)
					end

					for _, code in next, bhCodes or {} do
						if (type(find(codes, code)) == "nil") then
							insert(codes, code)
						end
					end

					if (tostring(game.PlaceId) == id) then
						if (workspace:FindFirstChild("playerps")) then
							local private = lp.PlayerGui:WaitForChild("Main"):WaitForChild("private")
							repeat wait() until private.Text ~= ""
							local code = private.Text
							if (type(table.find(codes, code)) == "nil") then
								insert(codes, code)
							end
						end
					end

					local txt = khr .. '/' .. id .. '.txt'
					writefile(txt, JSON:stringify(codes))
					privateCodes[id] = codes

					insert(note, string.format('%s.txt - %s', id, name))
				end

				insert(note, '')
				insert(note, '')
				insert(note, "[ <place_id.txt - place_name> automatically updated @ Raz Hub ]")
				
				writefile(khr .. '/__READ__.txt', table.concat(note, '\n'))

				for i,v in ipairs(sort(places)) do
					local dropdown = private_section:AddDropdown(places[v] .. " | " .. tostring(#privateCodes[v]), "", false, function (selected)
						if (selected:len() >= 5) then
							lp.startevent:FireServer("teleporttoprivate", selected)
						end
					end)
					for _, id in next, privateCodes[v] do dropdown:Add(id) end
				end
			end
		end)
	end
end)

create_page("Settings", {
	name = "settings",
	default = {
		autorank = {
			enabled = false,
			prestige = false
		},
		webhook = {},
		scrolls = {
			enabled = false,
			selected = {},

			hop = false,
			auto_remove = false,
			use_codes = false,
			stop_on_target = false
		},
		
		autofarm = {
			enabled = false,
			place = nil,
			height = 0,
			distance = 5
		},

		no_cooldown = {
			enabled = false,
			top_priority = false
		},

		spam_keys = {
			enabled = false,
			missions_only = true,
			selected = {}
		}
	}
}, function(tab, config)
	local scrolls = {};

	script_settings = config

	task.spawn(function()
		while (Library.running) do
			init_im()
			task.wait()
		end
	end)

	local statz = lp:WaitForChild('statz')
	local is_scroll_owned = function (name)
		return statz.unlocked:FindFirstChild(name .. "scroll") or statz.unlocked:FindFirstChild(name) or statz.genkailevel:FindFirstChild(name)
	end

	local scan_for_scrolls = function(instance)
		local _ = {}
	
		for i,v in next, instance:GetChildren() do
			local sh = v:IsA("Model") and v:FindFirstChild("sh")
			if (sh and sh:FindFirstChild("ClickDetector")) then
				if (sh.Position.Y <= 0) then
					print_debug(1, 'Scroll Scanner; Destroyed', sh.Parent.Name, sh.Position.Y)
					v:Destroy()
				elseif (not is_scroll_owned(v.Name)) then
					print_debug(1, "Scroll Scanner;", "Found", v.Name, tostring(is_scroll_owned(v.Name)))
					if (v.Name == "gamepass") then
						for index, instance in next, v:GetDescendants() do
							print_debug(2, index, v:GetFullName(), '|', v.ClassName)
						end
					end
					insert(_, v)
				end
			end
		end
	
		return _
	end

	local auto_hop_toggle;

	local claim_scrolls = function(tbl)
		local root = lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
		if (not root) then return end
		if (not config.scrolls.enabled) then return end

		local alljutsu = services.replicatedstorage:FindFirstChild('alljutsu')
		local powers = services.replicatedstorage:WaitForChild("saber")
		if (not powers:FindFirstChild("monkeystaffb")) then -- if not conquest
			powers = powers:WaitForChild("powers")
		end
		local modes = alljutsu:WaitForChild("modes")

		print_debug(0, 'claim_scrolls triggered')
		for i, v in next, tbl do
			local click_detector = v:FindFirstChildWhichIsA('ClickDetector', true)
			local sh = click_detector and click_detector.Parent
			local invoke = sh and sh:FindFirstChild('invoke')

			if (sh and ((click_detector and click_detector:IsA('ClickDetector')) or (invoke and invoke:IsA('RemoteEvent')))) then
				scroll_claiming = true
				print_debug(1, 'Detected a scroll', i, v, click_detector)
				local is_claiming = false
				local is_selected = find(config.scrolls.selected, v.Name) ~= nil
				local boss = v:FindFirstChild('boss')
				local boss_npc;
				local is_boss = false
				if (boss and boss:IsA('StringValue')) then
					is_boss = true
					for _, npc in next, workspace.npc:GetChildren() do
						local npctype = npc:FindFirstChild('npctype')
						if (npctype and npctype.Value == boss.Value) then
							boss_npc = npc
							break
						end
					end
				end

				local sct = tick()
				while (Library.running and (tick() - sct) < 3 and not is_scroll_owned(v.Name) and sh:IsDescendantOf(workspace) and ((click_detector and click_detector:IsDescendantOf(workspace)) or (invoke and invoke:IsDescendantOf(workspace)))) do
					is_claiming = true
					print_debug(1, 'Collecting...', i, v, click_detector)
					look_at(sh)

					local v3, in_view = camera:WorldToViewportPoint(sh.Position)
					for i,v in next, lp.PlayerGui:GetChildren() do
						if (v:IsA('Frame')) then
							v.Visible = false
						elseif (v:IsA('ScreenGui')) then
							v.Enabled = false
						end
					end
					Library.GUI.Enabled = false
					main_menu.Visible = false
					if (boss_npc and boss_npc:IsDescendantOf(workspace)) then
						sct = tick()
						local hum = boss_npc:FindFirstChild('Humanoid')
						local roo = boss_npc:FindFirstChild('HumanoidRootPart')
						if (hum and roo) then
							local char = lp.Character
							local combat = char and char:FindFirstChild("combat")
							local update = combat and combat:FindFirstChild("update")
							if (update) then
								update:FireServer('key', 'e')
								task.wait()
								update:FireServer('key', 'eend')
							end
							hum.Health = 0
							set_cframe(root, roo.CFrame * CFrame.new(0, 50, 0))
						end
					else
						set_cframe(root, sh.CFrame)

						if (invoke) then
							invoke:FireServer(lp)
						else
							invoke = sh:FindFirstChild('invoke')
						end

						if (clickdetector) then
							pcall(fireclickdetector, click_detector)
						end
						services.virtualinputmanager:SendMouseButtonEvent(v3.X, v3.Y, 0, true, workspace, 0)
						services.virtualinputmanager:WaitForInputEventsProcessed()
						services.virtualinputmanager:SendMouseButtonEvent(v3.X, v3.Y, 0, false, workspace, 0)
						services.virtualinputmanager:WaitForInputEventsProcessed()
					end
					task.wait()
				end
				for i,v in next, lp.PlayerGui:GetChildren() do
					if (v:IsA('Frame')) then
						v.Visible = true
					elseif (v:IsA('ScreenGui')) then
						v.Enabled = true
					end
				end
				Library.GUI.Enabled = true
				main_menu.Visible = true

				if (is_claiming and is_scroll_owned(v.Name)) then
					if (config.scrolls.stop_on_target and is_selected) then
						config.scrolls.hop = false
						config:set('scrolls', config.scrolls)
						if (auto_hop_toggle) then
							auto_hop_toggle(false)
						end
					end

					if (webhook_config.webhook.scrolls) then
						local name = nil
						local instance = scroll_drops.boss[v.Name] or scroll_drops.dungeon[v.Name] or scroll_drops.normal[v.Name]

						if (instance) then
							local realname = instance:FindFirstChild("REALNAME") or instance:FindFirstChild("realname")
							if (realname) then
								name = realname.Value
							end
						end
						task.spawn(function()
							webhook_main:send("Scroll Sniper", ("A scroll has been claimed in **%s**\nScroll: **%s**\nName: **%s**"):format(tostring(places[tostring(game.PlaceId)]), v.Name, tostring(name)), "Shindo Life • REWRITE")
						end)
					end
					print_debug(1, "scrolls.enabled", v.Name, "claimed")
					Library:Notify("Scroll Alert", v.Name .. '\n' .. 'Claimed: ' .. tostring(is_scroll_owned(v.Name) ~= nil))

				end
				print_debug(1, 'End of loop scroll claiming', i, v, click_detector)
				scroll_claiming = false
			end
		end

		task.wait(0.5)
	end

	if (is_lg_premium) then
		tab:AddToggle('Collect Scrolls', config.scrolls.enabled, function(t)
			config.scrolls.enabled = t
			config:set('scrolls', config.scrolls)
		end)

		local auto_rank_section = tab:AddSubsection("Auto Rank")
		do
			auto_rank_section:AddToggle("Auto Rank", config.autorank.enabled, function(t)
				config.autorank.enabled = t

				config:set('autorank', config.autorank)

				local statz = game.Players.LocalPlayer:WaitForChild('statz')
				local startevent = lp:WaitForChild('startevent')
				while (Library.running and config.autorank.enabled) do
					-- if (LP.statz.lvl.lvl.Value >= 500) then
					if (lp.statz.lvl.lvl.Value >= 1000) then
						if (config.autorank.prestige and statz.prestige.rank.Value == "Z" and statz.prestige.number.Value == 3)
						then
							startevent:FireServer("maxlvlpres")
						else
							startevent:FireServer("rankup")
						end
						task.wait(2)
					end
					task.wait()
				end
			end)

			auto_rank_section:AddToggle("Enable Prestige / Rank Upgrade", config.autorank.prestige, function(t)
				config.autorank.prestige = t

				config:set('autorank', config.autorank)
			end)
		end

		local no_cooldown_section = tab:AddSubsection("No Cooldown")
		do
			local is_notifying = false;
			local trigger_nocooldown = function(boolean)
				local char = lp.Character
				local combat = char and char:FindFirstChild("combat")
				local update = combat and combat:FindFirstChild("update")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local modeup = root and root:FindFirstChild("modeup")
				local mode = combat and combat:FindFirstChild("mode")
				local Main = lp.PlayerGui and lp.PlayerGui:FindFirstChild("Main")
				local ingame = Main and Main:FindFirstChild("ingame")
				local Bar = ingame and ingame:FindFirstChild("Bar")
				local hp = Bar and Bar:FindFirstChild("hp")
				local statz = lp and lp:FindFirstChild('statz')
				local keys = statz and statz:FindFirstChild('keys')
				local z = keys and keys:FindFirstChild('z')
				local cooldown = z and z:FindFirstChild('cooldown')
				local alljutsu = services.replicatedstorage:FindFirstChild('alljutsu')
				local modes = alljutsu and alljutsu:FindFirstChild('modes')

				-- for idx, val in ipairs({
				-- 	char,
				-- 	combat,
				-- 	update,
				-- 	root,
				-- 	modeup,
				-- 	mode,
				-- 	Main,
				-- 	ingame,
				-- 	Bar,
				-- 	hp,
				-- 	statz,
				-- 	keys,
				-- 	z,
				-- 	cooldown,
				-- 	alljutsu,
				-- 	modes,
				-- 	services.replicatedstorage
				-- }) do
				-- 	print_debug(0, idx, typeof(val), val)
				-- end
				-- print_debug(0, typeof(lp), lp)
				-- print_debug(0, typeof(char), char)
				if (char and modes and cooldown and update and modeup and mode and Main and ingame and Bar and hp and hp.Text ~= "HP: 000") then
					if (not boolean) then
						is_doing_nocooldown = false
						if (char:FindFirstChild('zombify')) then
							return char.zombify:Destroy()
						end

						return
					end

					if (is_doing_nocooldown) then return end

					is_doing_nocooldown = true

					local disable = mode:FindFirstChild('disable')
					if (not disable or disable.Value or cooldown.Value ~= 0) then
						is_doing_nocooldown = false
						return
					end

					if (not char:FindFirstChild("zombify")) then
						local old = modes:FindFirstChild(z.Value)
						local is_replacing = false
						if (not old or not old:FindFirstChild('beserk') or not old:FindFirstChild('modeban')) then
							is_replacing = true
							for i,v in next, modes:GetChildren() do
								if (v:FindFirstChild('beserk') and v:FindFirstChild('modeban') and v.beserk:IsA('Script') and is_scroll_owned(v.Name)) then
									local startevent = lp:FindFirstChild('startevent')
									if (not startevent) then
										is_doing_nocooldown = false
										return
									end
									startevent:FireServer('equipmode', v)
									z.Value = v.Name
									is_replacing = false
									break
								end
							end

							if (is_replacing) then
								is_doing_nocooldown = false
								if (not is_notifying) then
									is_notifying = true;
									Library:Notify('No Cooldown - Alert', 'You do not have a tailed beast to use this feature', 5)
									task.delay(5, function()
										is_notifying = false;
									end)
								end
								return
							end
						end

						if (not (char:FindFirstChild("bodyeffect") or char:FindFirstChild("beserk") or char:FindFirstChild("zombify"))) then
							local last = tick()
							while (Library.running and char:IsDescendantOf(workspace) and not modeup.Enabled and not (char:FindFirstChild("bodyeffect") or char:FindFirstChild("beserk") or char:FindFirstChild("zombify")) and math.floor(tick()-last) <= 3) do
								is_doing_nocooldown = true
								update:FireServer("key", "z")
								wait()
							end
							while (Library.running and char:IsDescendantOf(workspace) and modeup.Enabled and not (char:FindFirstChild("bodyeffect") or char:FindFirstChild("beserk") or char:FindFirstChild("zombify")) and math.floor(tick()-last) <= 3) do
								is_doing_nocooldown = true
								task.wait()
							end

							if (math.floor(tick()-last) >= 3) then
								is_doing_nocooldown = false
								return;
							end
						end

						if (not char:IsDescendantOf(workspace)) then
							is_doing_nocooldown = false
							return
						end
						if (char:FindFirstChild("bodyeffect") and not char:FindFirstChild("zombify")) then
							update:FireServer("key", "zend")
							if (not char:FindFirstChild("zombify")) then
								say("!spirit")
							end
							local beserk = char:IsDescendantOf(workspace) and char:WaitForChild("beserk", 5)
							if (beserk) then
								local jinroom = beserk:FindFirstChild("jinroom")
								while (Library.running) do
									jinroom = beserk:FindFirstChild("jinroom")

									if (jinroom and jinroom:FindFirstChild("leave")) then
										break
									end

									is_doing_nocooldown = true
									task.wait()
								end

								if (jinroom and jinroom:FindFirstChild('leave')) then
									jinroom.leave.Value = true
									task.wait(.2)
									beserk:Destroy()
									-- say("!spirit off")
								end
							end
		
							local pgmain = lp.PlayerGui:FindFirstChild('Main')
							local pgf = pgmain and pgmain:FindFirstChild('Frame')
							if (pgf) then
								pgf:Destroy()
							end
						end
					end

					is_doing_nocooldown = false
				end
			end

			no_cooldown_section:AddToggle("Enabled", config.no_cooldown.enabled, function(t)
				config.no_cooldown.enabled = t
				config:set('no_cooldown', config.no_cooldown)
				
				if (not t) then
					return trigger_nocooldown(t)
				end

				while (Library.running and config.no_cooldown.enabled) do
					task.spawn(trigger_nocooldown, true)
					task.wait()
				end
				-- task.spawn(trigger_nocooldown, false)
			end)

			no_cooldown_section:AddToggle("Top Priority", config.no_cooldown.top_priority, function(t)
				config.no_cooldown.top_priority = t
				config:set('no_cooldown', config.no_cooldown)
			end)
		end

		local auto_hop_section = tab:AddSubsection("Autohop")
		do
			if (config.scrolls.hop) then
				Library:Verification("Would you like to turn off Autohop?", 5, function(y, n)
					if (y) then
						config.scrolls.hop = false
						config:set('scrolls', config.scrolls)
					end
				end)
			end

			local is_using_label = auto_hop_section:AddLabel('')
			task.spawn(function()
				while (Library.running) do
					is_using_label(('Use Codes: %s\nServer Creator Gamepass Toggle in Teleports section'):format(tostring(teleports_config.use_codes)))
					task.wait()
				end
			end)

			local function can_hop(name)
				local GLOBALTIME = workspace:WaitForChild("GLOBALTIME", 2)
				if (not GLOBALTIME) then return false end
				local globalesttime = GLOBALTIME:WaitForChild("globalesttime", 2)
				if (not globalesttime) then return false end
				if (typeof(globalesttime.Value:find(':')) ~= 'number') then return false end
				local h,m = table.unpack(globalesttime.Value:split(':'))
				local scroll = scrolls[name]
			
				if (scroll) then
					local hr = scroll.time.hr - (h%12)
					local min = (scroll.time.min - m) + 25
			
					if (tonumber(h) == scroll.time.hr and min >= -1) then
						if (min <= 25 and min >= -1) then
							return true
						end
					end
				end
			
				return false
			end

			do
				local function get_next_scrolls()
					local GLOBALTIME = workspace:WaitForChild("GLOBALTIME", 2)
					if (not GLOBALTIME) then return false end
					local globalesttime = GLOBALTIME:WaitForChild("globalesttime", 2)
					if (not globalesttime) then return false end
					if (typeof(globalesttime.Value:find(':')) ~= 'number') then return false end
				
					if (globalesttime) then
						local h,m,s = unpack(globalesttime.Value:split(':'))
				
						if (typeof(h) == "string" and typeof(m) == "string" and typeof(s) == "string") then
							h = tonumber(h)
							m = tonumber(m)
				
							if (h < 12) then
								h += 12
							end
							
							local closest = {
								scroll = nil,
								h = math.huge,
								m = math.huge
							}
				
							local sorted = {}
				
							for name, object in next, scrolls do
								local scroll_h = object.time.hr
								local scroll_m = object.time.min
								scroll_h = tonumber(tonumber(scroll_h) < 12 and (tonumber(scroll_h) + 12) or scroll_h)
				
								local duration_h = scroll_h - h
								local duration_m = scroll_m - m
				
								if (duration_h >= 0 and duration_m >= 0) then
									table.insert(sorted, {
										scroll = object.name,
										h = duration_h,
										m = duration_m
									})
								end
							end

							local new_sorted = {}
				

				
							for i=1, 6, 1 do
								table.insert(new_sorted, sorted[i])
							end
							
							sorted = new_sorted

							-- table.sort(sorted, function(left, right)
							-- 	return left.m < right.m
							-- end)
				
							return sorted
						end
					end
				
					return nil
				end
				
				local label = "Spawning in %02dh, %02dm and %02ds\r\nName: %s"
				local labels = {}
				for i = 1, 3 do
					local l,r = auto_hop_section:AddSplitLabel("Next scroll is spawning in xh, xm and xs\r\nName: x", "Next scroll is spawning in xh, xm and xs\r\nName: x")
					labels[#labels + 1] = l
					labels[#labels + 1] = r
				end

				task.spawn(function()
					while (Library.running) do
						local GLOBALTIME = workspace:WaitForChild("GLOBALTIME", 2)
						if (GLOBALTIME) then
							local globalesttime = GLOBALTIME:WaitForChild("globalesttime", 2)
							if (globalesttime and typeof(globalesttime.Value:find(':')) == 'number') then
								local h,m,s = table.unpack(globalesttime.Value:split(':'))

								h = tonumber(h)
								if (h < 12) then h += 12 end
								m = tonumber(m)
								s = (60 - tonumber(s:split(' ')[1])) % 60

								local next_scrolls = get_next_scrolls() or {}

								table.sort(next_scrolls, function (left, right)
									return left.h < right.h and left.m < right.m
								end)

								for _, object in ipairs(next_scrolls) do
									labels[_](label:format(object.h, object.m, s, object.scroll))
								end
							end
						end

						task.wait(1)
					end
				end)
			end

			local dropdown;
			dropdown = auto_hop_section:AddDropdown('Multi-Selection', nil, true, function(option, toggle)
				local value = option:sub(
					select(1, option:find('[\\(]')) + 1,
					-2
				)

				local idx = find(config.scrolls.selected, value)
				if (typeof(idx) ~= 'number' and toggle) then
					if (is_scroll_owned(value)) then
						return dropdown:Set(option, false)
					end

					insert(config.scrolls.selected, value)
				elseif (typeof(idx) == 'number' and not toggle) then
					remove(config.scrolls.selected, idx)
				end

				config:set('scrolls', config.scrolls)
			end)

			do
				local function get_id(name)
					for id, v in next, places do
						if (name == v) then return id end
					end
				end

				task.spawn(function()
					local GLOBALTIME = workspace:WaitForChild("GLOBALTIME")
					local clienttell = GLOBALTIME:WaitForChild("clienttell", 5)

					if (clienttell) then
						-- local scrolls = {}
						for i,v in next, services.replicatedstorage:GetDescendants() do
							if (v.Name == "SCROLLSPAWN") then
								scroll_drops.normal[v.Parent.Name] = v.Parent
							end

							if (v.Name == "isdungeondrop") then
								scroll_drops.dungeon[v.Parent.Name] = v.Parent
							end
						end
						
						for i,v in next, clienttell:GetChildren() do
							local instance = scroll_drops.normal[v.Name]

							if (instance and v:IsA("StringValue") and v.Value:len() > 2) then
								local realname = instance:FindFirstChild("REALNAME") or instance:FindFirstChild("realname")
								
								if (realname) then
									-- vibe += 1
									scrolls[v.Name] = {
										name = realname.Value,
										time = {
											min = v:WaitForChild("gettime"):WaitForChild("min").Value,
											hr = v:WaitForChild("gettime"):WaitForChild("hr").Value
										},
										place = {
											name = v.location.Value,
											id = get_id(v.location.Value)
										}
									}
			
									print_debug(0, v.Name, scrolls[v.Name].place.id)
									local scroll = scrolls[v.Name]
									dropdown:Add(string.format('[%02d:%02d | %s](%s)', scroll.time.hr, scroll.time.min, scroll.name, v.Name), typeof(find(config.scrolls.selected, v.Name)) == "number")
								end
							end
						end
					end

					auto_hop_section:AddButton("Un-select all scrolls", "This will un-select every scrolls upon button click", function()
						for i,v in next, scrolls do
							dropdown:Set(string.format('[%02d:%02d | %s](%s)', v.time.hr, v.time.min, v.name, i), false)
						end
					end)

					auto_hop_section:AddButton("Select all scrolls", "This will select every scrolls upon button click", function()
						for i,v in next, scrolls do
							dropdown:Set(string.format('[%02d:%02d | %s](%s)', v.time.hr, v.time.min, v.name, i), not is_scroll_owned(i))
						end
					end)

					auto_hop_toggle = auto_hop_section:AddToggle("Enabled", config.scrolls.hop, function(t)
						config.scrolls.hop = t
						config:set('scrolls', config.scrolls)
					end)

					auto_hop_section:AddToggle("Stop if a scroll is found", config.scrolls.stop_on_target, function(t)
						config.scrolls.stop_on_target = t
						config:set('scrolls', config.scrolls)
					end)

					auto_hop_section:AddToggle("Un-check collected scrolls", config.scrolls.auto_remove, function(t)
						config.scrolls.auto_remove = t
						config:set('scrolls', config.scrolls)
					end)

					task.spawn(function()

						while (Library.running) do
							if (config.scrolls.auto_remove) then
								for i,v in next, scrolls do
									if (is_scroll_owned(i)) then
										dropdown:Set(string.format('[%02d:%02d | %s](%s)', v.time.hr, v.time.min, v.name, i), false)
									end
								end
							end

							lp.statz.unlocked.ChildAdded:Wait()
						end
					end)

					task.spawn(function()
						while (Library.running) do
							if (config.scrolls.enabled) then
								local folder = nil
								for i,v in next, workspace:GetChildren() do
									if (v.Name:find("scrolltime") == 1 and v:IsA("Folder")) then
										folder = v
										break
									end
								end

								if (game.PlaceId == 5824792748) then
									folder = workspace
								end

								claim_scrolls(scan_for_scrolls(folder or workspace:FindFirstChild('GLOBALTIME')))
								claim_scrolls(scan_for_scrolls(workspace))
							end
							
							if (is_lg_premium and config.scrolls.hop) then
								for index, name in next, config.scrolls.selected do
									if (Library.running and config.scrolls.hop and not found and not hopping and can_hop(name)) then
										-- printDebug('[AUTOHOP]', name)
										print(`[AUTOHOP] {name}`)
										local scroll = scrolls[name]

										if (not scroll) then continue end

										local id = tostring(scroll.place.id)
										hopping = true
										if (not teleports_config.use_codes) then -- this is actually the opposite
											task.spawn(function()
												game:GetService("TeleportService").TeleportInitFailed:Wait()
												if (config.webhook.autohop) then
													webhook_main:send("Autohop", "Failed to autohop, rejoining to a public server to try again", "Shindo Life • REWRITE")
												end
												game:GetService("TeleportService"):Teleport(tonumber(id))
											end)

											task.spawn(function()
												if not gamepasses.privateservers then
													task.spawn(function()
														local ojid = game.JobId
														local url = `https://games.roblox.com/v1/games/{id}/servers/Public?sortOrder=Asc&limit=100`
														local data = JSON:parse(game:HttpGet(url)).data

														local jid = data[math.random(1, #data)].id
														
														while jid == ojid do
															jid = data[math.random(1, #data)].id
															task.wait()
														end

														game:GetService("TeleportService"):TeleportToPlaceInstance(tonumber(id), jid, lp)
															-- return JSON:parse(Raw)
														-- end
													end)
												else
													lp.startevent:FireServer("createprivateserver", tonumber(id))
													if (config.webhook.autohop) then
														scroll_name = scroll and scroll.name or 'N/A'
														webhook_main:send("Autohop", ("Autohopping to %s\nLooking for **%s** (%s)\nWith private server gamepass"):format(scroll.place.name, name, scroll_name), "Shindo Life • REWRITE")
													end
												end
												task.wait(10)
												hopping = false
											end)
										else
											local codes = privateCodes[id]
											if (codes) then
												local code = remove(codes, 1)
												if (code) then
													insert(codes, code)
													writefile('Raz Hub/Shindo Life/codes' .. '/' .. id .. '.txt', JSON:stringify(privateCodes[id]))
													lp:WaitForChild("startevent"):FireServer("teleporttoprivate", code)
													if (config.webhook.autohop) then
														scroll_name = scroll and scroll.name or 'N/A'
														webhook_main:send("Autohop", ("Autohopping to %s\nLooking for **%s** (%s)\nWith private server code"):format(scroll.place.name, name, scroll_name), "Shindo Life • REWRITE")
													end
													task.wait(30)
												end
											end
											hopping = false
										end
									end
								end
							end
							task.wait()
						end
					end)
				end)
			end
		end

		local spam_keys_section = tab:AddSubsection("Spam Keys")
		do
			local KeyService = {}
			do
				local twait = task.wait
				local byte = string.byte
	
				function KeyService:SimulateKeyPress(char, remote)
					if (remote) then
						remote:FireServer("key", char)
					else
						services.virtualuser:SetKeyDown(byte(tostring(char)))
					end
					twait()
					if (remote) then
						remote:FireServer("key", char .. "end")
					else
						services.virtualuser:SetKeyUp(byte(tostring(char)))
					end
				end
	
				function KeyService:SimulateKeyDown(char, remote)
					if (remote) then
						remote:FireServer("key", char)
					else
						services.virtualuser:SetKeyDown(byte(tostring(char)))
					end
				end
	
				function KeyService:SimulateKeyUp(char, remote)
					if (remote) then
						remote:FireServer("key", char .. "end")
					else
						services.virtualuser:SetKeyUp(byte(tostring(char)))
					end
				end
			end

			local integrity = {}
			spam_keys_section:AddToggle("Enabled", config.spam_keys.enabled, function(t)
				local int = {}
				integrity = int
				config.spam_keys.enabled = t
				config:set('spam_keys', config.spam_keys)

				local combat, update, functions;
				local character = lp.Character or lp.CharacterAdded:Wait()
				local currentmission = lp:WaitForChild("currentmission")
				task.spawn(function()
					while (Library.running) do
						character = lp.Character
						print_debug(0, 'got character?', character)
						combat = character and character:FindFirstChild("combat")
						update = combat and combat:FindFirstChild("update")
						functions = combat and combat:FindFirstChild("functions")
						print_debug(0, character, combat, update, functions)
						if (not (character and combat and update and functions)) then
							task.wait()
							continue
						end

						lp.CharacterRemoving:Wait()
						character = nil
						combat = nil
						update = nil
						functions = nil
						lp.CharacterAdded:Wait()
					end
				end)

				local function is_same_model(model)
					return not is_doing_nocooldown and Library.running and config.spam_keys.enabled and model == character
				end

				while (Library.running and config.spam_keys.enabled and integrity == int) do
					if (not is_doing_nocooldown and character and combat and update and functions) then
						print_debug(2, 'Top-level loop - spam_keys enabled')
						local current_char = character
						local trigger_spam = false

						if (force_spam) then
							trigger_spam = true
						elseif (use_spam) then
							trigger_spam = true
						elseif (not config.spam_keys.missions_only or currentmission.Value) then
							trigger_spam = true
						elseif (workspace:FindFirstChild('warserver') and not workspace:FindFirstChild('dungeons')) then
							trigger_spam = true
						end

						if (trigger_spam) then
							for char, boolean in next, config.spam_keys.selected do
								if (not boolean) then continue end
								if (char:find('+')) then
									local s = char:split('+')
									while (is_same_model(current_char) and not functions.mouse2.Value) do update:FireServer("mouse2", true) task.wait() end
									while (is_same_model(current_char) and functions.mouse2.Value and functions.key.Value ~= s[2]:lower()) do update:FireServer("key", s[2]:lower()) task.wait() end
									while (is_same_model(current_char) and functions.mouse2.Value and functions.key.Value ~= (s[2]:lower() .. "end")) do update:FireServer("key", s[2]:lower() .. "end") task.wait() end
									while (is_same_model(current_char) and functions.mouse2.Value) do update:FireServer("mouse2", false) task.wait() end
								elseif (update) then
									KeyService:SimulateKeyPress(char:lower(), update)
								end
							end
						end
					end
					task.wait()
				end
			end)

			spam_keys_section:AddToggle("Missions Only", config.spam_keys.missions_only, function(t)
				config.spam_keys.missions_only = t
				config:set('spam_keys', config.spam_keys)
			end)

			local keys = spam_keys_section:AddDropdown("Selection", nil, true, function(option, is_toggled)
				config.spam_keys.selected[option] = is_toggled
				config:set('spam_keys', config.spam_keys)
			end)

			keys:Add('RMB+Z', config.spam_keys.selected['RMB+Z'])
			keys:Add('RMB+E', config.spam_keys.selected['RMB+E'])
			keys:Add('RMB+Q', config.spam_keys.selected['RMB+Q'])
			for i,v in next, ("rtyfghzeqvbn"):split('') do
				keys:Add(v:upper(), config.spam_keys.selected[v:upper()])
			end
		end
	end

	local auto_farm_section = tab:AddSubsection("Auto Farm Settings")
	do
		if (is_lg_premium) then
			if (config.autofarm.enabled) then
				local yes, no = false, false
				Library:Verification("Would you like to stop autofarming?", 5, function(y, n)
					yes, no = y, n
				end)
			
				if (yes) then
					config.autofarm.enabled = false
					config:set('autofarm', config.autofarm)
				end
			end

			af_toggle = auto_farm_section:AddToggle('Auto Farm (upon execution)', config.autofarm.enabled, function(t)
				is_farming = t
				config.autofarm.enabled = t
				config:set('autofarm', config.autofarm)
			end)
		end

		auto_farm_section:AddSlider('Height', config.autofarm.height, -500, 500, function(n)
			config.autofarm.height = n
			config:set('autofarm', config.autofarm)
		end)

		auto_farm_section:AddSlider('Distance', config.autofarm.distance, -500, 500, function(n)
			config.autofarm.distance = n
			config:set('autofarm', config.autofarm)
		end)
	end

	-- Discord Webhook
	local Webhook = tab:AddSubsection("Discord Webhook")
	do
		Webhook:AddTextBox("Webhook Url", webhook_settings.url, function(text)
			if (webhook_settings.url ~= text) then
				webhook_settings:set("url", text)
				
				webhook_main:setUrl(text)
				webhook_main:send("Kesh Hub Logger - TEST", "This is a test lol", "Shindo Life • REWRITE")
			end
		end)

		local Selection = Webhook:AddDropdown("Logs Selection", nil, true, function(option)
			config.webhook[option:lower()] = not config.webhook[option:lower()]
			
			config:set('webhook', config.webhook)
			if (config.webhook.reminder) then
				webhook_main:send("Kesh Hub Logger", ("**%s** has been turned %s"):format(tostring(option), config.webhook[option:lower()] and 'on' or 'off'), 'Shindo Life • REWRITE')
			end
		end)

		Selection:Add("Scrolls", config.webhook.scrolls)
		Selection:Add("Spins", config.webhook.spins)
		Selection:Add("Autohop", config.webhook.autohop)
		Selection:Add("Reminder", config.webhook.reminder)

		webhook_main:setUrl(webhook_settings.url)
		webhook_config = config

		local function create_timestamp(f)
			f = f or 'R'
			return ('<t:%s:%s>'):format(tostring(os.time()), f)
		end

		if (config.webhook.reminder) then
			webhook_main:send('', 'Script fully loaded since ' .. create_timestamp(), 'Shindo Life • REWRITE')
		end

		task.spawn(function()
			local s = 0
			local last = 0
			while (Library.running) do
				if (config.webhook.reminder and (tick()-last) > 120) then
					local statz = lp:FindFirstChild('statz')
					local lvl = 0
					local mode = 'N/A'
					local cash = 0
					local spins = 0
					if (statz) then
						local _lvl = statz:FindFirstChild('lvl')
						local _spins = statz:FindFirstChild('spins')
						local _cash = statz:FindFirstChild('cash')
						local keys = statz:FindFirstChild('keys')
						if (keys) then
							local z = keys:FindFirstChild('z')
							if (z and z.Value ~= '') then
								mode = z.Value
							end
						end

						if (_lvl and _spins and _cash) then
							lvl = _lvl.lvl.Value
							spins = _spins.Value
							cash = _cash.Value
						end
					end
					webhook_main:send('Reminder', 'Shindo Life script is currently running...\r\n' .. create_timestamp('F') .. (
						'```json\r\n{\r\n\t"Level": %s,\r\n\t"Mode": "%s",\r\n\t"Cash": %s,\r\n\t"Spins": %s\r\n}```'
					):format(tostring(lvl), tostring(mode), tostring(cash), tostring(spins)), 'Shindo Life • REWRITE')
					last = tick()
					s = 120
				end
				task.wait(s)
				s = 0
			end
		end)
	end
end)

-- if (game.PlaceId ~= 4616652839 and game.PlaceId ~= 7524809704) then
-- 	Loader:set('Waiting for character to load...')
-- 	while (not workspace:FindFirstChild(lp.Name)) do
-- 		task.wait()
-- 	end
-- end

-- set loader text
Loader:set('Applying anti-cheat bypass...')
-- wait til the render frame is next
task.wait()

-- does not pause the script execution
task.spawn(function()
	local char = lp.Character;
	local _end = false
	do
		task.spawn(function()
			while (Library.running) do
				if (not char) then
					char = lp.CharacterAdded:Wait()
				end
				lp.CharacterRemoving:Wait()
				char = nil
			end
		end)

		task.spawn(function()
			while (Library.running) do wait() end
			_end = true
		end)
	end

	local coreCall do
		local MAX_RETRIES = 8
	
		local StarterGui = game:GetService('StarterGui')
		local RunService = game:GetService('RunService')
	
		coreCall = function(method, ...)
			local result = {}
			for retries = 1, MAX_RETRIES do
				result = {pcall(StarterGui[method], StarterGui, ...)}
				if result[1] then
					break
				end
				RunService.Stepped:Wait()
			end
			return unpack(result)
		end
	end
		
	local current = services.userinputservice.MouseBehavior
	local current2 = services.userinputservice.OverrideMouseIconBehavior
	local __index = hookmetamethod(game, '__index', (function(...)
		if (_end or checkcaller()) then return shared.__khrindex(...) end
		local self, key = ...

		if (not checkcaller() and key ~= 'Name') then
			if (client_settings.semi_godmode) then
				local name = self.Name

				if (name == 'Humanoid' and key == 'Health') then
					return 5
				end

				if (name == 'fakehealth' and key == 'Value') then
					return 9e9
				end

				if (char == self and key == 'fakehealth') then
					return fakehealth
				end
			end

			if (self == mouse) then
				local v3 = track_v3
				if (v3 and (key == 'X' or key == 'Y')) then
					return v3[key]
				end
			end
		end

		return shared.__khrindex(...)
	end))
	-- last hook which will go to the first __newindex hook eventually
	local __newindex = hookmetamethod(game, '__newindex', (function(...)
		if (_end or checkcaller()) then return shared.__khrnewindex2(...) end
		local self, key, value = ...

		if (self.Parent == char) then
			if (self.Name == 'Humanoid') then
				if (key == 'WalkSpeed' and client_settings.ws.enabled) then
					value = client_settings.ws.value
				end

				if (key == 'JumpPower' and client_settings.jp.enabled) then
					value = client_settings.jp.value
				end
			end

			return shared.__khrnewindex2(self, key, value)
		end

		if (key == 'Parent') then
			if (self == lp.Character and value ~= workspace) then return end
			if (typeof(value) == 'Instance' and value.Name == 'ClientEffects' and client_settings.remove_effects) then
				return
			end
		end

		if (self == services.userinputservice) then
			if (key == 'MouseBehavior') then
				current = value
			elseif (key == 'OverrideMouseIconBehavior') then
				current2 = value
			end
		end

		return shared.__khrnewindex2(...)
	end))

	local old_fakehealth = nil

	local __namecall = hookmetamethod(game, '__namecall', (function(...)
		local args = {...}
		local self = remove(args, 1)
		local method = getnamecallmethod()

		-- if (not checkcaller() and method == 'SetCore') then
		-- 	return
		-- end

		if (not checkcaller() and method == 'FindFirstChild') then
			if (args[1] == 'fakehealth') then
				old_fakehealth = shared.__khrnamecall(...)
				
				if (client_settings.semi_godmode) then
					return fakehealth
				end
			end
		end

		return shared.__khrnamecall(...)
	end))

	shared.__khrindex = shared.__khrindex or __index
	shared.__khrnewindex2 = shared.__khrnewindex2 or __newindex
	shared.__khrnamecall = shared.__khrnamecall or __namecall

	while (Library.running) do
		local visible = Library.Window.Visible;
		-- services.userinputservice.MouseIconEnabled = visible;
		services.userinputservice.MouseBehavior = visible and Enum.MouseBehavior.Default or current or Enum.MouseBehavior.LockCenter

		if (client_settings.semi_godmode) then
			fakehealth.Value = 9e9
			local stayonground = char and char:FindFirstChild("stayonground")
			if (stayonground) then
				stayonground:Destroy()
			end
		end

		coreCall('SetCore', 'ResetButtonCallback', true)

		task.wait()
	end
end)

-- close loader
Loader:done()
-- turn on gui
Library.GUI.Enabled = true
end)()
