local function split_with_delimiters(text, code_start, code_end)
	local in_code = false
	local last_code = ""
	local result = {}
	local read_pos = 1

	while read_pos <= #text do
		if not in_code then
			local next_code_pos = string.find(text, code_start, read_pos)
			if next_code_pos == nil then
				-- take the rest
				next_code_pos = #text + 1
			end
			local sub_text = string.sub(text, read_pos, next_code_pos - 1)
			if sub_text ~= "" then
				table.insert(result, { condition = last_code, text = sub_text })
			end
			read_pos = next_code_pos + #code_start
			in_code = true
		else
			local next_text_pos = string.find(text, code_end, read_pos)
			if next_text_pos == nil then
				-- this may not happen!
				error("code block never closed")
				return nil
			end
			last_code = string.sub(text, read_pos, next_text_pos - 1):gsub("^%s*(.-)%s*$", "%1")
			read_pos = next_text_pos + #code_end
			in_code = false
		end
	end
	return result
end

local function split(text)
	return split_with_delimiters(text, "{{", "}}")
end

local function render_fragment(steps, frag_index)
	-- how often has the fragment function been called
	local calls_to_frag = 0

	-- set to false, if any function says there are more fragments to come
	local is_last_fragment = true

	-- stored for otherwise
	local last_visible = true

	-- context with the functions thah can be called
	local context = {
		all = function()
			-- always render
			return true
		end,

		fragment = function()
			-- step into next fragment
			calls_to_frag = calls_to_frag + 1
			local visible = calls_to_frag <= frag_index
			if not visible then
				-- if we are not visible yet, we will change in a later fragment
				is_last_fragment = false
			end
			return visible
		end,

		otherwise = function()
			return not last_visible
		end,

		reset_fragment = function(new_calls_to_frag)
			-- reset the call count
			calls_to_frag = new_calls_to_frag
			local visible = calls_to_frag <= frag_index
			if not visible then
				-- same as with fragment
				is_last_fragment = false
			end
			return visible
		end,

		only = function(only_frags)
			-- test if ther are more steps to come
			if math.max(table.unpack(only_frags)) >= frag_index then
				is_last_fragment = false
			end
			for _, test_step in ipairs(only_frags) do
				if test_step == frag_index then
					return true
				end
				return false
			end
		end,

		except = function(except_frags)
			-- test if ther are more steps to come
			if math.max(table.unpack(except_frags)) >= frag_index then
				is_last_fragment = false
			end
			for _, test_step in ipairs(except_frags) do
				if test_step == frag_index then
					return false
				end
				return true
			end
		end,
	}

	-- setup synonyms
	context["frag"] = context["fragment"]
	context["reset_frag"] = context["reset_fragment"]
	context["other"] = context["otherwise"]

	-- the final rendered fragment
	local result = ""

	for i, step in ipairs(steps) do
		local visible = true -- default for empyt string

		if step.condition ~= "" then
			visible = load("return " .. step.condition, nil, nil, context)()
		end

		if type(visible) ~= "boolean" then
			error("value " .. step.condition .. "did not evaluate to type boolean")
		end

		last_visible = visible

		if visible then
			result = result .. step.text
		end
	end

	return result, is_last_fragment
end

local function render_all_fragments(conditional_blocks)
	local fragment_index = 0
	local last_step = false
	local result = {}

	while not last_step do
		local rendered, is_last = render_fragment(conditional_blocks, fragment_index)
		fragment_index = fragment_index + 1
		table.insert(result, rendered)
		last_step = is_last
	end

	return result
end

local function contains_one_of(list, values)
	for _, value in ipairs(values) do
		for _, list_value in ipairs(list) do
			if value == list_value then
				return true
			end
		end
	end
	return false
end

local function code_block(block)
	if contains_one_of(block.classes, { "inc", "incremental" }) then
		local conditional_blocks = split(block.text)
		local code_blocks = {}

		-- filter the clases specific to us
		local block_classes = {}
		for _, class in ipairs(block.classes) do
			if class ~= "inc" and class ~= " incremental" then
				table.insert(block_classes, class)
			end
		end

		-- filter the attributes, specific to us
		local block_attributes = {}
		for key, value in pairs(block.attributes) do
			if key ~= "gravity" then
				block_attributes[key] = value
			end
		end

		local block_attr = pandoc.Attr(block.identifier, block_classes, block_attributes)

		for index, rendered in ipairs(render_all_fragments(conditional_blocks)) do
			local div_attrs = { class = "fragment" }
			-- assign the framgent properties
			if index == 1 then
				div_attrs["class"] = div_attrs["class"] .. " fade-out"
				div_attrs["data-fragment-index"] = 0
			elseif index == 2 then
				div_attrs["class"] = div_attrs["class"] .. " fade-in-then-out"
				div_attrs["data-fragment-index"] = 0
			elseif index == #rendered then
				div_attrs["class"] = div_attrs["class"] .. " fade-in"
			else
				div_attrs["class"] = div_attrs["class"] .. " fade-in-then-out"
			end

			div_attrs["style"] = "display: flex;"
			div_attrs["magin"] = "auto auto auto auto"

			if block.attributes["gravity"] == "topleft" then
				div_attrs["magin"] = "0 auto auto 0"
			elseif block.attributes["gravity"] == "top" then
				div_attrs["magin"] = "0 auto auto auto"
			elseif block.attributes["gravity"] == "topright" then
				div_attrs["magin"] = "0 0 auto auto"
			elseif block.attributes["gravity"] == "right" then
				div_attrs["magin"] = "auto 0 auto auto"
			elseif block.attributes["gravity"] == "bottomright" then
				div_attrs["magin"] = "auto 0 0 auto"
			elseif block.attributes["gravity"] == "bottom" then
				div_attrs["magin"] = "auto auto 0 auto"
			elseif block.attributes["gravity"] == "bottomleft" then
				div_attrs["magin"] = "auto auto 0 0"
			elseif block.attributes["gravity"] == "left" then
				div_attrs["magin"] = "auto auto auto 0"
			end

			table.insert(code_blocks, pandoc.Div(pandoc.CodeBlock(rendered, block_attr), pandoc.Attr(div_attrs)))
		end

		return pandoc.Div({
			pandoc.Div(
				code_blocks,
				pandoc.Attr({ class = "r-stack", style = "height: fit-content; width: fit-content; margin: auto" })
			),
		})
	end
end

return {
	{
		split_with_delimiters = split_with_delimiters,
		split = split,
		render_fragment = render_fragment,
		render_all_fragments = render_all_fragments,
		CodeBlock = code_block,
	},
}
