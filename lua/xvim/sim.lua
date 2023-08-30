require("cluautils.string_utils")
require("cluautils.json")

---@enum DeviceState
DeviceState = {
    SHUTDOWN = "Shutdown",
    BOOTED = "Booted",
}

---@enum DeviceType
DeviceType = {
    SIMULATOR = "SIM",
    PHYSICAL = "PHYS",
}

---@class device
---@field udid string
---@field state DeviceState
---@field name string
---@field os string
---@field type DeviceType
---@field get_type fun()
---
---@class devices
---@field physical device[]
---@field simulators device[]

---@MARK - Helper functions

---@param info string
---@return device
local function parse_physical_device(info)
    local separated_info = info:split(" ")

    return {udid=separated_info[2], name=separated_info[1], type=DeviceType.PHYSICAL}
end

---@return device[]
local function get_physical_devices()
    local all_devices = io.popen("xcrun xctrace list devices")
    local devices_header = "== Devices =="
    local simulators_header = "== Simulators =="

    if all_devices == nil then
        return {}
    end

    local physical_devices = {}
    local is_phys = false

    for line in all_devices:lines("*l") do
        if line:find(devices_header) ~= nil then
            is_phys = true

        elseif line:find(simulators_header) ~= nil then
            is_phys = false
            break

        elseif is_phys and not line:is_empty() then
            local device = parse_physical_device(line)
            table.insert(physical_devices, device)
        end
    end

    return physical_devices
end

---@return device[]
local function get_simulators()
    local all_devices = io.popen("xcrun simctl list -j devices available")

    if all_devices == nil then
        return {}
    end

    local json = Json.decode(all_devices:read("*a"))

    if json == nil then
        return {}
    end
    ---@type device[]
    local simulators = {}
    local devices_by_os = json.devices

    for device_tags, devices in pairs(devices_by_os) do
        local tags = tostring(device_tags):split("%.")
        local os_value = tags[#tags]

        for _, device in pairs(devices) do
            table.insert(simulators, {
                udid=device.udid,
                state=device.state,
                name=device.name,
                os=os_value,
                type=DeviceType.SIMULATOR,
            })
        end
    end

    return simulators
end

---@MARK - API

---@return devices
function GetAvailableDevices()
    local physical = get_physical_devices()
    local simulators = get_simulators()

    local devices = {physical=physical, simulators=simulators}

    return devices
end
