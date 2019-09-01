local TrapperClass = class()
local constants = require 'constants'
local CraftingJob = require 'stonehearth.jobs.crafting_job'
local rng = _radiant.math.get_default_rng()
radiant.mixin(TrapperClass, CraftingJob)

function TrapperClass:initialize()
   CraftingJob.initialize(self)
   self._sv._tame_beast_percent_chance = 0
   self._sv.max_num_siege_weapons = {}
   self._sv.max_num_animal_traps = {}
end

function TrapperClass:activate()
   CraftingJob.activate(self)

   if self._sv.is_current_class then
      self:_register_with_town()
   end

   self.__saved_variables:mark_changed()
end

function TrapperClass:restore()
   if self._sv.is_current_class then
      self:_register_with_town()
   end
end

function TrapperClass:promote(json_path, options)
   CraftingJob.promote(self, json_path, options)
   self._sv.max_num_siege_weapons = self._job_json.initial_num_siege_weapons or { trap = 0 }
   if next(self._sv.max_num_siege_weapons) then
      self:_register_with_town()
   end
   self._sv.max_num_animal_traps = self._job_json.initial_num_animal_traps or { fish_trap = 0 }
   if next(self._sv.max_num_animal_traps) then
      self:_register_with_town()
   end
   self.__saved_variables:mark_changed()
end

function TrapperClass:demote()
   local player_id = radiant.entities.get_player_id(self._sv._entity)
   local town = stonehearth.town:get_town(player_id)
   if town then
      town:remove_placement_slot_entity(self._sv._entity)
   end

   CraftingJob.demote(self)
end

--Private functions

function TrapperClass:_create_listeners()
   self._clear_trap_listener = radiant.events.listen(self._sv._entity, 'stonehearth:clear_trap', self, self._on_clear_trap)
   self._befriend_pet_listener = radiant.events.listen(self._sv._entity, 'stonehearth:befriend_pet', self, self._on_pet_befriended)

   --Move into another function that is activated by a test
   --self._set_trap_listener = radiant.events.listen(self._sv._entity, 'stonehearth:set_trap', self, self._on_set_trap)
end

function TrapperClass:_remove_listeners()
   if self._clear_trap_listener then
      self._clear_trap_listener:destroy()
      self._clear_trap_listener = nil
   end

   if self._befriend_pet_listener then
      self._befriend_pet_listener:destroy()
      self._befriend_pet_listener = nil
   end

   if self._set_trap_listener then
      self._set_trap_listener:destroy()
      self._set_trap_listener = nil
   end
end

-- Called if the trapper is harvesting a trap for food.
-- @param args - the trapped_entity_id field inside args is nil if there is no critter, and true if there is a critter
function TrapperClass:_on_clear_trap(args)
   if args.trapped_entity_id then
      self._job_component:add_exp(self._xp_rewards['successful_trap'])
   else
      self._job_component:add_exp(self._xp_rewards['unsuccessful_trap'])
   end
end

-- Called when the trapper is befriending a pet
-- @param args - the pet_id field inside args is nil if there is no critter, and the ID if there is a critter
function TrapperClass:_on_pet_befriended(args)
   if args.pet_id then
      self._job_component:add_exp(self._xp_rewards['befriend_pet'])
   end
end

-- We actually want the XP to be gained on harvesting; this is mostly for testing purposes.
function TrapperClass:_on_set_trap(args)
   --Comment in for testing, or write activation fn for autotests
   --self._job_component:add_exp(90)
end

-- Functions for level up
--Increase the size of the backpack
function TrapperClass:increase_backpack_size(args)
   local sc = self._sv._entity:get_component('stonehearth:storage')
   sc:change_max_capacity(args.backpack_size_increase)
end

function TrapperClass:set_tame_beast_percentage(args)
   self._sv._tame_beast_percent_chance = args.tame_beast_percentage
end
-- Functions for demote
--Make the backpack size smaller
function TrapperClass:decrease_backpack_size(args)
   local sc = self._sv._entity:get_component('stonehearth:storage')
   sc:change_max_capacity(-args.backpack_size_increase)
end

function TrapperClass:should_tame(target)
   local trappable = radiant.entities.get_component_data('stonehearth:trapper:trapping_grounds', 'stonehearth:trapping_grounds').trappable_animal_weights
   local big_game = trappable and trappable.big_game or {}
   local is_big_game = big_game[target:get_uri()]
   if not is_big_game then
      if not self:has_perk('trapper_natural_empathy_1') then
         return false
      end

      local trapper = self._sv._entity
      local num_pets = trapper:add_component('stonehearth:pet_owner'):num_pets()
      local max_num_pets = 1
      local attributes = trapper:get_component('stonehearth:attributes')
      if attributes then
         local compassion = attributes:get_attribute('compassion')
         if compassion >= stonehearth.constants.attribute_effects.COMPASSION_TRAPPER_TWO_PETS_THRESHOLD then
            max_num_pets = 2
         end
      end

      if num_pets >= max_num_pets then
         return false
      end

      -- percentage chance to tame the pet.
      local percent = rng:get_int(1, 100)
      if percent > self._sv._tame_beast_percent_chance then
         return false
      end

      return true
   else
      --log:debug('%s IS big game, DON\'T consider taming it', target)
      return false
   end
end

function TrapperClass:increase_max_placeable_traps(args)
   if args.max_num_siege_weapons then
      self._sv.max_num_siege_weapons = args.max_num_siege_weapons    
   end
   if args.max_num_animal_traps then
      self._sv.max_num_animal_traps = args.max_num_animal_traps
   end
   self:_register_with_town()
   self.__saved_variables:mark_changed()
end

function TrapperClass:_register_with_town()
   local player_id = radiant.entities.get_player_id(self._sv._entity)
   local town = stonehearth.town:get_town(player_id)
   if town then
      town:add_placement_slot_entity(self._sv._entity, self._sv.max_num_siege_weapons)
      if self._sv.max_num_animal_traps then
         town:add_placement_slot_entity(self._sv._entity, self._sv.max_num_animal_traps)
      end
   end
end

return TrapperClass
