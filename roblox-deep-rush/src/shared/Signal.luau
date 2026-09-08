--!nonstrict
--[[
	Signal.luau — a minimal observer, used by the client state store.

	BindableEvents would work, but they deep-copy tables across the boundary,
	which quietly breaks patch objects. This does not.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:connect(handler: (...any) -> ())
	local entry = { handler = handler }
	table.insert(self._handlers, entry)

	return {
		disconnect = function()
			local index = table.find(self._handlers, entry)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

function Signal:fire(...)
	-- Iterate a copy: a handler is allowed to disconnect itself.
	local snapshot = table.clone(self._handlers)
	for _, entry in ipairs(snapshot) do
		local ok, err = pcall(entry.handler, ...)
		if not ok then
			warn("DeepRush: signal handler error: " .. tostring(err))
		end
	end
end

function Signal:destroy()
	table.clear(self._handlers)
end

return Signal
