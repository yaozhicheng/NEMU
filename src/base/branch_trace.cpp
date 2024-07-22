extern "C" {
    #include <common.h>
    #include <debug.h>
}

#ifdef CONFIG_ENABLE_BRANCH_TRACE

#include "branch_trace.h"
#include <thread>
#include <mutex>
#include <chrono>
#include <queue>
#include <map>
#include <fstream>
#include <cstdlib>
#include <string>

std::queue<branch_trace> trace_queue;
std::mutex mtx, qmtx;
uint64_t __br_trace_index__ = 0;
bool branch_trace_dump_started = false;
bool enable_log_trace_to_file = true;
std::thread task;

void branch_trace_dump(pid_t parent_id){
    u_int64_t flage = 0xbebebebebebebebe;
    std::fstream ofs("__all_branch.trace", std::ios::out|std::ios::binary);
    ofs.write((char *)&flage, sizeof(flage));
    ofs.write((char *)&flage, sizeof(flage));
    bool debug_log = std::getenv("BR_STD_LOG") != nullptr;
    while (true)
    {
        branch_trace t;
        qmtx.lock();
        if(trace_queue.empty()){
            qmtx.unlock();
            if(!branch_trace_dump_started)break;
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            continue;
        }
        t = trace_queue.front();
        trace_queue.pop();
        ofs.write((char *)&t, sizeof(t));
        if(debug_log){
            printf("[%ld] PC: %lx => %lx taken: %d, type: %d\n", t.index, t.pc, t.target, t.taken, t.type);
        }
        qmtx.unlock();
    }
    flage = 0xedededededededed;
    ofs.write((char *)&flage, sizeof(flage));
    ofs.write((char *)&flage, sizeof(flage));
    ofs.flush();
    ofs.close();
}

extern "C" {
    void report_br_trace(uint64_t pc, uint64_t target, uint32_t taken, uint32_t type){        
        // start dump thread
        mtx.lock();
        if (!branch_trace_dump_started && enable_log_trace_to_file){
            branch_trace_dump_started = true;
            task = std::thread(branch_trace_dump, getppid());
        }
        mtx.unlock();
        // send trace data to queue
        qmtx.lock();
        branch_trace t;
        t.index = __br_trace_index__;
        t.pc = pc;
        t.target = target;
        t.taken = taken;
        t.type = type;
        trace_queue.push(t);
        __br_trace_index__ += 1;
        qmtx.unlock();
    }
    void report_br_trace_join(){
        branch_trace_dump_started = false;
        task.join();
    }
}

extern "C" {
void init_monitor(int, char *[]);
void cpu_exec(uint64_t n);
}

void br_monitor_init(std::vector<std::string> args){
    br_monitor_record_log(0);
    int argc = (int)args.size();
    char** argv = (char**)malloc(sizeof(char*) * 128);
    for(int i = 0; i < 128 && i < argc; i++){
        argv[i] = strdup(args[i].c_str());
    }
    return init_monitor(argc, argv);
}

bool br_monitor_record_log(int v){
    if(v == 0){
        enable_log_trace_to_file = false;
    }else if(v > 0){
        enable_log_trace_to_file = true;
    }
    return enable_log_trace_to_file;
}

branch_trace br_monitor_get(int64_t c){
    while (trace_queue.empty()){
        if (nemu_state.state == NEMU_END || nemu_state.state == NEMU_ABORT){
            branch_trace t;
            t.index = -1;
            return t;
        }
        cpu_exec(c);
    }
    auto t = trace_queue.front();
    trace_queue.pop();
    return t;
}

#else
extern "C" {
    void report_br_trace(uint64_t pc, uint64_t target, uint32_t taken, uint32_t type){}
}
#endif
