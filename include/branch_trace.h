#include <common.h>
#ifndef __branch_trace__
#define __branch_trace__

#include <cstdint>
#include <string>
#include <vector>

typedef struct {
    int64_t index;
    int64_t pc;
    int64_t target;
    int32_t taken;
    int32_t type;
} branch_trace;

void br_monitor_init(std::vector<std::string> args);
bool br_monitor_record_log(int v);
branch_trace br_monitor_get(int64_t c=100000);

#endif
