require("busted.runner")()

-- add local path to package list
package.path = "./?.lua;" .. package.path
local filter = require("fragment_code_blocks")[1]

describe("test splitting code blocks into conditions and text", function()
	it("split with code at beginning", function()
		-- setup
		local input = [[{{ code }}text
text
]]
		-- act
		local splitted = filter.split(input)
		--split =
		assert.are.same({ { condition = "code", text = "text\ntext\n" } }, splitted)
	end)

	it("split with code in the middle", function()
		-- setup
		local input = [[text
{{ code }}
text
]]
		-- act
		local splitted = filter.split(input)
		--split =
		assert.are.same({
			{ condition = "", text = "text\n" },
			{ condition = "code", text = "\ntext\n" },
		}, splitted)
	end)

	it("split with code at end", function()
		-- setup
		local input = [[text
{{ code }}]]
		-- act
		local splitted = filter.split(input)
		--split =
		assert.are.same({
			{ condition = "", text = "text\n" },
		}, splitted)
	end)

	it("multiple splits", function()
		-- setup
		local input = [[text
{{ code }}
text
{{ code2 }}
text2
]]
		-- act
		local splitted = filter.split(input)
		--split =
		assert.are.same({
			{ condition = "", text = "text\n" },
			{ condition = "code", text = "\ntext\n" },
			{ condition = "code2", text = "\ntext2\n" },
		}, splitted)
	end)

	describe("generating fragments", function()
		it("generate single fragment with no condition", function()
			-- setup
			local input = { { condition = "", text = "text" } }

			-- act
			local fragment, is_last = filter.render_fragment(input, 0)

			-- test
			assert.are.same(true, is_last)
			assert.are.same("text", fragment)
		end)

		it("put all into fragment when all is called", function()
			-- setup
			local input = { { condition = "all()", text = "text" } }

			-- act
			local fragment, is_last = filter.render_fragment(input, 0)

			-- test
			assert.are.same("text", fragment)
			assert.are.same(true, is_last)
		end)

		it("render multiple fragments", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "f1" },
				{ condition = "fragment()", text = "f2" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local fragment0, is_last_index0 = filter.render_fragment(input, 0)
			local fragment1, is_last_index1 = filter.render_fragment(input, 1)
			local fragment2, is_last_index2 = filter.render_fragment(input, 2)

			-- test
			assert.are.same("ba", fragment0)
			assert.are.same(false, is_last_index0)
			assert.are.same("bf1a", fragment1)
			assert.are.same(false, is_last_index1)
			assert.are.same("bf1f2a", fragment2)
			assert.are.same(true, is_last_index2)
		end)

		it("render all fragments in on call", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "f1" },
				{ condition = "fragment()", text = "f2" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local fragments = filter.render_all_fragments(input)

			-- test
			assert.are.same(3, #fragments)
			assert.are.same("ba", fragments[1])
			assert.are.same("bf1a", fragments[2])
			assert.are.same("bf1f2a", fragments[3])
		end)

		it("otherwiese condition", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "s" },
				{ condition = "otherwise()", text = "t" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local fragments = filter.render_all_fragments(input)

			-- test
			assert.are.same(2, #fragments)
			assert.are.same("bta", fragments[1])
			assert.are.same("bsa", fragments[2])
		end)

		it("reset_frag condition", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "f1" },
				{ condition = "frag()", text = "f2" },
				{ condition = "reset_frag(1)", text = "rf" },
				{ condition = "frag()", text = "rf2" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local rendered = filter.render_all_fragments(input)

			-- test
			assert.are.same(3, #rendered)
			assert.are.same("ba", rendered[1])
			assert.are.same("bf1rfa", rendered[2])
			assert.are.same("bf1f2rfrf2a", rendered[3])
		end)

		it("only condition", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "f1" },
				{ condition = "frag()", text = "f2" },
				{ condition = "only({1})", text = "o" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local rendered = filter.render_all_fragments(input)

			-- test
			assert.are.same(3, #rendered)
			assert.are.same("ba", rendered[1])
			assert.are.same("bf1oa", rendered[2])
			assert.are.same("bf1f2a", rendered[3])
		end)

		it("except condition", function()
			-- setup
			local input = {
				{ condition = "", text = "b" },
				{ condition = "frag()", text = "f1" },
				{ condition = "frag()", text = "f2" },
				{ condition = "except({1})", text = "e" },
				{ condition = "all()", text = "a" },
			}

			-- act
			local fragments = filter.render_all_fragments(input)

			-- test
			assert.are.same(3, #fragments)
			assert.are.same("bea", fragments[1])
			assert.are.same("bf1a", fragments[2])
			assert.are.same("bf1f2ea", fragments[3])
		end)
	end)
end)
