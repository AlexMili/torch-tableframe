require 'lfs'
require 'torch'

-- Make sure that directory structure is always the same
if (string.match(lfs.currentdir(), "/specs$")) then
  lfs.chdir("..")
end

-- Include Dataframe lib
paths.dofile('init.lua')

-- Go into specs so that the loading of CSV:s is the same as always
lfs.chdir("specs")

describe("Row functions", function()
  it("Inserts new data",function()
		local a = Dataframe("./data/simple_short.csv")

		a:append(Df_Dict({['Col A']={15},['Col B']={25},['Col C']={35}}))
		assert.are.same(a:shape(), {rows=5, cols=3})-- "The simple_short.csv is 4x3 after insert should be 5x3"
	end)

	it("Removes a row given an index",function()
		local a = Dataframe("./data/simple_short.csv")

		a:remove_index(1)
		assert.are.same(a:shape(), {rows=3, cols=3})-- "The simple_short.csv is 4x3"
		assert.are.same(a:get_column('Col A'), {2,3,4})

		a:remove_index(1)
		a:remove_index(1)
		a:remove_index(1)
		assert.are.same(a:shape(), {rows=0, cols=3})
	end)
end)
