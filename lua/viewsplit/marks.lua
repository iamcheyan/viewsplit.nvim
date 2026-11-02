local M = {}

local function valid_name(name)
  return type(name) == "string" and #name == 1 and name:match("^[a-z]$") ~= nil
end

function M.set(state, name, pos)
  if not state or not valid_name(name) or type(pos) ~= "table" or type(pos[1]) ~= "number" or type(pos[2]) ~= "number" then
    return false
  end
  state.marks = state.marks or {}
  state.marks[name] = { row = pos[1], col = pos[2] }
  return true
end

function M.get(state, name)
  if not state or not valid_name(name) then return nil end
  local mark = state.marks and state.marks[name]
  return mark and { mark.row, mark.col } or nil
end

function M.delete(state, name)
  if not state or not valid_name(name) then return false end
  if not state.marks or not state.marks[name] then return false end
  state.marks[name] = nil
  return true
end

return M
