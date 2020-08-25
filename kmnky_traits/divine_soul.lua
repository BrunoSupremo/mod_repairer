local DivineSoul = class()

local log = radiant.log.create_logger('kai')
function DivineSoul:initialize()
	self._sv._entity = nil
	self._sv._uri = nil
end

function DivineSoul:create(entity, uri)
	self._sv._entity = entity
	self._sv._uri = uri
end

function DivineSoul:activate()
	local json = radiant.resources.load_json(self._sv._uri)
	local player_id = self._sv._entity:get_player_id()
	local population = stonehearth.population:get_population(player_id)

	self.pop_listener = radiant.events.listen_once(population, 'stonehearth:population:citizen_count_changed', function()
		if not self._sv._entity:get_component('stonehearth:unit_info')._sv._made_divine_soul then
			local options = {}
			options.dont_drop_talisman = true
			options.skip_visual_effects = true
			local job_comp = self._sv._entity:get_component('stonehearth:job')
			local able_to_be_cleric = pcall(function()
				job_comp:promote_to('stonehearth:jobs:cleric', options)
			end)
			if able_to_be_cleric then
				local equip_comp = self._sv._entity:get_component('stonehearth:equipment')
				equip_comp:unequip_item('stonehearth:weapons:tome')
				equip_comp:equip_item('kmnky_traits:weapons:soul_staff')
				equip_comp:equip_item('kmnky_traits:traits:soul_outfit')
			end
			self._sv._entity:get_component('stonehearth:unit_info')._sv._made_divine_soul = true
		end
	end)

end

function DivineSoul:destroy()
	self._sv._entity:get_component('stonehearth:equipment'):unequip_item('kmnky_traits:traits:soul_outfit')
	self._sv._entity:get_component("stonehearth:job"):_equip_equipment(self._sv._entity:get_component("stonehearth:job")._job_json)
	self.pop_listener:destroy()
end

return DivineSoul