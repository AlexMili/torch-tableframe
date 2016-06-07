local params = {...}
local Dataframe = params[1]

local argcheck = require "argcheck"
local doc = require "argcheck.doc"

doc[[

## Subsetting and manipulation functions

]]

Dataframe.sub = argcheck{
	doc =  [[
<a name="Dataframe.sub">
### Dataframe.sub(@ARGP)

@ARGT

Selects a subset of rows and returns those

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='start', type='number', doc='Row to start at', default=1},
	{name="stop", type='number', doc='Last row to include', default=false},
	call = function(self, start, stop)
	if (not stop) then
		stop = self.n_rows
	end

	assert(start <= stop, "Stop argument can't be less than the start argument")
	assert(start > 0, "Start position can't be less than 1")
	assert(stop <= self.n_rows, "Stop position can't be more than available rows")

	local indexes = {}
	for i = start,stop do
		table.insert(indexes, i)
	end

	return self:_create_subset(Df_Array(indexes))
end}

Dataframe.get_random = argcheck{
	doc =  [[
<a name="Dataframe.get_random">
### Dataframe.get_random(@ARGP)

@ARGT

Retrieves a random number of rows for exploring

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='n_items', type='number', doc='Number of rows to retrieve', default=1},
	call = function(self, n_items)

	assert(isint(n_items), "The number must be an integer. You've provided " .. tostring(n_items))
	assert(n_items > 0 and
	       n_items < self.n_rows, "The number must be an integer between 0 and " ..
				 self.n_rows .. " - you've provided " .. tostring(n_items))
	local rperm = torch.randperm(self.n_rows)
	local indexes = {}
	for i = 1,n_items do
		table.insert(indexes, rperm[i])
	end
	return self:_create_subset(Df_Array(indexes))
end}

Dataframe.head = argcheck{
	doc =  [[
<a name="Dataframe.head">
### Dataframe.head(@ARGP)

@ARGT

Retrieves the first elements of a table

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='n_items', type='number', doc='Number of rows to retrieve', default=10},
	call = function(self, n_items)

	head = self:sub(1, math.min(n_items, self.n_rows))

	return head
end}

Dataframe.tail = argcheck{
	doc =  [[
<a name="Dataframe.tail">
### Dataframe.tail(@ARGP)

@ARGT

Retrieves the last elements of a table

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='n_items', type='number', doc='Number of rows to retrieve', default=10},
	call = function(self, n_items)

	start_pos = math.max(1, self.n_rows - n_items + 1)
	tail = self:sub(start_pos)

	return tail
end}

Dataframe._create_subset = argcheck{
	doc =  [[
<a name="Dataframe._create_subset">
### Dataframe._create_subset(@ARGP)

Creates a class and returns a subset based on the index items. Intended for internal
use. The method is primarily intended for internal use.

@ARGT

_Return value_: Dataframe or Batchframe
]],
	{name="self", type="Dataframe"},
	{name='index_items', type='Df_Array', doc='The indexes to retrieve'},
	{name='as_batchframe', type='boolean',
	 doc=[[Return a Batchframe with a different `to_tensor` functionality that allows
	 loading data, label tensors simultaneously]], default=false},
	call = function(self, index_items)
	index_items = index_items.data

	for i=1,#index_items do
		local val = index_items[i]
		assert(isint(val) and
		       val > 0 and
		       val <= self.n_rows,
		       "There are values outside the allowed index range 1 to " .. self.n_rows ..
		       ": " .. tostring(val))
	end

	-- TODO: for some reason the categorical causes errors in the loop, this strange copy fixes it
	-- The above is most likely to global variables beeing overwritten due to lack of local definintions
	local tmp = clone(self.categorical)
	self.categorical = {}
	local ret
	if (as_batchframe) then
		ret = Batchframe()
	else
		ret = Dataframe.new()
	end
	for _,i in pairs(index_items) do
		local val = self:get_row(i)
		if (ret:size(1) == 0) then
			ret:load_table(Df_Dict(val), Df_Dict(self.schema))
		else
			ret:append(Df_Dict(val))
		end
	end
	self.categorical = tmp
	ret = self:_copy_meta(ret)
	return ret
end}


--
-- where('column_name','my_value') :
--
-- ARGS: - column 		(required) [string] : column to browse or a condition_function that
--                                          takes a row and returns true/false depending
--                                          on the row values
--		 - item_to_find (required) [string] : value to find
--
-- RETURNS : Dataframe
--
Dataframe.where = argcheck{
	doc =  [[
<a name="Dataframe.where">
### Dataframe.where(@ARGP)

@ARGT

Find the rows where the column has the given value

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='column_name', type='string',
	 doc='column to browse or findin the item argument'},
	{name='item_to_find', type='number|string|boolean',
	 doc='The value to find'},
	call = function(self, column_name, item_to_find)

	return self:where(function(row)
		return row[column_name] == item_to_find
	end)
end}

Dataframe.where = argcheck{
	doc =  [[
You can also provide a function for more advanced matching

@ARGT

]],
	overload=Dataframe.where,
	{name="self", type="Dataframe"},
	{name='match_fn', type='function',
	 doc='Function that takes a row as an argument and returns boolean'},
	call = function(self, match_fn)
	local matches = self:which(match_fn)
	return self:_create_subset(Df_Array(matches))
end}

Dataframe.which = argcheck{
	doc =  [[
<a name="Dataframe.which">
### Dataframe.whic(@ARGP)

@ARGT

Finds the rows that match the arguments

_Return value_: table
]],
	{name="self", type="Dataframe"},
	{name="condition_function", type="function",
	 doc="Function that returns true if a condition is met. Received the entire row as a table argument."},
	call=function(self, condition_function)

	local matches = {}
	for i = 1, self.n_rows do
		local row = self:get_row(i)
		if condition_function(row) then
			table.insert(matches, i)
		end
	end

	return matches
end}

Dataframe.which = argcheck{
	doc =  [[
If you provide a value and a column it will look for identical matches

@ARGT

_Return value_: table
]],
	overload=Dataframe.which,
	{name="self", type="Dataframe"},
	{name="column_name", type="string",
	 doc="The column with the value"},
	{name="value", type="number|string|boolean|nan"},
	call=function(self, column_name, value)

	local values = self:get_column(column_name)
	local matches = {}
	if (isnan(value)) then
		for i = 1, self.n_rows do
			if isnan(values[i]) then
				table.insert(matches, i)
			end
		end
	else
		for i = 1, self.n_rows do
			local row = self:get_row(i)
			if values[i] == value then
				table.insert(matches, i)
			end
		end
	end

	return matches
end}

Dataframe.update = argcheck{
	doc =  [[
<a name="Dataframe.update">
### Dataframe.update(@ARGP)

@ARGT

_Return value_: void
]],
	{name="self", type="Dataframe"},
	{name='condition_function', type='function',
	 doc='Function that tests if the row should be updated. It should accept a row table as an argument and return boolean'},
	{name='update_function', type='function',
	 doc='Function that updates the row. Takes the entire row as an argument, modifies it and returns the same.'},
	call = function(self, condition_function, update_function)
	local matches = self:which(condition_function)
	for _, i in pairs(matches) do
		row = self:get_row(i)
		new_row = update_function(clone(row))
		self:_update_single_row(i, Df_Tbl(new_row), Df_Tbl(row))
	end
end}

-- Internal function to update a single row from data and index
Dataframe._update_single_row = argcheck{
	{name="self", type="Dataframe"},
	{name="index_row", type="number"},
	{name="new_row", type="Df_Tbl"},
	{name="old_row", type="Df_Tbl"},
	call=function(self, index_row, new_row, old_row)
	for i=1,#self.columns do
		local key = self.columns[i]
		if (new_row.data[key] ~= old_row.data[key] or
		    (isnan(new_row.data[key]) or
		     isnan(old_row.data[key]))) then
			if (self:is_categorical(key)) then
				new_row.data[key] = self:_get_raw_cat_key(key, new_row.data[key])
			end
			self.dataset[key][index_row] = new_row.data[key]
		end
	end
end}

Dataframe.set = argcheck{
	doc =  [[
<a name="Dataframe.set">
### Dataframe.set(@ARGP)

@ARGT

Change value for a line where a column has a certain value

_Return value_: void
]],
	{name="self", type="Dataframe"},
	{name='item_to_find', type='number|string|boolean',
	 doc='Value to search'},
	{name='column_name', type='string',
 	 doc='The name of the column'},
	 {name='new_value', type='Df_Dict',
 	 doc='Value to replace with'},
	call = function(self, item_to_find, column_name, new_value)
	assert(self:has_column(column_name), "Could not find column: " .. tostring(column_name))
	new_value = new_value.data

	temp_converted_cat_cols = {}
	column_data = self:get_column(column_name)
	for i = 1, self.n_rows do
		if column_data[i] == item_to_find then
			for _,k in pairs(self.columns) do
				-- If the column shoul be updated then the user should have set the key
				-- in the new_key table
				if new_value[k] ~= nil then
					if (self:is_categorical(k)) then
						new_value[k] = self:_get_raw_cat_key(column_name, new_value[k])
					end
					self.dataset[k][i] = new_value[k]
				end
			end
			break
		end
	end
end}

Dataframe.set = argcheck{
	doc =  [[
You can also provide the index that you want to set

@ARGT

_Return value_: void
]],
	overload=Dataframe.set,
	{name="self", type="Dataframe"},
	{name='index', type='number',
	 doc='Row index number'},
	{name='new_values', type='Df_Dict',
 	 doc='Value to replace with'},
	call = function(self, index, new_values)
	assert(isint(index), "The index should be an integer, you've provided " .. tostring(index))
	assert(index > 0 and index <= self.n_rows, ("The index (%d) is outside the bounds 1-%d"):format(index, self.n_rows))

	new_values = new_values.data

	for i=1,#self.columns do
		local key = self.columns[i]
		if (new_values[key] ~= nil) then
			if (self:is_categorical(key)) then
				new_values[key] = self:_get_raw_cat_key(key, new_values[key])
			end
			self.dataset[key][index] = new_values[key]
		end
	end
end}

Dataframe.wide2long = argcheck{
	doc = [[
<a name="Dataframe.wide2long">
### Dataframe.wide2long(@ARGP)

Change table from wide format, i.e. where a labels are split over multiple columns
into a case where all the values are in one column and adjacent is a column with
the column names.

@ARGT

_Return value_: Dataframe
]],
	{name="self", type="Dataframe"},
	{name='columns', type='Df_Array',
	 doc='The columns that are to be merged'},
	 {name='id_name', type='string',
 	 doc='The column name for where to store the old column names'},
	{name='value_name', type='string',
	 doc='The column name for where to store the values'},
	call = function(self, columns, id_name, value_name)
	columns = columns.data
	assert(not self:has_column(id_name), "The column name for the id's already exists")
	assert(not self:has_column(value_name), "The column name for the values already exists")
	for _,column_name in ipairs(columns) do
		assert(self:has_column(column_name), "The column name doesn't exist")
	end

	local ret = self:copy()
	ret:add_column(id_name)
	ret:add_column(value_name)

	local i = 1
	while i <= ret.n_rows do
		local row = ret:get_row(i)
		local first = true
		for _,column_name in ipairs(columns) do
			if (first) then
				local values = {}
				values[id_name] = column_name
				values[value_name] = row[column_name]
				if (isnan(values[value_name])) then
					values[id_name] = 0/0
				end
				first = false
				-- Just update the current row
				ret:set(i, Df_Dict(values))
			elseif (row[column_name] ~= nil and
			        row[column_name] ~= '' and
			        not isnan(row[column_name])) then
				row[id_name] = column_name
				row[value_name] = row[column_name]
				i = i + 1
				if (i > ret:size(1)) then
					ret:append(Df_Dict(row))
				else
					ret:insert(i, Df_Dict(row))
				end
			end
		end
		i = i + 1
	end

	for _,column_name in ipairs(columns) do
		ret:drop(column_name)
	end

	return ret
end}

Dataframe.wide2long = argcheck{
	doc = [[
You can also provide a regular expression for column names

@ARGT

]],
	overload=Dataframe.wide2long,
	{name="self", type="Dataframe"},
	{name='column_regex', type='string',
	 doc='Regular expression for the columns that are to be merged'},
	 {name='id_name', type='string',
 	 doc='The column name for where to store the old column names'},
	{name='value_name', type='string',
	 doc='The column name for where to store the values'},
	call = function(self, column_regex, id_name, value_name)
	local columns_2_merge = {}
	for _,column_name in ipairs(self.column_order) do
		if (column_name:match(column_regex)) then
			table.insert(columns_2_merge, column_name)
		end
	end
	assert(#columns_2_merge > 0, "Could not find columns that matched the regular expression: " .. column_regex)
	return self:wide2long(Df_Array(columns_2_merge), id_name, value_name)
end}
