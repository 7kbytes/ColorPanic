--!strict
-- Who a spectator watches and what the eliminated card says (D-14). Kept pure so it can be
-- tested outside Studio. The players to watch come from the MatchRole attribute the server
-- sets; watching only moves the local camera and never reaches the server.

export type Candidate = { userId: number, name: string, role: string? }

export type Card = { title: string, subtitle: string }

local SpectateModel = {}

-- Survivors other than `selfId`, sorted by name (then userId), so every client steps through
-- them in the same order.
function SpectateModel.targets(players: { Candidate }, selfId: number): { Candidate }
	local list: { Candidate } = {}
	for _, candidate in players do
		if candidate.role == "Survivor" and candidate.userId ~= selfId then
			table.insert(list, candidate)
		end
	end
	table.sort(list, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.userId < b.userId
	end)
	return list
end

local function indexOf(targets: { Candidate }, userId: number?): number?
	if userId == nil then
		return nil
	end
	for index, candidate in targets do
		if candidate.userId == userId then
			return index
		end
	end
	return nil
end

-- Keeps watching `currentId` while they are still a target, otherwise the first target.
-- nil when nobody is left to watch.
function SpectateModel.pick(targets: { Candidate }, currentId: number?): number?
	if indexOf(targets, currentId) then
		return currentId
	end
	local first = targets[1]
	return if first then first.userId else nil
end

-- The next (`direction` 1) or previous (-1) target after `currentId`, wrapping at the ends.
function SpectateModel.step(targets: { Candidate }, currentId: number?, direction: number): number?
	local count = #targets
	if count == 0 then
		return nil
	end
	local index = indexOf(targets, currentId)
	if index == nil then
		return targets[1].userId
	end
	local nextIndex = ((index - 1 + direction) % count) + 1
	return targets[nextIndex].userId
end

-- The eliminated card for a player knocked out at the end of `round`: they survived the rounds
-- before it. `round` is nil if the round number has not arrived.
function SpectateModel.card(round: number?): Card
	local survived = if round then round - 1 else nil
	local subtitle: string
	if survived == nil then
		subtitle = "Better luck next match"
	elseif survived <= 0 then
		subtitle = "Out in round 1"
	elseif survived == 1 then
		subtitle = "You survived 1 round"
	else
		subtitle = string.format("You survived %d rounds", survived)
	end
	return { title = "You're out!", subtitle = subtitle }
end

return SpectateModel
