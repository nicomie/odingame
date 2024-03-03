package main

import "core:fmt"
import "core:os"
import "core:strings"
import vk "vendor:vulkan"
import "vendor:glfw"
import "core:dynlib"
import glm "core:math/linalg/glsl"

WIDTH :: 800;
HEIGHT :: 600;


VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"};
DEVICE_EXTENSIONS := [?]cstring{"VK_KHR_swapchain"};

Context :: struct {
    instance :vk.Instance,
    window :glfw.WindowHandle,
    queueFamily
}

QueueFamilyIndices :: struct {
    graphicsFamily: u32,
}


findQueueFamilies :: proc(device: vk.PhysicalDevice) -> QueueFamilyIndices {
    indices: QueueFamilyIndices;
    count: u32;
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, nil)

    families:= make([]vk.QueueFamilyProperties, count);
    vk.GetPhysicalDeviceQueueFamilyProperties(device, &count, raw_data(families))

    i:u32 = 0;
    for family in families {
        if .GRAPHICS in family.queueFlags{
            indices.graphicsFamily = i;
        }
        i+=1;
    }

  
    return indices;
}

pickPhysicalDevice :: proc() {

    physicalDevice :vk.PhysicalDevice;

    deviceCount :u32;
    vk.EnumeratePhysicalDevices(instance, &deviceCount, nil)
   
    if deviceCount == 0 {
        fmt.print("no gpu with vulkan support found")
        os.exit(1);
    }

    devices := make([]vk.PhysicalDevice, deviceCount);
    vk.EnumeratePhysicalDevices(instance, &deviceCount, raw_data(devices))

    suitability :: proc(dev: vk.PhysicalDevice) -> bool {
        props :vk.PhysicalDeviceProperties;
        features :vk.PhysicalDeviceFeatures;
        vk.GetPhysicalDeviceProperties(dev, &props);
        vk.GetPhysicalDeviceFeatures(dev, &features);

        indices := findQueueFamilies(dev);
        if &indices.graphicsFamily != nil {
            return true
        } else {
            return false
        }
    }

    for device in devices {
        if (suitability(device)) {
            physicalDevice = device;
            break;
        }
    }

    if physicalDevice == nil {
        fmt.print("nfailed to find gpu")
    }
}

createLogicalDevice :: proc() {

}

checkValidaitonLayerSupport :: proc() -> bool{

  
    lCount: u32;
    vk.EnumerateInstanceLayerProperties(&lCount, nil)

    availableLayers:= make([]vk.LayerProperties, lCount);
    vk.EnumerateInstanceLayerProperties(&lCount, raw_data(availableLayers))

    for layer in VALIDATION_LAYERS {
        found:= false;

        for &property in availableLayers {
            if string(layer) == strings.truncate_to_byte(string(property.layerName[:]), 0) {
                found = true;
            }
        }

        return found
    }

    return true;
}

initWindow :: proc() {
    glfw.Init()

    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
    glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE)

    window = glfw.CreateWindow(WIDTH, HEIGHT, "Odin + Vulkan", nil, nil); 

      
    model := glm.mat4{
        0.5,   0,   0, 0,
          0, 0.5,   0, 0,
          0,   0, 0.5, 0,
          0,   0,   0, 1,
    }
    pos := glm.vec4{
        0.5,
        0.5,
        0,
        0,
    };

    test := model * pos;
    fmt.print(test)


}

initVulkan :: proc() {
    vulkan_lib, loaded := dynlib.load_library("libvulkan.so")
    assert(loaded)
    vkGetInstanceProcAddr, found := dynlib.symbol_address(vulkan_lib, "vkGetInstanceProcAddr")
    assert(found)
    vk.load_proc_addresses(vkGetInstanceProcAddr)

    createInstance()
    // setup debug messenger
    pickPhysicalDevice()
    createLogicalDevice()
}

createInstance :: proc() {
    if !checkValidaitonLayerSupport() {
        fmt.println("Failed to add validation layer support");

    }
    appInfo :vk.ApplicationInfo;
    appInfo.sType = vk.StructureType.APPLICATION_INFO;
    appInfo.pApplicationName = "Hello triangle";
    appInfo.applicationVersion = vk.MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No engine";
    appInfo.engineVersion = vk.MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = vk.API_VERSION_1_0

    createInfo: vk.InstanceCreateInfo;
    createInfo.sType = vk.StructureType.INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
  
    glfwExtensions := glfw.GetRequiredInstanceExtensions()

    extendedExtensions := make([dynamic]cstring, len(glfwExtensions)+1)

    append(&extendedExtensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME);

    createInfo.enabledExtensionCount = cast(u32)len(extendedExtensions)
    createInfo.ppEnabledExtensionNames = raw_data(extendedExtensions)

    createInfo.enabledLayerCount = 0;

    // if validation layers
    createInfo.enabledLayerCount = len(VALIDATION_LAYERS)
    createInfo.pNext = nil
  
    result := vk.CreateInstance(&createInfo, nil, &instance);

    if result != vk.Result.SUCCESS {
        fmt.println("failed to create instance");
    }

    n_ext: u32;
	vk.EnumerateInstanceExtensionProperties(nil, &n_ext, nil);
    fmt.printf("%d number of extenstions available\n", n_ext);

    extensions := make([]vk.ExtensionProperties, n_ext);
    vk.EnumerateInstanceExtensionProperties(nil, &n_ext, raw_data(extensions));

    for e in extensions {
        fmt.printf("%s | ", e.extensionName);
    }

    


}

loop :: proc() {
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
    }
}

exit :: proc() {
    // vk shutdowns
    vk.DestroyInstance(instance, nil)

    // glfw shutdowns
    glfw.DestroyWindow(window)
    glfw.Terminate()

}

main :: proc() {

    using ctx: Context;

    initWindow(ctx);
    initVulkan(ctx);
    loop(ctx);
    exit();

}

