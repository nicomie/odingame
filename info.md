# Needed to run vulkan on Linux
```
vulkan_lib, loaded := dynlib.load_library("libvulkan.so")
assert(loaded)
vkGetInstanceProcAddr, found := dynlib.symbol_address(vulkan_lib, "vkGetInstanceProcAddr")
assert(found)
vk.load_proc_addresses(vkGetInstanceProcAddr)
```


