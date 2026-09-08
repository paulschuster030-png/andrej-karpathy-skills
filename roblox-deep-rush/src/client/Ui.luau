--!nonstrict
--[[
	Ui.luau — the smallest possible UI kit.

	Roblox has no styling layer, so without something like this every panel
	re-implements corners, strokes and fonts slightly differently and the
	game starts to look homemade. One theme table, five constructors.

	Sizing is deliberately chunky: most Roblox sessions are on a phone, and a
	button smaller than ~48px is a button that gets missed mid-fall.
]]

local Ui = {}

Ui.THEME = {
	bg = Color3.fromRGB(12, 12, 18),
	panel = Color3.fromRGB(22, 22, 32),
	panelLight = Color3.fromRGB(34, 34, 48),
	text = Color3.fromRGB(240, 240, 250),
	muted = Color3.fromRGB(150, 150, 172),
	accent = Color3.fromRGB(255, 88, 120),
	gold = Color3.fromRGB(255, 205, 90),
	cyan = Color3.fromRGB(110, 230, 255),
	green = Color3.fromRGB(110, 235, 160),
	danger = Color3.fromRGB(255, 80, 80),
}

function Ui.corner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

function Ui.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Ui.THEME.panelLight
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0
	stroke.Parent = instance
	return stroke
end

function Ui.padding(instance: Instance, amount: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, amount)
	padding.PaddingBottom = UDim.new(0, amount)
	padding.PaddingLeft = UDim.new(0, amount)
	padding.PaddingRight = UDim.new(0, amount)
	padding.Parent = instance
	return padding
end

function Ui.frame(props)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Ui.THEME.panel
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromOffset(100, 100)
	frame.Position = props.position or UDim2.fromOffset(0, 0)
	frame.AnchorPoint = props.anchor or Vector2.new(0, 0)
	frame.Visible = props.visible ~= false
	frame.ZIndex = props.z or 1
	frame.Name = props.name or "Frame"
	if props.radius ~= false then
		Ui.corner(frame, props.radius)
	end
	frame.Parent = props.parent
	return frame
end

function Ui.text(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.fromOffset(0, 0)
	label.AnchorPoint = props.anchor or Vector2.new(0, 0)
	label.Font = props.font or Enum.Font.GothamBold
	label.Text = props.text or ""
	label.TextColor3 = props.color or Ui.THEME.text
	label.TextScaled = props.scaled ~= false
	label.TextXAlignment = props.align or Enum.TextXAlignment.Center
	label.TextYAlignment = props.valign or Enum.TextYAlignment.Center
	label.TextWrapped = props.wrap or false
	label.ZIndex = props.z or 2
	label.Name = props.name or "Label"
	label.Visible = props.visible ~= false
	if not label.TextScaled then
		label.TextSize = props.textSize or 16
	end
	label.Parent = props.parent
	return label
end

--- A button that visibly reacts. The press animation is not decoration: on
--- mobile, without it a player cannot tell whether their tap registered.
function Ui.button(props)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.color or Ui.THEME.panelLight
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.fromOffset(120, 48)
	button.Position = props.position or UDim2.fromOffset(0, 0)
	button.AnchorPoint = props.anchor or Vector2.new(0, 0)
	button.Font = props.font or Enum.Font.GothamBlack
	button.Text = props.text or ""
	button.TextColor3 = props.textColor or Ui.THEME.text
	button.TextScaled = props.scaled ~= false
	button.AutoButtonColor = false
	button.ZIndex = props.z or 2
	button.Name = props.name or "Button"
	button.Visible = props.visible ~= false
	Ui.corner(button, props.radius)
	if props.stroke then
		Ui.stroke(button, props.stroke, 2)
	end

	local base = button.BackgroundColor3
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.12)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = base
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = base:Lerp(Color3.new(0, 0, 0), 0.2)
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = base
	end)

	if props.onClick then
		button.Activated:Connect(props.onClick)
	end

	button.Parent = props.parent
	return button
end

--- A labelled progress bar. Returns the fill frame so the caller can drive
--- it without re-querying children every frame.
function Ui.bar(props)
	local holder = Ui.frame({
		parent = props.parent,
		size = props.size,
		position = props.position,
		anchor = props.anchor,
		color = props.background or Ui.THEME.bg,
		radius = props.radius or 8,
		z = props.z,
	})

	local fill = Ui.frame({
		parent = holder,
		size = UDim2.fromScale(0, 1),
		color = props.color or Ui.THEME.cyan,
		radius = props.radius or 8,
		z = (props.z or 1) + 1,
	})

	local label = Ui.text({
		parent = holder,
		text = props.text or "",
		scaled = false,
		textSize = props.textSize or 14,
		z = (props.z or 1) + 2,
	})

	return holder, fill, label
end

return Ui
