#include "system_stats.h"
#include <windows.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <dxgi1_4.h>
#include <comdef.h>
#include <wbemidl.h>
#include <thread>
#include <mutex>
#include <atomic>
#include <vector>
#include <string>

#pragma comment(lib, "pdh.lib")
#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "wbemuuid.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "oleaut32.lib")

namespace system_stats {

struct StatsData {
    double cpu_usage = 0.0;
    double cpu_temp = -1.0;
    double ram_used = 0.0;
    double ram_total = 0.0;
    double gpu_usage = 0.0;
    double gpu_temp = -1.0;
    double vram_used = 0.0;
    double vram_total = 0.0;
    double gpu_clock = -1.0;
    double gpu_mem_clock = -1.0;
    double fps = -1.0;
};

static std::thread worker_thread;
static std::mutex stats_mutex;
static std::atomic<bool> thread_running{false};
static StatsData latest_stats;

// CPU usage state
static ULONGLONG prev_idle_time = 0;
static ULONGLONG prev_kernel_time = 0;
static ULONGLONG prev_user_time = 0;

ULONGLONG ConvertFileTime(const FILETIME& ft) {
    return (((ULONGLONG)ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
}

double CalculateCpuUsage() {
    FILETIME idle_ft, kernel_ft, user_ft;
    if (!GetSystemTimes(&idle_ft, &kernel_ft, &user_ft)) {
        return -1.0;
    }
    ULONGLONG idle_time = ConvertFileTime(idle_ft);
    ULONGLONG kernel_time = ConvertFileTime(kernel_ft);
    ULONGLONG user_time = ConvertFileTime(user_ft);

    if (prev_idle_time == 0) {
        prev_idle_time = idle_time;
        prev_kernel_time = kernel_time;
        prev_user_time = user_time;
        return 0.0;
    }

    ULONGLONG idle_diff = idle_time - prev_idle_time;
    ULONGLONG kernel_diff = kernel_time - prev_kernel_time;
    ULONGLONG user_diff = user_time - prev_user_time;

    prev_idle_time = idle_time;
    prev_kernel_time = kernel_time;
    prev_user_time = user_time;

    ULONGLONG total_diff = kernel_diff + user_diff;
    if (total_diff == 0) {
        return 0.0;
    }

    double usage = (1.0 - (double)idle_diff / total_diff) * 100.0;
    if (usage < 0.0) usage = 0.0;
    if (usage > 100.0) usage = 100.0;
    return usage;
}

// NVML Definitions and loader
typedef int (*nvmlInit_t)();
typedef int (*nvmlShutdown_t)();
typedef int (*nvmlDeviceGetCount_t)(unsigned int*);
typedef int (*nvmlDeviceGetHandleByIndex_t)(unsigned int, void**);
typedef int (*nvmlDeviceGetUtilizationRates_t)(void*, void*);
typedef int (*nvmlDeviceGetTemperature_t)(void*, int, unsigned int*);
typedef int (*nvmlDeviceGetClockInfo_t)(void*, int, unsigned int*);
typedef int (*nvmlDeviceGetMemoryInfo_t)(void*, void*);
typedef int (*nvmlDeviceGetName_t)(void*, char*, unsigned int);

struct nvmlUtilization_t {
    unsigned int gpu;
    unsigned int memory;
};
struct nvmlMemory_t {
    unsigned long long total;
    unsigned long long free;
    unsigned long long used;
};

#define NVML_TEMPERATURE_GPU 0
#define NVML_CLOCK_GRAPHICS 0
#define NVML_CLOCK_MEM 1

static HMODULE hNvml = nullptr;
static nvmlInit_t pNvmlInit = nullptr;
static nvmlShutdown_t pNvmlShutdown = nullptr;
static nvmlDeviceGetCount_t pNvmlDeviceGetCount = nullptr;
static nvmlDeviceGetHandleByIndex_t pNvmlDeviceGetHandleByIndex = nullptr;
static nvmlDeviceGetUtilizationRates_t pNvmlDeviceGetUtilizationRates = nullptr;
static nvmlDeviceGetTemperature_t pNvmlDeviceGetTemperature = nullptr;
static nvmlDeviceGetClockInfo_t pNvmlDeviceGetClockInfo = nullptr;
static nvmlDeviceGetMemoryInfo_t pNvmlDeviceGetMemoryInfo = nullptr;
static nvmlDeviceGetName_t pNvmlDeviceGetName = nullptr;

static bool nvmlLoaded = false;
static void* nvmlDevice = nullptr;

void InitializeNvml() {
    if (nvmlLoaded) return;
    hNvml = LoadLibraryA("nvml.dll");
    if (!hNvml) {
        hNvml = LoadLibraryA("C:\\Program Files\\NVIDIA Corporation\\NVSMI\\nvml.dll");
    }
    if (!hNvml) {
        hNvml = LoadLibraryA("C:\\Windows\\System32\\nvml.dll");
    }

    if (hNvml) {
        pNvmlInit = (nvmlInit_t)GetProcAddress(hNvml, "nvmlInit_v2");
        if (!pNvmlInit) pNvmlInit = (nvmlInit_t)GetProcAddress(hNvml, "nvmlInit");

        pNvmlShutdown = (nvmlShutdown_t)GetProcAddress(hNvml, "nvmlShutdown");
        pNvmlDeviceGetCount = (nvmlDeviceGetCount_t)GetProcAddress(hNvml, "nvmlDeviceGetCount");
        pNvmlDeviceGetHandleByIndex = (nvmlDeviceGetHandleByIndex_t)GetProcAddress(hNvml, "nvmlDeviceGetHandleByIndex_v2");
        if (!pNvmlDeviceGetHandleByIndex) pNvmlDeviceGetHandleByIndex = (nvmlDeviceGetHandleByIndex_t)GetProcAddress(hNvml, "nvmlDeviceGetHandleByIndex");

        pNvmlDeviceGetUtilizationRates = (nvmlDeviceGetUtilizationRates_t)GetProcAddress(hNvml, "nvmlDeviceGetUtilizationRates");
        pNvmlDeviceGetTemperature = (nvmlDeviceGetTemperature_t)GetProcAddress(hNvml, "nvmlDeviceGetTemperature");
        pNvmlDeviceGetClockInfo = (nvmlDeviceGetClockInfo_t)GetProcAddress(hNvml, "nvmlDeviceGetClockInfo");
        pNvmlDeviceGetMemoryInfo = (nvmlDeviceGetMemoryInfo_t)GetProcAddress(hNvml, "nvmlDeviceGetMemoryInfo");
        pNvmlDeviceGetName = (nvmlDeviceGetName_t)GetProcAddress(hNvml, "nvmlDeviceGetName");

        if (pNvmlInit && pNvmlShutdown && pNvmlDeviceGetHandleByIndex &&
            pNvmlDeviceGetUtilizationRates && pNvmlDeviceGetTemperature &&
            pNvmlDeviceGetMemoryInfo) {
            if (pNvmlInit() == 0) {
                unsigned int count = 0;
                if (pNvmlDeviceGetCount && pNvmlDeviceGetCount(&count) == 0 && count > 0) {
                    if (pNvmlDeviceGetHandleByIndex(0, &nvmlDevice) == 0) {
                        nvmlLoaded = true;
                    }
                }
            }
        }
    }
}

void CleanupNvml() {
    if (nvmlLoaded && pNvmlShutdown) {
        pNvmlShutdown();
    }
    if (hNvml) {
        FreeLibrary(hNvml);
        hNvml = nullptr;
    }
    nvmlLoaded = false;
    nvmlDevice = nullptr;
}

void QueryNvml(StatsData& stats) {
    if (!nvmlLoaded || !nvmlDevice) return;

    nvmlUtilization_t util;
    if (pNvmlDeviceGetUtilizationRates(nvmlDevice, &util) == 0) {
        stats.gpu_usage = util.gpu;
    }

    unsigned int temp = 0;
    if (pNvmlDeviceGetTemperature(nvmlDevice, NVML_TEMPERATURE_GPU, &temp) == 0) {
        stats.gpu_temp = temp;
    }

    nvmlMemory_t mem;
    if (pNvmlDeviceGetMemoryInfo(nvmlDevice, &mem) == 0) {
        stats.vram_used = (double)mem.used / (1024.0 * 1024.0 * 1024.0);
        stats.vram_total = (double)mem.total / (1024.0 * 1024.0 * 1024.0);
    }

    if (pNvmlDeviceGetClockInfo) {
        unsigned int clockGpu = 0;
        if (pNvmlDeviceGetClockInfo(nvmlDevice, NVML_CLOCK_GRAPHICS, &clockGpu) == 0) {
            stats.gpu_clock = clockGpu;
        }
        unsigned int clockMem = 0;
        if (pNvmlDeviceGetClockInfo(nvmlDevice, NVML_CLOCK_MEM, &clockMem) == 0) {
            stats.gpu_mem_clock = clockMem;
        }
    }
}

// DXGI Fallback for VRAM
void QueryDxgiVram(StatsData& stats) {
    IDXGIFactory4* pFactory = nullptr;
    HRESULT hr = CreateDXGIFactory1(__uuidof(IDXGIFactory4), (void**)&pFactory);
    if (SUCCEEDED(hr) && pFactory) {
        IDXGIAdapter* pAdapter = nullptr;
        if (SUCCEEDED(pFactory->EnumAdapters(0, &pAdapter))) {
            IDXGIAdapter3* pAdapter3 = nullptr;
            if (SUCCEEDED(pAdapter->QueryInterface(__uuidof(IDXGIAdapter3), (void**)&pAdapter3))) {
                DXGI_QUERY_VIDEO_MEMORY_INFO memInfo;
                if (SUCCEEDED(pAdapter3->QueryVideoMemoryInfo(0, DXGI_MEMORY_SEGMENT_GROUP_LOCAL, &memInfo))) {
                    stats.vram_used = (double)memInfo.CurrentUsage / (1024.0 * 1024.0 * 1024.0);
                    stats.vram_total = (double)memInfo.Budget / (1024.0 * 1024.0 * 1024.0);
                }
                pAdapter3->Release();
            }
            pAdapter->Release();
        }
        pFactory->Release();
    }
}

// RAM
void QueryRam(StatsData& stats) {
    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    if (GlobalMemoryStatusEx(&memInfo)) {
        stats.ram_total = (double)memInfo.ullTotalPhys / (1024.0 * 1024.0 * 1024.0);
        stats.ram_used = (double)(memInfo.ullTotalPhys - memInfo.ullAvailPhys) / (1024.0 * 1024.0 * 1024.0);
    }
}

// Worker Thread Function
void StatsWorkerThread() {
    // 1. Initialize COM on this thread
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    bool com_initialized = SUCCEEDED(hr) || hr == RPC_E_CHANGED_MODE;

    // 2. Initialize WMI for CPU temperature
    IWbemLocator* pLoc = nullptr;
    IWbemServices* pSvc = nullptr;
    if (com_initialized) {
        hr = CoCreateInstance(CLSID_WbemLocator, 0, CLSCTX_INPROC_SERVER, IID_IWbemLocator, (LPVOID*)&pLoc);
        if (SUCCEEDED(hr) && pLoc) {
            hr = pLoc->ConnectServer(_bstr_t(L"ROOT\\WMI"), NULL, NULL, 0, NULL, 0, 0, &pSvc);
            if (SUCCEEDED(hr) && pSvc) {
                CoSetProxyBlanket(pSvc, RPC_C_AUTHN_WINNT, RPC_C_AUTHZ_NONE, NULL,
                                  RPC_C_AUTHN_LEVEL_CALL, RPC_C_IMP_LEVEL_IMPERSONATE, NULL, EOAC_NONE);
            } else {
                if (pSvc) pSvc->Release();
                pSvc = nullptr;
            }
        }
    }

    // 3. Initialize NVML for GPU
    InitializeNvml();

    // 4. Initialize PDH for FPS and GPU fallback
    PDH_HQUERY pdhQuery = nullptr;
    PDH_HCOUNTER fpsCounter = nullptr;
    PDH_HCOUNTER gpuCounter = nullptr;
    bool pdhInitialized = false;

    if (PdhOpenQueryA(NULL, NULL, &pdhQuery) == ERROR_SUCCESS) {
        PdhAddEnglishCounterA(pdhQuery, "\\Desktop Window Manager(*)\\Frames Per Second", 0, &fpsCounter);
        PdhAddEnglishCounterA(pdhQuery, "\\GPU Engine(*)\\Utilization Percentage", 0, &gpuCounter);
        PdhCollectQueryData(pdhQuery);
        pdhInitialized = true;
    }

    // Loop
    while (thread_running) {
        StatsData current;

        // A. CPU Usage
        current.cpu_usage = CalculateCpuUsage();

        // B. CPU Temp (WMI)
        if (pSvc) {
            IEnumWbemClassObject* pEnumerator = nullptr;
            hr = pSvc->ExecQuery(bstr_t("WQL"), bstr_t("SELECT CurrentTemperature FROM MSAcpi_ThermalZoneTemperature"),
                                 WBEM_FLAG_FORWARD_ONLY | WBEM_FLAG_RETURN_IMMEDIATELY, NULL, &pEnumerator);
            if (SUCCEEDED(hr) && pEnumerator) {
                IWbemClassObject* pclsObj = nullptr;
                ULONG uReturn = 0;
                hr = pEnumerator->Next(WBEM_INFINITE, 1, &pclsObj, &uReturn);
                if (SUCCEEDED(hr) && uReturn > 0 && pclsObj) {
                    VARIANT vtProp;
                    hr = pclsObj->Get(L"CurrentTemperature", 0, &vtProp, 0, 0);
                    if (SUCCEEDED(hr) && vtProp.vt != VT_NULL && vtProp.vt != VT_EMPTY) {
                        double kelvin_tenths = 0.0;
                        if (vtProp.vt == VT_I4) kelvin_tenths = vtProp.lVal;
                        else if (vtProp.vt == VT_UI4) kelvin_tenths = vtProp.ulVal;
                        else if (vtProp.vt == VT_R8) kelvin_tenths = vtProp.dblVal;

                        if (kelvin_tenths > 0) {
                            current.cpu_temp = (kelvin_tenths - 2732.0) / 10.0;
                        }
                    }
                    VariantClear(&vtProp);
                    pclsObj->Release();
                }
                pEnumerator->Release();
            }
        }

        // C. RAM
        QueryRam(current);

        // D. GPU (NVML vs Fallback)
        if (nvmlLoaded) {
            QueryNvml(current);
        } else {
            // Fallback for VRAM via DXGI
            QueryDxgiVram(current);
        }

        // E. PDH (FPS and GPU usage fallback if nvml isn't loaded)
        if (pdhInitialized) {
            PdhCollectQueryData(pdhQuery);

            // FPS
            if (fpsCounter) {
                PDH_FMT_COUNTERVALUE val;
                if (PdhGetFormattedCounterValue(fpsCounter, PDH_FMT_DOUBLE, NULL, &val) == ERROR_SUCCESS) {
                    if (val.CStatus == PDH_CSTATUS_VALID_DATA) {
                        current.fps = val.doubleValue;
                    }
                }
            }

            // GPU usage fallback (take maximum utilization from GPU engine engines)
            if (!nvmlLoaded && gpuCounter) {
                DWORD dwBufferSize = 0;
                DWORD dwItemCount = 0;
                PdhGetFormattedCounterArrayA(gpuCounter, PDH_FMT_DOUBLE, &dwBufferSize, &dwItemCount, NULL);
                if (dwBufferSize > 0) {
                    std::vector<char> buffer(dwBufferSize);
                    PPDH_FMT_COUNTERVALUE_ITEM_A pItems = (PPDH_FMT_COUNTERVALUE_ITEM_A)buffer.data();
                    if (PdhGetFormattedCounterArrayA(gpuCounter, PDH_FMT_DOUBLE, &dwBufferSize, &dwItemCount, pItems) == ERROR_SUCCESS) {
                        double max_util = 0.0;
                        for (DWORD i = 0; i < dwItemCount; i++) {
                            if (pItems[i].FmtValue.CStatus == PDH_CSTATUS_VALID_DATA) {
                                if (pItems[i].FmtValue.doubleValue > max_util) {
                                    max_util = pItems[i].FmtValue.doubleValue;
                                }
                            }
                        }
                        current.gpu_usage = max_util;
                    }
                }
            }
        }

        // Save stats thread-safely
        {
            std::lock_guard<std::mutex> lock(stats_mutex);
            latest_stats = current;
        }

        // Sleep for 1 second, checking running flag in short intervals
        for (int i = 0; i < 10 && thread_running; i++) {
            Sleep(100);
        }
    }

    // Cleanup WMI
    if (pSvc) pSvc->Release();
    if (pLoc) pLoc->Release();

    // Cleanup NVML
    CleanupNvml();

    // Cleanup PDH
    if (pdhQuery) {
        PdhCloseQuery(pdhQuery);
    }

    // Cleanup COM
    if (com_initialized) {
        CoUninitialize();
    }
}

void Initialize() {
    if (thread_running) return;
    thread_running = true;
    worker_thread = std::thread(StatsWorkerThread);
}

void Cleanup() {
    if (!thread_running) return;
    thread_running = false;
    if (worker_thread.joinable()) {
        worker_thread.join();
    }
}

flutter::EncodableMap GetStats() {
    std::lock_guard<std::mutex> lock(stats_mutex);
    flutter::EncodableMap result;
    result[flutter::EncodableValue("cpu_usage")] = flutter::EncodableValue(latest_stats.cpu_usage);
    result[flutter::EncodableValue("cpu_temp")] = flutter::EncodableValue(latest_stats.cpu_temp);
    result[flutter::EncodableValue("ram_used")] = flutter::EncodableValue(latest_stats.ram_used);
    result[flutter::EncodableValue("ram_total")] = flutter::EncodableValue(latest_stats.ram_total);
    result[flutter::EncodableValue("gpu_usage")] = flutter::EncodableValue(latest_stats.gpu_usage);
    result[flutter::EncodableValue("gpu_temp")] = flutter::EncodableValue(latest_stats.gpu_temp);
    result[flutter::EncodableValue("vram_used")] = flutter::EncodableValue(latest_stats.vram_used);
    result[flutter::EncodableValue("vram_total")] = flutter::EncodableValue(latest_stats.vram_total);
    result[flutter::EncodableValue("gpu_clock")] = flutter::EncodableValue(latest_stats.gpu_clock);
    result[flutter::EncodableValue("gpu_mem_clock")] = flutter::EncodableValue(latest_stats.gpu_mem_clock);
    result[flutter::EncodableValue("fps")] = flutter::EncodableValue(latest_stats.fps);
    return result;
}

} // namespace system_stats
