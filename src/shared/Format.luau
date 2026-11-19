local Format = {}
local units = { { 1e15, "Q" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }

function Format.Number(value)
	for _, unit in ipairs(units) do
		if math.abs(value) >= unit[1] then
			return (string.format("%.1f%s", value / unit[1], unit[2]):gsub("%.0(%a)$", "%1"))
		end
	end
	return tostring(math.floor(value))
end

function Format.Money(value)
	return "$" .. Format.Number(value)
end

return table.freeze(Format)
