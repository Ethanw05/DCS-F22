-- GPL-3.0-or-later. One bounded mailbox per numeric-entry owner.
local M = { command = 11800, maximum_sequence = 16777215 }
local fields = { 'REQUEST', 'ACTIVE', 'COMMAND', 'VALUE', 'ACK_REQUEST', 'RESULT', 'ACK_VALUE' }
local function finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1e9
end
function M.channel(lane, get, put)
    local prefix = 'F22_ENTRY_' .. lane .. '_'
    for _, field in ipairs(fields) do get(prefix .. field) end
    local channel = {}
    function channel.take(_self, sequence)
        if not finite(sequence) or sequence % 1 ~= 0 or sequence < 1
            or sequence > M.maximum_sequence or get(prefix .. 'ACTIVE') ~= 1
            or get(prefix .. 'REQUEST') ~= sequence
            or get(prefix .. 'ACK_REQUEST') >= sequence then return end
        local command, value = get(prefix .. 'COMMAND'), get(prefix .. 'VALUE')
        if not finite(command) or command % 1 ~= 0 or not finite(value) then return end
        return command, value
    end
    function channel.finish(_self, sequence, accepted, value)
        put(prefix .. 'ACK_VALUE', value or 0)
        put(prefix .. 'RESULT', accepted and 1 or 2)
        put(prefix .. 'ACK_REQUEST', sequence) -- Publish the completion last.
    end
    function channel.submit(_self, send, owner, command, value, read)
        local previous = get(prefix .. 'REQUEST')
        if not finite(previous) or previous < 0 or previous % 1 ~= 0
            or previous >= M.maximum_sequence then return nil, 'ENTRY CAPACITY' end
        local sequence = previous + 1
        put(prefix .. 'ACTIVE', 0)
        put(prefix .. 'COMMAND', command)
        put(prefix .. 'VALUE', value)
        put(prefix .. 'REQUEST', sequence)
        put(prefix .. 'ACTIVE', 1)
        local pending = {}
        function pending.cancel()
            if get(prefix .. 'REQUEST') == sequence then put(prefix .. 'ACTIVE', 0) end
        end
        function pending.read()
            return get(prefix .. 'ACK_REQUEST') == sequence and get(prefix .. 'RESULT') == 1
                and (not read or read())
        end
        function pending.error()
            if get(prefix .. 'ACK_REQUEST') == sequence and get(prefix .. 'RESULT') == 2 then
                return 'OWNER REJECTED'
            end
        end
        send(owner, M.command, sequence)
        return pending
    end
    return channel
end
return M
