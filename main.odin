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
    physicalDevice :vk.PhysicalDevice,
    swap_chain: Swapchain,
    surface: vk.SurfaceKHR,
}

QueueFamilyIndices :: struct {
    graphicsFamily: u32,
}

Swapchain :: struct {
	handle: vk.SwapchainKHR,
	images: []vk.Image,
	image_views: []vk.ImageView,
	format: vk.SurfaceFormatKHR,
	extent: vk.Extent2D,
	present_mode: vk.PresentModeKHR,
	image_count: u32,
	support: SwapChainDetails,
	framebuffers: []vk.Framebuffer,
}

SwapChainDetails :: struct{
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats: []vk.SurfaceFormatKHR,
	present_modes: []vk.PresentModeKHR,
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

checkDeviceExtensionSupport :: proc(physical_device: vk.PhysicalDevice) -> bool {

    ext_count: u32;
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, nil);
	
	available_extensions := make([]vk.ExtensionProperties, ext_count);
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, raw_data(available_extensions));
	
	for ext in DEVICE_EXTENSIONS
	{
		found: b32;
		for available in &available_extensions
		{
			if cstring(&available.extensionName[0]) == ext
			{
				found = true;
				break;
			}
		}
		if !found do return false;
	}
	return true;
}

querySwapChainDetails :: proc(using ctx: ^Context, dev: vk.PhysicalDevice)
{
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(dev, surface, &swap_chain.support.capabilities);
	
	format_count: u32;
	vk.GetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &format_count, nil);
	if format_count > 0
	{
		swap_chain.support.formats = make([]vk.SurfaceFormatKHR, format_count);
		vk.GetPhysicalDeviceSurfaceFormatsKHR(dev, surface, &format_count, raw_data(swap_chain.support.formats));
	}
	
	present_mode_count: u32;
	vk.GetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &present_mode_count, nil);
	if present_mode_count > 0
	{
		swap_chain.support.present_modes = make([]vk.PresentModeKHR, present_mode_count);
		vk.GetPhysicalDeviceSurfacePresentModesKHR(dev, surface, &present_mode_count, raw_data(swap_chain.support.present_modes));
	}
}

pickPhysicalDevice :: proc(using ctx: ^Context) {

    device_count: u32;
    vk.EnumeratePhysicalDevices(instance, &device_count, nil)


   
    if device_count == 0 {
        fmt.print("no gpu with vulkan support found")
        os.exit(1);
    }

    devices := make([]vk.PhysicalDevice, device_count);
    vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))

    suitability :: proc(using ctx: ^Context, dev: vk.PhysicalDevice) -> int {

        props :vk.PhysicalDeviceProperties;
        features :vk.PhysicalDeviceFeatures;
        vk.GetPhysicalDeviceProperties(dev, &props);
        vk.GetPhysicalDeviceFeatures(dev, &features);

        score := 0;
		if props.deviceType == .DISCRETE_GPU do score += 1000;
		score += cast(int)props.limits.maxImageDimension2D;

        if !features.geometryShader do return 0;
        if !checkDeviceExtensionSupport(dev) do return 0;

        querySwapChainDetails(ctx, dev);
		if len(swap_chain.support.formats) == 0 || len(swap_chain.support.present_modes) == 0 do return 0;
		
		return score;
    }

	hiscore := 0;
	for dev in devices
	{
		score := suitability(ctx, dev);
		if score > hiscore
		{
			physicalDevice = dev;
			hiscore = score;
		}
	}
	
	if (hiscore == 0)
	{
		fmt.eprintf("ERROR: Failed to find a suitable GPU\n");
		os.exit(1);
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

initWindow :: proc(using ctx: ^Context) {
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

initVulkan :: proc(using ctx: ^Context) {
    vulkan_lib, loaded := dynlib.load_library("libvulkan.so")
    assert(loaded)
    vkGetInstanceProcAddr, found := dynlib.symbol_address(vulkan_lib, "vkGetInstanceProcAddr")
    assert(found)
    vk.load_proc_addresses(vkGetInstanceProcAddr)

    createInstance(ctx)

    extensions := getExtensions();
	for ext in &extensions do fmt.println(cstring(&ext.extensionName[0]));

    pickPhysicalDevice(ctx)
    // createLogicalDevice()
}

createInstance :: proc(using ctx: ^Context) {
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

    createInfo.enabledExtensionCount = cast(u32)len(glfwExtensions)
    createInfo.ppEnabledExtensionNames = raw_data(glfwExtensions)

    createInfo.enabledLayerCount = 0;

    when ODIN_DEBUG {
        layerCount: u32;
        vk.EnumerateInstanceLayerProperties(&layerCount, nil)
        layers := make([]vk.LayerProperties, layerCount)
        vk.EnumerateInstanceLayerProperties(&layerCount, raw_data(layers))

        outer: for name in VALIDATION_LAYERS {

            for layer in &layers {
                if name == cstring(&layer.layerName[0]) do continue outer;
            }
            fmt.eprintf("ERROR: validation layer %q not available\n", name);
			os.exit(1);
        }
        	
		create_info.ppEnabledLayerNames = &VALIDATION_LAYERS[0];
		create_info.enabledLayerCount = len(VALIDATION_LAYERS);
		fmt.println("Validation Layers Loaded");
    } else {
        createInfo.enabledLayerCount = 0
    }
  

    if vk.CreateInstance(&createInfo, nil, &instance) != .SUCCESS {
        fmt.println("failed to create instance");
        return;
    }
    fmt.println("Instance Created");

}

getExtensions :: proc() -> []vk.ExtensionProperties {
    n_ext: u32;
	vk.EnumerateInstanceExtensionProperties(nil, &n_ext, nil);
    fmt.printf("%d number of extenstions available\n", n_ext);

    extensions := make([]vk.ExtensionProperties, n_ext);
    vk.EnumerateInstanceExtensionProperties(nil, &n_ext, raw_data(extensions));

    for e in extensions {
        //fmt.printf("%s | ", e.extensionName);
    }

    return extensions
}

loop :: proc(using ctx: ^Context) {
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
    }
}

exit :: proc(using ctx: ^Context) {
    // vk shutdowns
    vk.DestroyInstance(instance, nil)

    // glfw shutdowns
    glfw.DestroyWindow(window)
    glfw.Terminate()

}

main :: proc() {

    using ctx: Context;

    initWindow(&ctx);
    initVulkan(&ctx);
    loop(&ctx);
    exit(&ctx);

}

