#ifndef RUNNER_SYSTEM_STATS_H_
#define RUNNER_SYSTEM_STATS_H_

#include <flutter/encodable_value.h>

namespace system_stats {

// Initialize background statistics tracking thread
void Initialize();

// Cleanup resources and stop tracking thread
void Cleanup();

// Thread-safely fetch the latest collected system statistics
flutter::EncodableMap GetStats();

} // namespace system_stats

#endif // RUNNER_SYSTEM_STATS_H_
