require("cluautils.tests.base_test_case")
require("sim")

---@MARK - Tests

SimTests = CTestCase

function SimTests:test_get_all_devices()
    ---@type devices
    local devices = GetAvailableDevices()

    return #devices.physical >= 0 and #devices.simulators >= 0
end

SimTests:run_tests()
