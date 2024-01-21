local mod = get_mod("Power_DI")
local DMF = get_mod("DMF")
local PDI = {}
local MasterItems = require("scripts/backend/master_items")
mod.version = "0.6"
mod.cache = {}
PDI.promise = require("scripts/foundation/utilities/promise")
PDI.utilities = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\utilities]])
PDI.save_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\save_manager]])
PDI.coroutine_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\coroutine_manager]])
PDI.api_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\api_manager]])
PDI.session_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\session_manager]])
PDI.datasource_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\datasource_manager]])
PDI.dataset_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\dataset_manager]])
PDI.report_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\report_manager]])
PDI.lookup_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\lookup_manager]])
PDI.view_manager = mod:io_dofile([[Power_DI\scripts\mods\Power_DI\modules\view_manager]])

--Function to print certain steps for debugging--
local debug = mod:get("debug_mode")
--Function to set debug mode--
PDI.set_debug_mode = function (value)
    debug = value
end
PDI.debug = function(function_name, context)
    if not debug then
       return 
    end
    if type(context) == "table" then
        print("Debug: "..function_name)
        print("----------")
        DMF:dump(context)
        print("----------")
    else
        print("Debug: "..function_name.." ("..tostring(context)..")")
    end
end

--Setting functions table--
local setting_functions = {
    max_cycles = PDI.coroutine_manager.set_max_cycles,
    debug_mode = PDI.set_debug_mode,
    auto_save =  PDI.save_manager.set_auto_save,
    auto_save_interval =  PDI.save_manager.set_auto_save_interval
}

--Create main data table--
PDI.data = {}

--Initialize components--
PDI.utilities.init(PDI)
PDI.api_manager.init(PDI)
PDI.coroutine_manager.init(PDI)
PDI.datasource_manager.init(PDI)
PDI.dataset_manager.init(PDI)
PDI.report_manager.init(PDI)
PDI.save_manager.init(PDI)
:next(
    function()
        mod:notify("Save files loaded")
        PDI.report_manager.register_save_data_reports()
    end
)
PDI.lookup_manager.init(PDI)
PDI.view_manager.init(PDI)
PDI.session_manager.init(PDI)

--Main update loop--
function mod.update(main_dt)
    PDI.save_manager.update()
    PDI.coroutine_manager.update()
end

--Trigger for updating settings--
function mod.on_setting_changed(setting_id)
    print(setting_id)
    local new_value = mod:get(setting_id)
    local setting_function = setting_functions[setting_id]
    if setting_function then
        setting_function(new_value)
    end
end

-- mod.on_all_mods_loaded = function()
--     if not Managers.ui:view_active("title_view") then
--         PDI.lookup_manager.add_master_item_lookup_table()
--     end
-- end

local previous_state_name

--Triggers for initializing and finalizing a session--
function mod.on_game_state_changed(status, state_name)
    if previous_state_name == "StateTitle" and state_name == "StateMainMenu" then
        PDI.lookup_manager.add_master_item_lookup_table()
    end
    if state_name == "GameplayStateRun" and status == "enter" and PDI.utilities.in_game() then
        PDI.session_manager.resume_or_create_session()
        PDI.datasource_manager.activate_hooks()
        mod:enable_all_hooks()
    elseif state_name == "GameplayStateRun" and status == "exit" and PDI.utilities.in_game() then
        mod:disable_all_hooks()
        PDI.session_manager.save_current_session()
        PDI.save_manager.clear_auto_save_cache()
    elseif state_name == "StateGameScore" and status == "enter" then
        local end_time = os.date("%X")
        PDI.session_manager.update_current_session_info({["end_time"] = end_time})
        PDI.session_manager.save_current_session()
        PDI.save_manager.clear_auto_save_cache()
	end
    if PDI.data.session_data and PDI.utilities.in_game() then
        PDI.data.session_data.info.status = Managers.state.game_mode:game_mode_state()
    end
    previous_state_name = state_name
end
-- function mod.on_game_state_changed(status, state_name)
--     if previous_state_name == "StateTitle" and state_name == "StateMainMenu" then
--         PDI.lookup_manager.add_master_item_lookup_table()
--     end
--     if state_name == "StateLoading" and status == "exit" then
--         if not PDI.session_manager.new_session_check() then
--             PDI.session_manager.resume_session()
--             PDI.datasource_manager.activate_hooks()
--             mod:enable_all_hooks()
--         end
--     elseif state_name == "GameplayInitStepGameMode" and status == "enter" and PDI.utilities.in_game() then
--         if PDI.session_manager.new_session_check() then
--             PDI.session_manager.create_session()
--             PDI.datasource_manager.activate_hooks()
--             mod:enable_all_hooks()
--         end
--     elseif state_name == "GameplayStateRun" and status == "exit" and PDI.utilities.in_game() then
--         mod:disable_all_hooks()
--         PDI.session_manager.save_current_session()
--         PDI.save_manager.clear_auto_save_cache()
--     elseif state_name == "StateGameScore" and status == "enter" then
--         local end_time = os.date("%X")
--         PDI.session_manager.update_current_session_info({["end_time"] = end_time})
--         PDI.session_manager.save_current_session()
--         PDI.save_manager.clear_auto_save_cache()
-- 	end
--     if PDI.data.session_data and PDI.utilities.in_game() then
--         PDI.data.session_data.info.status = Managers.state.game_mode:game_mode_state()
--     end
--     previous_state_name = state_name
-- end

--Hook to check if a session has ended, to update info in the save files--
mod:hook_safe(CLASS.GameModeManager, "rpc_game_mode_end_conditions_met", function(self, channel_id, outcome_id)
	local outcome = NetworkLookup.game_mode_outcomes[outcome_id]
    PDI.session_manager.update_current_session_info({["outcome"] = outcome})
end)

--Open the main PDI view--
function mod.open_pdi_view()
    PDI.view_manager.open_main_view()
end

--Dump data for debugging--
function mod.debug_dump()
    local datetime_string = os.date('%d_%m_%y_%H_%M_%S')
    DMF:dtf(PDI.data, "PDI_data_dump_"..datetime_string, 10)
    mod:notify("Data dump successful")
    -- PDI.data.save_data.report_templates = {}
    -- PDI.save_manager.save("save_data", PDI.data.save_data)
    -- :next(function()mod:echo("clear successful")end)
end